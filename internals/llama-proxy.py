#!/usr/bin/env python3
"""
Debug proxy: sits between nanocoder and llama.cpp, dumps the system prompt
from every /v1/chat/completions request to .hva-state/prompts/N.txt

Usage:
  # Terminal 1 — run proxy (default: listen 8081, forward to 8080)
  python3 internals/llama-proxy.py

  # Terminal 2 — run hva pointed at proxy port
  LLAMA_HOST_PORT=8081 hva

After two sessions, diff the captured prompts:
  diff .hva-state/prompts/1.txt .hva-state/prompts/2.txt | head -60
"""

import http.server
import http.client
import json
import os
import sys
import urllib.parse

LISTEN_PORT  = int(os.environ.get("PROXY_PORT",   "8081"))
FORWARD_HOST = os.environ.get("FORWARD_HOST", "127.0.0.1")
FORWARD_PORT = int(os.environ.get("FORWARD_PORT", "8080"))
OUT_DIR      = os.path.join(os.path.dirname(__file__), "..", ".hva-state", "prompts")

os.makedirs(OUT_DIR, exist_ok=True)
_req_count = 0
_session_count = 0
_last_msg_count = 0


def save_request(body_bytes):
    global _req_count, _session_count, _last_msg_count
    try:
        data = json.loads(body_bytes)
    except Exception:
        return
    messages = data.get("messages", [])
    if not messages:
        return

    _req_count += 1
    msg_count = len(messages)

    # New "session" = fewer messages than last time (session reset)
    if msg_count <= _last_msg_count:
        _session_count += 1
    _last_msg_count = msg_count

    # Save system prompt (text only, as before)
    system = next((m["content"] for m in messages if m.get("role") == "system"), None)
    if system:
        path = os.path.join(OUT_DIR, f"sys-{_req_count}.txt")
        with open(path, "w") as f:
            f.write(system)

    # Save full messages as JSON
    full_path = os.path.join(OUT_DIR, f"full-{_req_count}.json")
    with open(full_path, "w") as f:
        json.dump(messages, f, indent=2)

    # Summary
    roles = [m.get("role","?") for m in messages]
    lens = []
    for m in messages:
        c = m.get("content","")
        if isinstance(c, list):
            c = " ".join(x.get("text","") if isinstance(x, dict) else str(x) for x in c)
        lens.append(len(str(c)))
    print(f"[proxy] req #{_req_count} (session {_session_count}): {msg_count} msgs {roles[:6]}, char lens {lens[:6]}", flush=True)


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # suppress default access log

    def _forward(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""

        if self.path.rstrip("/").endswith("/chat/completions") and self.command == "POST":
            save_request(body)

        conn = http.client.HTTPConnection(FORWARD_HOST, FORWARD_PORT, timeout=300)
        headers = {k: v for k, v in self.headers.items()
                   if k.lower() not in ("host", "connection", "transfer-encoding")}
        conn.request(self.command, self.path, body=body or None, headers=headers)
        resp = conn.getresponse()
        resp_body = resp.read()

        self.send_response(resp.status)
        for k, v in resp.getheaders():
            if k.lower() in ("transfer-encoding",):
                continue
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(resp_body)))
        self.end_headers()
        self.wfile.write(resp_body)
        conn.close()

    def do_GET(self):    self._forward()
    def do_POST(self):   self._forward()
    def do_DELETE(self): self._forward()
    def do_PUT(self):    self._forward()


if __name__ == "__main__":
    print(f"[proxy] listening on :{LISTEN_PORT} → {FORWARD_HOST}:{FORWARD_PORT}", flush=True)
    print(f"[proxy] prompts → {os.path.abspath(OUT_DIR)}/", flush=True)
    print(f"[proxy] run hva with:  LLAMA_HOST_PORT={LISTEN_PORT} hva", flush=True)
    server = http.server.HTTPServer(("0.0.0.0", LISTEN_PORT), ProxyHandler)
    server.serve_forever()
