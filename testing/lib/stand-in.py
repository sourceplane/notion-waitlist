#!/usr/bin/env python3
"""A local stand-in for the two APIs a signup calls: Notion's and Resend's.

    stand-in.py <port-file> <log-file>

Listens on a free 127.0.0.1 port (written to <port-file> once it is
listening) and answers what the site's two routes send, as the services
would — a page for POST /v1/pages (Notion), an email id for POST /emails
(Resend) — appending every request it is sent to <log-file> as one JSON
line: method, path, the headers that matter, and the body as JSON. The e2e
tier points the Worker at it (NOTION_API_BASE_URL, RESEND_BASE_URL) and
reads the log: what reaches Notion and Resend is the template's own request.
Nothing here talks to the network.
"""
import json
import sys
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

port_file, log_file = sys.argv[1], sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("content-length") or 0))
        try:
            body = json.loads(raw or b"null")
        except ValueError:
            body = {"unparsed": raw.decode(errors="replace")}
        entry = {
            "method": "POST",
            "path": self.path,
            "authorization": self.headers.get("authorization"),
            "notion-version": self.headers.get("notion-version"),
            "body": body,
        }
        with open(log_file, "a") as f:
            f.write(json.dumps(entry) + "\n")
        if self.path == "/v1/pages":
            self._send(200, {"object": "page", "id": str(uuid.uuid4()), "properties": body.get("properties", {})})
        elif self.path == "/emails":
            self._send(200, {"id": str(uuid.uuid4())})
        else:
            self._send(404, {"object": "error", "status": 404, "code": "object_not_found", "message": self.path})


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
