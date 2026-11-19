"""PetTrack backend — deploy on Coolify (Dockerfile in this folder).

Features
- Anonymous device tokens (no accounts, no e-mail addresses stored)
- Household feeding sync ("Who fed the dog?")
- Public collar-tag pages /p/<slug> with lost-pet mode and a contact form for finders
- OCR for vet reports (Tesseract, English/Spanish/German/French/Dutch)

Storage: one SQLite file in DATA_DIR (mount a persistent volume there).
"""
from __future__ import annotations

import base64
import html
import io
import json
import os
import secrets
import sqlite3
import string
import time
from contextlib import contextmanager
from typing import Any

from fastapi import Depends, FastAPI, Form, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

DATA_DIR = os.environ.get("DATA_DIR", "./data")
DB_PATH = os.path.join(DATA_DIR, "pettrack.db")
MAX_IMAGE_BYTES = 8 * 1024 * 1024

app = FastAPI(title="PetTrack API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (token TEXT PRIMARY KEY, created_at REAL NOT NULL);
CREATE TABLE IF NOT EXISTS households (code TEXT PRIMARY KEY, owner TEXT NOT NULL, created_at REAL NOT NULL);
CREATE TABLE IF NOT EXISTS members (code TEXT NOT NULL, token TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY (code, token));
CREATE TABLE IF NOT EXISTS household_pets (code TEXT NOT NULL, pet_id TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY (code, pet_id));
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY, code TEXT NOT NULL, token TEXT NOT NULL, pet_id TEXT NOT NULL, date TEXT NOT NULL,
  data TEXT NOT NULL, received_at REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS events_code_date ON events (code, date);
CREATE TABLE IF NOT EXISTS public_pets (pet_id TEXT PRIMARY KEY, slug TEXT UNIQUE NOT NULL, owner TEXT NOT NULL, data TEXT NOT NULL, updated_at REAL NOT NULL);
CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, pet_id TEXT NOT NULL, name TEXT, phone TEXT, message TEXT NOT NULL, created_at REAL NOT NULL);
"""


@contextmanager
def db():
    os.makedirs(DATA_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


with db() as _c:
    _c.executescript(SCHEMA)


def device(authorization: str = Header(default="")) -> str:
    token = authorization.removeprefix("Bearer ").strip()
    with db() as c:
        if not token or not c.execute("SELECT 1 FROM devices WHERE token = ?", (token,)).fetchone():
            raise HTTPException(401, "Unknown device")
    return token


def membership(c: sqlite3.Connection, token: str) -> sqlite3.Row:
    row = c.execute("SELECT code FROM members WHERE token = ? ORDER BY rowid DESC LIMIT 1", (token,)).fetchone()
    if not row:
        raise HTTPException(404, "Not in a household")
    return row


def member_names(c: sqlite3.Connection, code: str) -> list[str]:
    return [r["name"] for r in c.execute("SELECT name FROM members WHERE code = ? ORDER BY rowid", (code,))]


# ---------------------------------------------------------------- devices

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/devices")
def register_device() -> dict[str, str]:
    token = secrets.token_urlsafe(32)
    with db() as c:
        c.execute("INSERT INTO devices VALUES (?, ?)", (token, time.time()))
    return {"token": token}


@app.delete("/api/devices/me")
def delete_device(token: str = Depends(device)) -> dict[str, bool]:
    """Deletes everything this device created on the server (App Store guideline 5.1.1(v))."""
    with db() as c:
        owned = [r["code"] for r in c.execute("SELECT code FROM households WHERE owner = ?", (token,))]
        for code in owned:
            for table in ("members", "household_pets", "events"):
                c.execute(f"DELETE FROM {table} WHERE code = ?", (code,))
            c.execute("DELETE FROM households WHERE code = ?", (code,))
        c.execute("DELETE FROM members WHERE token = ?", (token,))
        c.execute("DELETE FROM events WHERE token = ?", (token,))
        pets = [r["pet_id"] for r in c.execute("SELECT pet_id FROM public_pets WHERE owner = ?", (token,))]
        for pet_id in pets:
            c.execute("DELETE FROM messages WHERE pet_id = ?", (pet_id,))
        c.execute("DELETE FROM public_pets WHERE owner = ?", (token,))
        c.execute("DELETE FROM devices WHERE token = ?", (token,))
    return {"deleted": True}


# ---------------------------------------------------------------- household

class HouseholdIn(BaseModel):
    name: str = Field(min_length=1, max_length=40)


class JoinIn(HouseholdIn):
    code: str = Field(min_length=6, max_length=8)


def new_code() -> str:
    alphabet = "".join(ch for ch in string.ascii_uppercase + string.digits if ch not in "O0I1")
    raw = "".join(secrets.choice(alphabet) for _ in range(6))
    return f"{raw[:3]}-{raw[3:]}"


@app.post("/api/household")
def create_household(body: HouseholdIn, token: str = Depends(device)) -> dict[str, Any]:
    with db() as c:
        code = new_code()
        c.execute("INSERT INTO households VALUES (?, ?, ?)", (code, token, time.time()))
        c.execute("INSERT INTO members VALUES (?, ?, ?)", (code, token, body.name.strip()))
        return {"code": code, "members": member_names(c, code)}


@app.post("/api/household/join")
def join_household(body: JoinIn, token: str = Depends(device)) -> dict[str, Any]:
    code = body.code.strip().upper()
    if len(code) == 6:
        code = f"{code[:3]}-{code[3:]}"
    with db() as c:
        if not c.execute("SELECT 1 FROM households WHERE code = ?", (code,)).fetchone():
            raise HTTPException(404, "Invite code not found")
        c.execute("INSERT OR REPLACE INTO members VALUES (?, ?, ?)", (code, token, body.name.strip()))
        return {"code": code, "members": member_names(c, code)}


class EventIn(BaseModel):
    id: str = Field(max_length=64)
    petId: str = Field(max_length=64)
    kind: str = Field(pattern="^(meal|water|treat)$")
    date: str = Field(max_length=40)
    amount: float = 0
    fedBy: str = Field(default="", max_length=40)
    slotId: str | None = Field(default=None, max_length=64)


class EventsIn(BaseModel):
    events: list[EventIn] = Field(default_factory=list, max_length=500)


def store_events(c: sqlite3.Connection, code: str, token: str, events: list[EventIn]) -> None:
    now = time.time()
    for e in events:
        c.execute("INSERT OR IGNORE INTO events VALUES (?, ?, ?, ?, ?, ?, ?)",
                  (e.id, code, token, e.petId, e.date, e.model_dump_json(), now))


@app.post("/api/household/events")
def push_events(body: EventsIn, token: str = Depends(device)) -> dict[str, int]:
    with db() as c:
        code = membership(c, token)["code"]
        store_events(c, code, token, body.events)
    return {"stored": len(body.events)}


class PetIn(BaseModel):
    id: str = Field(max_length=64)
    name: str = Field(max_length=60)
    species: str = Field(max_length=20)


class SyncIn(EventsIn):
    since: str = Field(max_length=40)
    pets: list[PetIn] = Field(default_factory=list, max_length=50)
    slots: list[dict[str, Any]] = Field(default_factory=list, max_length=200)


@app.post("/api/household/sync")
def sync(body: SyncIn, token: str = Depends(device)) -> dict[str, Any]:
    with db() as c:
        code = membership(c, token)["code"]
        owner = c.execute("SELECT owner FROM households WHERE code = ?", (code,)).fetchone()["owner"]
        store_events(c, code, token, body.events)
        if token == owner:
            for p in body.pets:
                c.execute("INSERT OR REPLACE INTO household_pets VALUES (?, ?, ?)", (code, p.id, p.model_dump_json()))
        rows = c.execute("SELECT data FROM events WHERE code = ? AND token != ? AND date >= ? ORDER BY date LIMIT 1000",
                         (code, token, body.since)).fetchall()
        pets = [json.loads(r["data"]) for r in c.execute("SELECT data FROM household_pets WHERE code = ?", (code,))]
        return {"events": [json.loads(r["data"]) for r in rows], "pets": pets, "members": member_names(c, code)}


# ---------------------------------------------------------------- collar tag / lost mode

class LostIn(BaseModel):
    active: bool = False
    since: str = ""
    lastSeen: str = Field(default="", max_length=200)
    message: str = Field(default="", max_length=600)
    reward: str = Field(default="", max_length=80)
    contactPhone: str = Field(default="", max_length=40)


class PublicPetIn(BaseModel):
    name: str = Field(max_length=60)
    species: str = Field(max_length=20)
    breed: str = Field(default="", max_length=80)
    photo: str | None = Field(default=None, max_length=3_000_000)
    allergies: str = Field(default="", max_length=400)
    conditions: str = Field(default="", max_length=400)
    emergencyNotes: str = Field(default="", max_length=600)
    vetClinic: str = Field(default="", max_length=120)
    vetPhone: str = Field(default="", max_length=40)
    microchip: str = Field(default="", max_length=40)
    lost: LostIn | None = None


@app.put("/api/pets/{pet_id}/public")
def publish_pet(pet_id: str, body: PublicPetIn, token: str = Depends(device)) -> dict[str, str]:
    if body.photo and not body.photo.startswith("data:image/"):
        body.photo = None
    with db() as c:
        row = c.execute("SELECT slug, owner FROM public_pets WHERE pet_id = ?", (pet_id,)).fetchone()
        if row and row["owner"] != token:
            raise HTTPException(403, "Not your pet")
        slug = row["slug"] if row else secrets.token_urlsafe(6).replace("-", "x").replace("_", "y")
        c.execute("INSERT OR REPLACE INTO public_pets VALUES (?, ?, ?, ?, ?)", (pet_id, slug, token, body.model_dump_json(), time.time()))
    return {"slug": slug}


@app.get("/api/pets/{pet_id}/messages")
def pet_messages(pet_id: str, token: str = Depends(device)) -> dict[str, Any]:
    with db() as c:
        row = c.execute("SELECT owner FROM public_pets WHERE pet_id = ?", (pet_id,)).fetchone()
        if not row or row["owner"] != token:
            raise HTTPException(404, "Not found")
        rows = c.execute("SELECT * FROM messages WHERE pet_id = ? ORDER BY created_at DESC LIMIT 50", (pet_id,)).fetchall()
    return {"messages": [{"id": r["id"], "name": r["name"], "phone": r["phone"], "message": r["message"],
                          "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(r["created_at"]))} for r in rows]}


_recent_posts: dict[str, list[float]] = {}


def rate_limited(ip: str, limit: int = 5, window: float = 600) -> bool:
    now = time.time()
    hits = [t for t in _recent_posts.get(ip, []) if now - t < window]
    _recent_posts[ip] = hits + [now]
    return len(hits) >= limit


PAGE_CSS = """
body{margin:0;font:16px/1.5 -apple-system,system-ui,sans-serif;background:#F4EFE7;color:#17201C}
main{max-width:520px;margin:0 auto;padding:24px 18px 48px}
.card{background:#FFFDF9;border-radius:22px;padding:20px;margin:14px 0;border:1px solid #E3DBCE}
.lost{background:#B5382E;color:#fff;border:none}
h1{font:600 38px/1.1 Georgia,serif;margin:6px 0}
.eyebrow{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:#CF5F3B;font-weight:700}
img{width:100%;max-height:360px;object-fit:cover;border-radius:18px}
dt{font-size:13px;color:#5D6962;margin-top:10px}dd{margin:0;font-weight:500}
a.btn,button{display:block;width:100%;text-align:center;background:#17201C;color:#F4EFE7;border:0;border-radius:14px;padding:15px;font:600 17px system-ui;text-decoration:none;margin-top:10px}
input,textarea{width:100%;box-sizing:border-box;border:1px solid #E3DBCE;border-radius:12px;padding:12px;font:16px system-ui;margin-top:8px;background:#fff}
small{color:#5D6962}
"""


def esc(value: Any) -> str:
    return html.escape(str(value or ""))


@app.get("/p/{slug}", response_class=HTMLResponse)
def public_page(slug: str) -> HTMLResponse:
    with db() as c:
        row = c.execute("SELECT pet_id, data FROM public_pets WHERE slug = ?", (slug,)).fetchone()
    if not row:
        raise HTTPException(404, "Not found")
    p = json.loads(row["data"])
    lost = p.get("lost") or {}
    phone = lost.get("contactPhone") or ""
    rows = "".join(f"<dt>{label}</dt><dd>{esc(p.get(key))}</dd>" for label, key in [
        ("Species", "species"), ("Breed", "breed"), ("Allergies", "allergies"), ("Medical conditions", "conditions"),
        ("Notes", "emergencyNotes"), ("Veterinarian", "vetClinic"), ("Vet phone", "vetPhone"), ("Microchip", "microchip")] if p.get(key))
    lost_html = ""
    if lost.get("active"):
        lost_html = f"""<div class="card lost"><div class="eyebrow" style="color:#fff">Lost pet</div>
        <h1 style="font-size:28px">Please help {esc(p['name'])} get home</h1>
        {f'<p><b>Last seen:</b> {esc(lost.get("lastSeen"))}</p>' if lost.get('lastSeen') else ''}
        {f'<p>{esc(lost.get("message"))}</p>' if lost.get('message') else ''}
        {f'<p><b>Reward:</b> {esc(lost.get("reward"))}</p>' if lost.get('reward') else ''}
        {f'<a class="btn" style="background:#fff;color:#B5382E" href="tel:{esc(phone)}">Call {esc(phone)}</a>' if phone else ''}</div>"""
    photo = f'<img src="{esc(p["photo"])}" alt="">' if p.get("photo") else ""
    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="robots" content="noindex"><title>{esc(p['name'])} · PetTrack</title><style>{PAGE_CSS}</style></head><body><main>
    <div class="eyebrow">PetTrack · Pet ID</div><h1>{esc(p['name'])}</h1>{lost_html}{photo}
    <div class="card"><dl style="margin:0">{rows}</dl></div>
    <div class="card"><b>Found {esc(p['name'])}?</b><p><small>Your message goes straight to the owner. Leave a phone number so they can call you back.</small></p>
    <form method="post" action="/p/{esc(slug)}/message"><input name="name" placeholder="Your name" maxlength="60">
    <input name="phone" placeholder="Your phone" maxlength="40"><textarea name="message" rows="3" placeholder="Where is the pet now?" required maxlength="600"></textarea>
    <button type="submit">Send to the owner</button></form></div>
    <p><small>The owner's address is never shown on this page. Information on this page is provided by the owner;
    PetTrack does not verify it. In a medical emergency contact a veterinarian.</small></p></main></body></html>"""
    return HTMLResponse(page)


@app.post("/p/{slug}/message", response_class=HTMLResponse)
def finder_message(slug: str, request: Request, message: str = Form(..., max_length=600), name: str = Form("", max_length=60),
                   phone: str = Form("", max_length=40)) -> HTMLResponse:
    ip = request.client.host if request.client else "?"
    if rate_limited(ip):
        raise HTTPException(429, "Too many messages, please call instead.")
    with db() as c:
        row = c.execute("SELECT pet_id FROM public_pets WHERE slug = ?", (slug,)).fetchone()
        if not row:
            raise HTTPException(404, "Not found")
        c.execute("INSERT INTO messages VALUES (?, ?, ?, ?, ?, ?)", (secrets.token_hex(8), row["pet_id"], name, phone, message, time.time()))
    return HTMLResponse(f"<!doctype html><meta name=viewport content='width=device-width'><style>{PAGE_CSS}</style><main><h1>Thank you!</h1>"
                        f"<p>The owner has your message. If you left a number, they will call you.</p><a class=btn href='/p/{esc(slug)}'>Back</a></main>")


# ---------------------------------------------------------------- OCR

class ScanIn(BaseModel):
    image: str = Field(max_length=12_000_000)


@app.post("/api/scan")
def scan(body: ScanIn, token: str = Depends(device)) -> dict[str, Any]:
    """Recognises text on a vet report photo. Field extraction happens in the app (same parser offline and online)."""
    try:
        import pytesseract
        from PIL import Image, ImageOps
    except ImportError as exc:  # pragma: no cover - only without the OCR extras
        raise HTTPException(503, "OCR is not installed on this server") from exc
    data = body.image.split(",", 1)[-1]
    raw = base64.b64decode(data, validate=False)
    if len(raw) > MAX_IMAGE_BYTES:
        raise HTTPException(413, "Image too large")
    image = ImageOps.exif_transpose(Image.open(io.BytesIO(raw))).convert("L")
    text = pytesseract.image_to_string(image, lang=os.environ.get("OCR_LANGS", "eng+deu+fra+spa+nld"))
    return {"text": text}
