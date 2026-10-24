"""
API server for the AgroLens feed page — plain stdlib http.server, no framework.
Serves the exact JSON contract the Flutter HomeScreen widget expects:

    GET /news/                -> all articles, newest first
    GET /news/?category=alert -> filtered by category

Response: JSON array of objects shaped like NewsArticle.fromJson expects:
    { "doc_id": ..., "title": ..., "summary": ..., "url": ...,
      "source": ..., "category": ..., "publishedAt": <ISO 8601 string> }
"""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

from Db import get_connection, get_latest_articles, search_articles


def serialize_article(row):
    """Maps our Postgres row (id/url/published_at/...) to the Flutter-expected shape."""
    return {
        "doc_id": row["id"],
        "title": row["title"],
        "summary": row["summary"] or "",
        "url": row["url"],
        "source": row["source"],
        "category": row["category"],
        # isoformat() with tz gives e.g. "2026-09-05T12:00:00+00:00" — DateTime.parse handles this fine
        "publishedAt": row["published_at"].isoformat() if row["published_at"] else None,
    }


class NewsRequestHandler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        # Flutter web builds need this; harmless for mobile
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        if parsed.path == "/news/" or parsed.path == "/news":
            category = params.get("category", [None])[0]
            search_query = params.get("q", [None])[0]

            conn = get_connection()
            try:
                if search_query:
                    rows = search_articles(conn, search_query)
                else:
                    rows = get_latest_articles(conn, category=category if category != "all" else None)
                articles = [serialize_article(row) for row in rows]
                self._send_json(200, articles)
            except Exception as exc:
                print(f"[api] error handling {self.path}: {exc}")
                self._send_json(500, {"error": "internal server error"})
            finally:
                conn.close()
            return

        self._send_json(404, {"error": "not found"})

    def log_message(self, format, *args):
        # Keep default console logging; override if you want quieter/structured logs later
        super().log_message(format, *args)


def run(host="0.0.0.0", port=8000):
    server = ThreadingHTTPServer((host, port), NewsRequestHandler)
    print(f"AgroLens feed API running on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run()