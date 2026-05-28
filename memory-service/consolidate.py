#!/usr/bin/env python3
"""Consolida msgs do bot no conversation_history.
- Sempre grava o TEXTO (memoria full-text funciona sem chave).
- Se OPENAI_API_KEY existir: gera embedding (text-embedding-3-small, 1536d) e
  faz backfill das linhas sem embedding. Roda via cron (~0 RAM, sem modelo local)."""
import json, glob, os, requests
import psycopg2

ENV='/opt/braia/.env'; BOT='/opt/braia-bot'
MS='/opt/braia/memory-service'; STATE=MS+'/state'; DONE=STATE+'/consolidated.txt'
os.makedirs(STATE, exist_ok=True)

def load_env(p):
    e={}
    if os.path.exists(p):
        for l in open(p, encoding='utf-8'):
            l=l.strip()
            if '=' in l and not l.startswith('#'):
                k,v=l.split('=',1); e[k.strip()]=v.strip()
    return e
env=load_env(ENV)
DSN=env.get('DATABASE_URL'); KEY=env.get('OPENAI_API_KEY','').strip()

def embed(texts):
    r=requests.post('https://api.openai.com/v1/embeddings',
        headers={'Authorization':f'Bearer {KEY}','Content-Type':'application/json'},
        json={'model':'text-embedding-3-small','input':texts}, timeout=40)
    r.raise_for_status()
    return [d['embedding'] for d in r.json()['data']]
def vec(e): return '['+','.join(repr(x) for x in e)+']'

done=set(open(DONE).read().split()) if os.path.exists(DONE) else set()
conn=psycopg2.connect(DSN); conn.autocommit=True; cur=conn.cursor()

def ins(role, content, ts):
    emb=None
    if KEY:
        try: emb=embed([content])[0]
        except Exception as ex: print('embed falhou (segue texto):', ex)
    if emb is not None:
        cur.execute("INSERT INTO conversation_history (session_key,agent_id,role,content,embedding,created_at) "
                    "VALUES ('telegram','main',%s,%s,%s::vector,COALESCE(%s::timestamptz,now()))",
                    (role,content,vec(emb),ts))
    else:
        cur.execute("INSERT INTO conversation_history (session_key,agent_id,role,content,created_at) "
                    "VALUES ('telegram','main',%s,%s,COALESCE(%s::timestamptz,now()))",(role,content,ts))

count=0; news=[]
for f in sorted(glob.glob(BOT+'/inbox/*.json')):
    k='in:'+os.path.basename(f)
    if k in done: continue
    try:
        d=json.load(open(f,encoding='utf-8')); t=(d.get('text') or '').strip()
        if t: ins('user',t,d.get('timestamp')); count+=1
        news.append(k)
    except Exception as e: print('skip',f,e)
for f in sorted(glob.glob(BOT+'/sent/*.json')):
    k='out:'+os.path.basename(f)
    if k in done: continue
    try:
        d=json.load(open(f,encoding='utf-8')); t=(d.get('text') or '').strip()
        if t: ins('assistant',t,d.get('sent_at')); count+=1
        news.append(k)
    except Exception as e: print('skip',f,e)
if news:
    open(DONE,'a').write('\n'.join(news)+'\n')

# backfill embeddings (so quando ha chave): linhas sem vetor, em lote
bf=0
if KEY:
    cur.execute("SELECT id,content FROM conversation_history WHERE embedding IS NULL ORDER BY id LIMIT 50")
    for rid,content in cur.fetchall():
        try:
            e=embed([content])[0]
            cur.execute("UPDATE conversation_history SET embedding=%s::vector WHERE id=%s",(vec(e),rid)); bf+=1
        except Exception as ex: print('backfill falhou id',rid,ex); break
print(f'novas={count} backfill_embeddings={bf} chave_openai={"sim" if KEY else "nao (modo full-text)"}')
