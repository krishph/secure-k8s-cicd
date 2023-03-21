import unittest
from unittest.mock import Mock

from redis.exceptions import ConnectionError

from app import create_app


class VotingTests(unittest.TestCase):
    def setUp(self):
        self.db = Mock()
        self.client = create_app(self.db).test_client()

    def test_vote_uses_atomic_increment(self):
        self.db.hincrby.return_value = 7
        response = self.client.post("/api/vote", json={"choice": "cats"})
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json, {"choice": "cats", "votes": 7})
        self.db.hincrby.assert_called_once_with("votes", "cats", 1)

    def test_invalid_votes_do_not_write(self):
        for body in ({"choice": "other"}, {}, [], None, {"choice": ["cats"]}):
            with self.subTest(body=body):
                response = self.client.post("/api/vote", json=body, content_type="application/json")
                self.assertEqual(response.status_code, 400)
        self.db.hincrby.assert_not_called()

    def test_non_json_rejected(self):
        self.assertEqual(self.client.post("/api/vote", data="cats").status_code, 415)

    def test_results_start_at_zero(self):
        self.db.hmget.return_value = [None, "3"]
        self.assertEqual(self.client.get("/api/results").json, {"cats": 0, "dogs": 3})

    def test_readiness_fails_but_liveness_survives_storage_outage(self):
        self.db.ping.side_effect = ConnectionError("private connection detail")
        response = self.client.get("/readyz")
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private", response.get_data(as_text=True))
        self.assertEqual(self.client.get("/healthz").status_code, 200)

    def test_oversized_request_rejected(self):
        response = self.client.post("/api/vote", json={"choice": "cats", "extra": "x" * 2048})
        self.assertEqual(response.status_code, 413)
        self.db.hincrby.assert_not_called()


if __name__ == "__main__":
    unittest.main()
