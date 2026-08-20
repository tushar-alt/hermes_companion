# relay.py — pip install fastapi uvicorn
import os, secrets, time
from pathlib import Path
from fastapi import FastAPI, Header, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

TOKEN = os.environ.get("RELAY_TOKEN", secrets.token_hex(24))  # set RELAY_TOKEN in env
SHARED_DIR = Path.home() / "Shared"
SHARED_DIR.mkdir(exist_ok=True)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

chats = {"main": {"name": "Hermes", "isMain": True, "lastId": 0, "paused": False, "lastTs": 0}}
messages = {"main": []}
running_sessions = {}  # track running agent sessions

def auth(authorization: str = None):
    if authorization != f"Bearer {TOKEN}":
        raise HTTPException(401, "unauthorized")

def next_id(chat):
    chats[chat]["lastId"] += 1
    return chats[chat]["lastId"]

# ── Agent hooks ──────────────────────────────────────────────────────────────

def run_agent(chat_id: str, chat_messages: list) -> str:
    """Run the agent on a message and return the reply text."""
    # This is where you'd wire in your actual agent logic.
    # For now, return a simple echo. Replace this with your Hermes agent call.
    user_msg = chat_messages[-1]["text"] if chat_messages else ""
    return f"[Hermes] I received: {user_msg}"

def start_agent_session(chat_id: str):
    """Start a chat's agent session."""
    running_sessions[chat_id] = {"started": time.time(), "status": "running"}
    chats[chat_id]["paused"] = False

def stop_agent_session(chat_id: str):
    """Stop a chat's agent session — zero resources."""
    running_sessions.pop(chat_id, None)
    chats[chat_id]["paused"] = True

# ── API endpoints ────────────────────────────────────────────────────────────

@app.get("/api/health")
def health():
    return {"ok": True}

@app.get("/api/chats")
def list_chats(authorization: str = Header(None)):
    auth(authorization)
    return {"chats": [{"id": cid, **c, "avatar": "⚕"} for cid, c in chats.items()]}

@app.get("/api/chat")
def main_chat(authorization: str = Header(None)):
    auth(authorization)
    c = chats["main"]
    return {"chatId": "main", "displayName": c["name"], "lastId": c["lastId"]}

class NewChat(BaseModel):
    name: str

@app.post("/api/chat/new")
def new_chat(body: NewChat, authorization: str = Header(None)):
    auth(authorization)
    cid = f"chat_{secrets.token_hex(4)}"
    chats[cid] = {"name": body.name, "isMain": False, "lastId": 0, "paused": False, "lastTs": 0}
    messages[cid] = []
    return {"id": cid, "name": body.name}

@app.post("/api/chat/{cid}/pause")
def pause_chat(cid: str, authorization: str = Header(None)):
    auth(authorization)
    if cid not in chats:
        raise HTTPException(404, "no such chat")
    stop_agent_session(cid)
    return {"ok": True}

@app.post("/api/chat/{cid}/resume")
def resume_chat(cid: str, authorization: str = Header(None)):
    auth(authorization)
    if cid not in chats:
        raise HTTPException(404, "no such chat")
    start_agent_session(cid)
    return {"ok": True}

@app.delete("/api/chat/{cid}")
def delete_chat(cid: str, authorization: str = Header(None)):
    auth(authorization)
    if cid == "main":
        raise HTTPException(400, "cannot delete main")
    stop_agent_session(cid)
    chats.pop(cid, None)
    messages.pop(cid, None)
    return {"ok": True}

@app.get("/api/messages")
def get_messages(after: int = 0, chat: str = "main", authorization: str = Header(None)):
    auth(authorization)
    ms = [m for m in messages.get(chat, []) if m["id"] > after]
    return {"messages": ms, "lastId": chats.get(chat, {}).get("lastId", after)}

class Send(BaseModel):
    text: str = ""
    chat: str = "main"
    media: list[str] = []

@app.post("/api/send")
def send(body: Send, authorization: str = Header(None)):
    auth(authorization)
    cid = body.chat if body.chat in chats else "main"
    messages[cid].append({
        "id": next_id(cid), "role": "user",
        "text": body.text, "ts": time.time(), "media": body.media
    })
    chats[cid]["lastTs"] = time.time()

    # Run agent if session is not paused
    if not chats[cid].get("paused", False):
        reply = run_agent(cid, messages[cid])
        messages[cid].append({
            "id": next_id(cid), "role": "assistant",
            "text": reply, "ts": time.time(), "media": []
        })

    return {"ok": True}

@app.get("/api/status")
def status(authorization: str = Header(None)):
    auth(authorization)
    result = {}
    for cid, c in chats.items():
        sess = running_sessions.get(cid, {})
        result[cid] = {
            "status": "running" if cid in running_sessions else "idle",
            "since": sess.get("started", 0),
            "detail": sess.get("detail", ""),
            "paused": c.get("paused", False)
        }
    return {"chats": result}

@app.get("/api/files")
def files(authorization: str = Header(None)):
    auth(authorization)
    out = []
    for f in sorted(SHARED_DIR.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        if f.is_file():
            st = f.stat()
            out.append({"name": f.name, "path": str(f), "size": st.st_size, "mtime": st.st_mtime})
    return {"files": out}

@app.get("/api/media")
def media(path: str, authorization: str = Header(None)):
    auth(authorization)
    p = Path(path).resolve()
    if SHARED_DIR.resolve() not in p.parents or not p.is_file():
        raise HTTPException(404, "not found")
    return FileResponse(p)

@app.post("/api/upload")
def upload(chat: str = "main", name: str = "file",
           file: UploadFile = File(...), authorization: str = Header(None)):
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
