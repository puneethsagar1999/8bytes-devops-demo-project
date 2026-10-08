import os

import pytest

from app import app as flask_app

pytestmark = pytest.mark.skipif(
    not os.getenv("DB_HOST"), reason="needs a real PostgreSQL (set DB_HOST)"
)


def test_create_and_list_note():
    client = flask_app.test_client()
    created = client.post("/api/notes", json={"text": "hello from the test"})
    assert created.status_code == 201

    listed = client.get("/api/notes")
    assert listed.status_code == 200
    assert any(n["text"] == "hello from the test" for n in listed.get_json())