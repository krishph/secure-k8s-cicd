"""Small voting API. Redis is the shared store; it is never exposed to browsers."""

import os

from flask import Flask, jsonify, request
from redis import Redis
from redis.exceptions import RedisError

CHOICES = ("cats", "dogs")


def create_app(store=None):
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 1024
    db = store if store is not None else Redis.from_url(
        os.environ.get("REDIS_URL", "redis://redis:6379/0"),
        decode_responses=True,
        socket_connect_timeout=2,
        socket_timeout=2,
    )

    @app.after_request
    def headers(response):
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    @app.errorhandler(RedisError)
    def unavailable(_error):
        return jsonify(error="Vote storage is temporarily unavailable"), 503

    @app.get("/healthz")
    def health():
        return jsonify(status="ok")

    @app.get("/readyz")
    def ready():
        db.ping()
        return jsonify(status="ready")

    @app.get("/api/results")
    def results():
        counts = db.hmget("votes", CHOICES)
        return jsonify({choice: int(count or 0) for choice, count in zip(CHOICES, counts)})

    @app.post("/api/vote")
    def vote():
        if not request.is_json:
            return jsonify(error="Send application/json"), 415
        payload = request.get_json(silent=True)
        if not isinstance(payload, dict) or payload.get("choice") not in CHOICES:
            return jsonify(error="choice must be cats or dogs"), 400
        choice = payload["choice"]
        # Atomic increment avoids losing votes across concurrent workers.
        count = db.hincrby("votes", choice, 1)
        return jsonify(choice=choice, votes=count), 201

    return app


app = create_app()
