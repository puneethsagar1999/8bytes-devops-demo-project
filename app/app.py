import os
import time

import psycopg2
from flask import Flask, Response, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

app = Flask(__name__)

REQUESTS = Counter(
    "http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"]
)
LATENCY = Histogram(
    "http_request_duration_seconds", "Request latency in seconds", ["endpoint"]
)


def get_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "appdb"),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=3,
    )


@app.before_request
def start_timer():
    g.start = time.time()


@app.after_request
def record_metrics(response):
    if request.path != "/metrics":
        endpoint = request.url_rule.rule if request.url_rule else "unknown"
        LATENCY.labels(endpoint).observe(time.time() - g.start)
        REQUESTS.labels(request.method, endpoint, response.status_code).inc()
    return response


@app.errorhandler(psycopg2.OperationalError)
def db_unavailable(_error):
    return jsonify(error="database unavailable"), 503


@app.route("/")
def index():
    return (
        "<h1>DevOps Demo App</h1>"
        "<p>Frontend is running. Try <a href='/api/notes'>/api/notes</a>, "
        "<a href='/health'>/health</a>, <a href='/metrics'>/metrics</a>.</p>"
    )


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/ready")
def ready():
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
    finally:
        conn.close()
    return jsonify(status="ready")


@app.route("/api/notes", methods=["GET", "POST"])
def notes():
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS notes ("
                "id SERIAL PRIMARY KEY, text TEXT NOT NULL, "
                "created_at TIMESTAMP DEFAULT NOW())"
            )
            if request.method == "POST":
                text = (request.get_json(silent=True) or {}).get("text", "").strip()
                if not text:
                    return jsonify(error="text is required"), 400
                cur.execute(
                    "INSERT INTO notes (text) VALUES (%s) RETURNING id", (text,)
                )
                return jsonify(id=cur.fetchone()[0], text=text), 201
            cur.execute("SELECT id, text FROM notes ORDER BY id DESC LIMIT 20")
            return jsonify([{"id": r[0], "text": r[1]} for r in cur.fetchall()])
    finally:
        conn.close()


@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)