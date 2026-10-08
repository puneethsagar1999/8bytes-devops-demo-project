from unittest.mock import MagicMock, patch

from app import app as flask_app


def client():
    return flask_app.test_client()


def test_health():
    response = client().get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


def test_index_page():
    response = client().get("/")
    assert response.status_code == 200
    assert b"DevOps Demo App" in response.data


def test_metrics_exposes_request_counter():
    client().get("/health")
    response = client().get("/metrics")
    assert response.status_code == 200
    assert b"http_requests_total" in response.data


def test_notes_post_requires_text():
    with patch("app.get_conn", return_value=MagicMock()):
        response = client().post("/api/notes", json={"text": "  "})
    assert response.status_code == 400


def test_notes_list_empty():
    with patch("app.get_conn", return_value=MagicMock()):
        response = client().get("/api/notes")
    assert response.status_code == 200
    assert response.get_json() == []