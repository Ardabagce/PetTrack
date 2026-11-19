import os, tempfile
os.environ["DATA_DIR"] = tempfile.mkdtemp()
from fastapi.testclient import TestClient
from app import app

client = TestClient(app)

def token():
    return {"Authorization": "Bearer " + client.post("/api/devices").json()["token"]}

def test_household_flow():
    owner, member = token(), token()
    created = client.post("/api/household", json={"name": "Alex"}, headers=owner).json()
    joined = client.post("/api/household/join", json={"code": created["code"].replace("-", ""), "name": "Sam"}, headers=member).json()
    assert joined["members"] == ["Alex", "Sam"]
    pets = [{"id": "p1", "name": "Luna", "species": "dog"}]
    client.post("/api/household/sync", json={"since": "2026-01-01", "events": [], "pets": pets}, headers=owner)
    ev = {"id": "e1", "petId": "p1", "kind": "meal", "date": "2026-11-19T08:00:00Z", "fedBy": "Sam"}
    client.post("/api/household/events", json={"events": [ev]}, headers=member)
    res = client.post("/api/household/sync", json={"since": "2026-11-01", "events": []}, headers=owner).json()
    assert [e["fedBy"] for e in res["events"]] == ["Sam"]
    res_member = client.post("/api/household/sync", json={"since": "2026-11-01", "events": []}, headers=member).json()
    assert res_member["pets"][0]["name"] == "Luna" and res_member["events"] == []

def test_public_page_and_messages():
    owner = token()
    slug = client.put("/api/pets/p9/public", json={"name": "Milo <b>", "species": "cat", "lost": {"active": True, "contactPhone": "+1 555"}}, headers=owner).json()["slug"]
    page = client.get(f"/p/{slug}").text
    assert "Milo &lt;b&gt;" in page and "Please help" in page
    client.post(f"/p/{slug}/message", data={"message": "He is with me", "phone": "123"})
    msgs = client.get("/api/pets/p9/messages", headers=owner).json()["messages"]
    assert msgs[0]["message"] == "He is with me"
    assert client.get("/api/pets/p9/messages", headers=token()).status_code == 404
    assert client.put("/api/pets/p9/public", json={"name": "x", "species": "cat"}, headers=token()).status_code == 403

def test_requires_token():
    assert client.post("/api/household", json={"name": "A"}).status_code == 401

def test_delete_device_removes_everything():
    owner = token()
    client.post("/api/household", json={"name": "Alex"}, headers=owner)
    slug = client.put("/api/pets/pz/public", json={"name": "Z", "species": "dog"}, headers=owner).json()["slug"]
    assert client.delete("/api/devices/me", headers=owner).json() == {"deleted": True}
    assert client.get(f"/p/{slug}").status_code == 404
    assert client.post("/api/household", json={"name": "A"}, headers=owner).status_code == 401
