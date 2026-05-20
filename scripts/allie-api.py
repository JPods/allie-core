#!/usr/bin/env python3
"""
allie-api.py — Allie's outward-facing REST API

Exposes Allie's local LLMs (DeepSeek, Llama, Athena models) to:
  - JPods Raspberry Pi robots (routing/diagnostic queries)
  - WebClerk/Alice (without going through Anthropic)
  - Other local network devices
  - External callers via ngrok tunnel (when enabled)

Port: 5001 (does not conflict with WebClerk on 8000 or Route-Time on 5050)

Authentication: Bearer token from config/allie_api_keys.json

Usage:
  python3 allie-api.py                  — start on 0.0.0.0:5001
  python3 allie-api.py --port 5001      — explicit port
  python3 allie-api.py --local-only     — bind to 127.0.0.1 only
  python3 allie-api.py --no-auth        — disable auth (local dev only)

Runs as LaunchAgent: com.allie.api

External access:
  ngrok http 5001                        — temporary public URL
  cloudflared tunnel --url http://localhost:5001  — persistent public URL
"""

import sys
import json
import time
import datetime
import pathlib
import argparse
import threading
import subprocess
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

ALLIE       = pathlib.Path("/Users/williamjames/Allie")
KEYS_PATH   = ALLIE / "config" / "allie_api_keys.json"
LOG_PATH    = ALLIE / "config" / "agent_log.jsonl"
SCRIPTS     = ALLIE / "scripts"
OLLAMA_URL  = "http://localhost:11434/api/generate"

DEFAULT_REASONER  = "deepseek-r1:8b"
DEFAULT_ADVERSARY = "athena-reason:latest"
DEFAULT_JUDGE     = "llama3.2:latest"

# Global config (set at startup)
NO_AUTH = False


# ── Auth ───────────────────────────────────────────────────────────────────────

def load_keys() -> dict:
    if not KEYS_PATH.exists():
        return {}
    try:
        return json.loads(KEYS_PATH.read_text()).get("keys", {})
    except Exception:
        return {}


def check_auth(auth_header: str) -> tuple:
    """Returns (ok, caller_name). If NO_AUTH, always ok."""
    if NO_AUTH:
        return True, "no-auth"
    if not auth_header or not auth_header.startswith("Bearer "):
        return False, ""
    token = auth_header[len("Bearer "):]
    keys = load_keys()
    for name, key in keys.items():
        if key == token:
            return True, name
    return False, ""


# ── Ollama ────────────────────────────────────────────────────────────────────

def call_ollama(model: str, prompt: str, timeout: int = 120) -> tuple:
    start = time.time()
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.3, "num_predict": 2048},
    }).encode()
    req = urllib.request.Request(
        OLLAMA_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read())
            return body.get("response", "").strip(), time.time() - start, None
    except Exception as e:
        return "", time.time() - start, str(e)


def list_ollama_models() -> list:
    try:
        result = subprocess.run(
            ["ollama", "list"], capture_output=True, text=True, timeout=10
        )
        models = []
        for line in result.stdout.splitlines()[1:]:
            name = line.split()[0] if line.strip() else ""
            if name:
                models.append(name)
        return models
    except Exception:
        return []


# ── Logging ───────────────────────────────────────────────────────────────────

def log_event(entry: dict):
    entry["ts"] = datetime.datetime.now().isoformat(timespec="seconds")
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


# ── Request handler ───────────────────────────────────────────────────────────

class AllieAPIHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        # Suppress default server logging; we log ourselves
        pass

    def send_json(self, status: int, data: dict):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def send_error_json(self, status: int, message: str):
        self.send_json(status, {"error": message})

    def require_auth(self) -> tuple:
        auth = self.headers.get("Authorization", "")
        ok, caller = check_auth(auth)
        if not ok:
            self.send_error_json(401, "Unauthorized — provide Bearer token")
        return ok, caller

    def read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        try:
            return json.loads(self.rfile.read(length))
        except Exception:
            return {}

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/health":
            self.send_json(200, {
                "status": "ok",
                "ts": datetime.datetime.now().isoformat(timespec="seconds"),
                "ollama": "localhost:11434",
            })

        elif path == "/models":
            ok, caller = self.require_auth()
            if not ok:
                return
            models = list_ollama_models()
            self.send_json(200, {"models": models, "count": len(models)})

        else:
            self.send_error_json(404, f"Unknown endpoint: {path}")

    def do_POST(self):
        path = urlparse(self.path).path
        ok, caller = self.require_auth()
        if not ok:
            return
        body = self.read_body()

        # ── POST /ask ──────────────────────────────────────────────────────────
        if path == "/ask":
            model   = body.get("model", DEFAULT_REASONER)
            prompt  = body.get("prompt", "")
            context = body.get("context", "")
            timeout = int(body.get("timeout", 120))

            if not prompt:
                self.send_error_json(400, "prompt required")
                return

            full_prompt = f"{context}\n\n{prompt}".strip() if context else prompt
            response, elapsed, error = call_ollama(model, full_prompt, timeout)

            log_event({
                "event": "api-ask", "caller": caller,
                "model": model, "elapsed_s": round(elapsed, 1),
                "prompt": prompt[:100], "error": error,
            })

            if error:
                self.send_json(503, {"error": error, "model": model})
            else:
                self.send_json(200, {
                    "model": model, "response": response,
                    "elapsed_s": round(elapsed, 1),
                })

        # ── POST /deliberate ───────────────────────────────────────────────────
        elif path == "/deliberate":
            prompt   = body.get("prompt", "")
            rounds   = int(body.get("rounds", 1))
            reasoner  = body.get("reasoner",  DEFAULT_REASONER)
            adversary = body.get("adversary", DEFAULT_ADVERSARY)
            judge     = body.get("judge",     DEFAULT_JUDGE)
            timeout  = int(body.get("timeout", 300))

            if not prompt:
                self.send_error_json(400, "prompt required")
                return

            stages = []

            # Stage 1 — Reasoner
            r_prompt = f"You are Allie's reasoning engine. Answer directly and specifically:\n\n{prompt}"
            claim, elapsed, error = call_ollama(reasoner, r_prompt, timeout)
            if error:
                self.send_json(503, {"error": f"Reasoner failed: {error}"})
                return
            stages.append({"stage": "reasoner", "model": reasoner,
                            "response": claim, "elapsed_s": round(elapsed, 1)})

            # Stage 2 — Adversary
            a_prompt = (
                f"Probe the following claim for hallucinations, contradictions, "
                f"and overreach. Quote exact phrases. Be specific.\n\n"
                f"Original question: {prompt}\n\nClaim: {claim}"
            )
            critique, elapsed, error = call_ollama(adversary, a_prompt, timeout)
            if error:
                self.send_json(503, {"error": f"Adversary failed: {error}"})
                return
            stages.append({"stage": "adversary", "model": adversary,
                            "response": critique, "elapsed_s": round(elapsed, 1)})

            # Stage 3 — Judge
            j_prompt = (
                f"Adjudicate. For each critique point: stands or fails + one sentence why. "
                f"Produce revised synthesis. Final verdict: SUBSTANTIALLY CORRECT | "
                f"PARTIALLY CORRECT | SUBSTANTIALLY WRONG.\n\n"
                f"Question: {prompt}\nClaim: {claim}\nCritique: {critique}"
            )
            verdict, elapsed, error = call_ollama(judge, j_prompt, timeout)
            if error:
                self.send_json(503, {"error": f"Judge failed: {error}"})
                return
            stages.append({"stage": "judge", "model": judge,
                            "response": verdict, "elapsed_s": round(elapsed, 1)})

            log_event({
                "event": "api-deliberate", "caller": caller,
                "stages": len(stages), "prompt": prompt[:100],
            })

            self.send_json(200, {
                "prompt": prompt,
                "stages": stages,
                "verdict": verdict,
            })

        # ── POST /reflect ──────────────────────────────────────────────────────
        elif path == "/reflect":
            days    = int(body.get("days", 7))
            model   = body.get("model", DEFAULT_REASONER)
            timeout = int(body.get("timeout", 300))

            try:
                result = subprocess.run(
                    [sys.executable,
                     str(SCRIPTS / "allie-reflect.py"),
                     "--days", str(days),
                     "--model", model,
                     "--timeout", str(timeout)],
                    capture_output=True, text=True, timeout=timeout + 30,
                )
                log_event({"event": "api-reflect", "caller": caller, "days": days})
                self.send_json(200, {
                    "status": "ok" if result.returncode == 0 else "error",
                    "stdout": result.stdout[-2000:],
                    "stderr": result.stderr[-500:] if result.stderr else "",
                })
            except subprocess.TimeoutExpired:
                self.send_json(503, {"error": "reflect timed out"})
            except Exception as e:
                self.send_json(503, {"error": str(e)})

        else:
            self.send_error_json(404, f"Unknown endpoint: {path}")


# ── Server ────────────────────────────────────────────────────────────────────

def run(host: str = "0.0.0.0", port: int = 5001):
    server = HTTPServer((host, port), AllieAPIHandler)
    print(f"[allie-api] Listening on {host}:{port}")
    print(f"  Auth keys: {KEYS_PATH}")
    print(f"  No-auth mode: {NO_AUTH}")
    print(f"  Local network URL: http://$(ipconfig getifaddr en0):{port}")
    print(f"  Health: GET http://localhost:{port}/health")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[allie-api] Stopped.")


# ── Setup helper ──────────────────────────────────────────────────────────────

def setup_keys():
    """Interactive: generate API keys for each caller."""
    import secrets
    KEYS_PATH.parent.mkdir(parents=True, exist_ok=True)

    existing = {}
    if KEYS_PATH.exists():
        existing = json.loads(KEYS_PATH.read_text()).get("keys", {})

    callers = ["jpods-pi", "webclerk-alice", "external", "bill"]
    for caller in callers:
        if caller not in existing:
            existing[caller] = secrets.token_urlsafe(32)
            print(f"  Generated key for '{caller}': {existing[caller]}")
        else:
            print(f"  Existing key for '{caller}': {existing[caller]}")

    KEYS_PATH.write_text(json.dumps({"keys": existing}, indent=2))
    KEYS_PATH.chmod(0o600)
    print(f"\nSaved to {KEYS_PATH} (mode 600)")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    global NO_AUTH

    parser = argparse.ArgumentParser(description="Allie outward-facing API server")
    parser.add_argument("--port",       type=int, default=5001)
    parser.add_argument("--local-only", action="store_true", help="Bind to 127.0.0.1 only")
    parser.add_argument("--no-auth",    action="store_true", help="Disable auth (dev only)")
    parser.add_argument("--setup-keys", action="store_true", help="Generate API keys and exit")
    args = parser.parse_args()

    if args.setup_keys:
        setup_keys()
        return

    NO_AUTH = args.no_auth
    host = "127.0.0.1" if args.local_only else "0.0.0.0"
    run(host=host, port=args.port)


if __name__ == "__main__":
    main()
