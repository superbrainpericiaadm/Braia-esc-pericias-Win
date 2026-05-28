#!/usr/bin/env python3
"""Busca na memoria da Braia. Uso: search.py "topico" [limite]
- Com OPENAI_API_KEY: busca VETORIAL (cosseno) por significado.
- Sem chave: busca FULL-TEXT (palavras) no Postgres.
Imprime resultados em texto pro Claude ler."""
import sys, os, requests
import psycopg2

ENV='/opt/braia/.env'
def load_env(p):
    e={}
    if os.path.exists(p):
        for l in open(p,encoding='utf-8'):
            l=l.strip()
            if '=' in l and not l.startswith('#'):
                k,v=l.split('=',1); e[k.strip()]=v.strip()
    return e
env=load_env(ENV); DSN=env.get('DATABASE_URL'); KEY=env.get('OPENAI_API_KEY','').strip()
args=sys.argv[1:]; lim=10
if len(args)>=2 and args[-1].isdigit(): lim=int(args[-1]); q=' '.join(args[:-1]).strip()
else: q=' '.join(args).strip()
if not q: print('uso: search.py "topico" [limite]'); sys.exit(1)

conn=psycopg2.connect(DSN); cur=conn.cursor()
mode='vetorial' if KEY else 'full-text'
try:
    if KEY:
        r=requests.post('https://api.openai.com/v1/embeddings',
            headers={'Authorization':f'Bearer {KEY}','Content-Type':'application/json'},
            json={'model':'text-embedding-3-small','input':[q]}, timeout=40)
        r.raise_for_status(); qv='['+','.join(repr(x) for x in r.json()['data'][0]['embedding'])+']'
        cur.execute("SELECT role,left(content,400),created_at,round((1-(embedding<=>%s::vector))::numeric,3) "
                    "FROM conversation_history WHERE embedding IS NOT NULL "
                    "ORDER BY embedding<=>%s::vector LIMIT %s",(qv,qv,lim))
    else:
        cur.execute("SELECT role,left(content,400),created_at,round(ts_rank(content_tsv,websearch_to_tsquery('portuguese',%s))::numeric,3) "
                    "FROM conversation_history WHERE content_tsv @@ websearch_to_tsquery('portuguese',%s) "
                    "ORDER BY 4 DESC, created_at DESC LIMIT %s",(q,q,lim))
    rows=cur.fetchall()
    print(f'[busca {mode}] "{q}" -> {len(rows)} resultado(s)')
    for role,content,ts,score in rows:
        print(f'- ({ts:%Y-%m-%d %H:%M} {role} score={score}) {content}')
except Exception as e:
    print(f'[erro busca {mode}] {e}')
