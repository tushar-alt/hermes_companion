# relay.py — pip install fastapi uvicorn
import secrets, time
from pathlib import Path
from fastapi import FastAPI, Header, HTTPException, UploadFile, File
from pydantic import BaseModel

TOKEN = secrets.token_hex(24)          # or read from env/config
SHARED_DIR = Path.home() / "Shared"    # where files live
SHARED_DIR.mkdir(exist_ok=True)

app = FastAPI()
chats = {"main": {"name": "Hermes", "isMain": True, "lastId": 0, "paused": False, "lastTs": 0}}
messages = {"main": []}

def auth(authorization: str | None):
    if authorization != f"Bearer {TOKEN}":
        raise HTTPException(401, "unauthorized")

def next_id(chat):
    chats[chat]["lastId"] += 1
    return chats[chat]["lastId"]

@app.get("/api/health")
def health(): return {"ok": True}

@app.get("/api/chats")
def list_chats(authorization: str | None = Header(None)):
    auth(authorization)
    return {"chats": [{"id": cid, **c, "avatar": "⚕"} for cid, c in chats.items()]}

@app.get("/api/chat")
def main_chat(authorization: str | None = Header(None)):
    auth(authorization)
    c = chats["main"]
    return {"chatId": "main", "displayName": c["name"], "lastId": c["lastId"]}

class NewChat(BaseModel):
    name: str

@app.post("/api/chat/new")
def new_chat(body: NewChat, authorization: str | None = Header(None)):
    auth(authorization)
    cid = f"chat_{secrets.token_hex(4)}"
    chats[cid] = {"name": body.name, "isMain": False, "lastId": 0, "paused": False, "lastTs": 0}
    messages[cid] = []
    return {"id": cid, "name": body.name}

# Power toggle — when paused, KILL the session/CLI for that chat so it uses
# zero system resources. The app shows a red glowing dot while paused.
@app.post("/api/chat/{cid}/pause")
def pause_chat(cid: str, authorization: str | None = Header(None)):
    auth(authorization)
    if cid not in chats: raise HTTPException(404, "no such chat")
    chats[cid]["paused"] = True
    stop_agent_session(cid)   # your hook: terminate the session process/CLI
    return {"ok": True}

@app.post("/api/chat/{cid}/resume")
def resume_chat(cid: str, authorization: str | None = Header(None)):
    auth(authorization)
    if cid not in chats: raise HTTPException(404, "no such chat")
    chats[cid]["paused"] = False
    start_agent_session(cid)  # your hook: relaunch the session/CLI
    return {"ok": True}

@app.delete("/api/chat/{cid}")
def delete_chat(cid: str, authorization: str | None = Header(None)):
    auth(authorization)
    if cid == "main": raise HTTPException(400, "cannot delete main")
    stop_agent_session(cid)          # kill the session/CLI — no leftovers
    chats.pop(cid, None); messages.pop(cid, None)
    return {"ok": True}

@app.get("/api/messages")
def get_messages(after: int = 0, chat: str = "main", authorization: str | None = Header(None)):
    auth(authorization)
    ms = [m for m in messages.get(chat, []) if m["id"] > after]
    return {"messages": ms, "lastId": chats.get(chat, {}).get("lastId", after)}

class Send(BaseModel):
    text: str = ""
    chat: str = "main"
    media: list[str] = []

@app.post("/api/send")
def send(body: Send, authorization: str | None = Header(None)):
    auth(authorization)
    cid = body.chat if body.chat in chats else "main"
    messages[cid].append({"id": next_id(cid), "role": "user",
                          "text": body.text, "ts": time.time(), "media": body.media})
    chats[cid]["lastTs"] = time.time()   # for app-side recency sorting
    # 👉 THIS IS YOUR HOOK: run the agent on the new message — unless the
    #    session is paused (the message stays queued for after resume). When
    #    done, post an "assistant" message the same way, e.g.:
    #    if not chats[cid]["paused"]:
    #        reply = run_agent(cid, messages[cid])   # your agent logic
    #        messages[cid].append({"id": next_id(cid), "role": "assistant",
    #                              "text": reply, "ts": time.time(), "media": []})
    return {"ok": True}

@app.get("/api/status")
def status(authorization: str | None = Header(None)):
    auth(authorization)
    return {"chats": {cid: {"status": "idle", "since": 0, "detail": "",
                            "paused": c.get("paused", False)}
                      for cid, c in chats.items()}}

@app.get("/api/files")
def files(authorization: str | None = Header(None)):
    auth(authorization)
    out = []
    for f in sorted(SHARED_DIR.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        if f.is_file():
            st = f.stat()
            out.append({"name": f.name, "path": str(f), "size": st.st_size,
                        "mtime": st.st_mtime})
    return {"files": out}

@app.get("/api/media")
def media(path: str, authorization: str | None = Header(None)):
    auth(authorization)
    p = Path(path).resolve()
    if SHARED_DIR.resolve() not in p.parents or not p.is_file():
        raise HTTPException(404, "not found")
    return FileResponse(p)

@app.post("/api/upload")
def upload(chat: str = "main", name: str = "file",
           file: UploadFile = File(...), authorization: str | None = Header(None)):
    auth(authorization)
    dest = SHARED_DIR / Path(name).name
    dest.write_bytes(file.file.read())
    return {"path": str(dest)}

if __name__ == "__main__":
    import uvicorn
    print(f"\n⚕ Hermes relay ready — pairing link for the app:")
    print(f"hermes://pair?url=http%3A%2F%2F<YOUR-LAN-IP>%3A8124&token={TOKEN}")
    print(f"   (for internet use, replace the LAN URL with your public https URL)\n")
    uvicorn.run(app, host="0.0.0.0", port=8124)
