from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import signal
import sys
import urllib.request

ALERTMANAGER_URL = os.environ.get("ALERTMANAGER_URL", "")
RELAY_TOKEN = os.environ.get("RELAY_TOKEN", "")
TIMEOUT = int(os.environ.get("TIMEOUT", "10"))
MAX_BODY = 1 * 1024 * 1024  # 1MB


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        auth = self.headers.get("Authorization", "").removeprefix("Bearer ").strip()
        if RELAY_TOKEN and auth != RELAY_TOKEN:
            self.send_response(401)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        if length > MAX_BODY:
            self.send_response(413)
            self.end_headers()
            return

        raw = self.rfile.read(length)
        try:
            body = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"JSON parse error: {e}")
            self.send_response(400)
            self.end_headers()
            return

        alerts = []
        for a in body if isinstance(body, list) else [body]:
            src = a.get("Source", {})
            alerts.append({
                "labels": {
                    "alertname": f"crowdsec_{a.get('Scenario', 'unknown')}",
                    "source": "crowdsec",
                    "ip": src.get("Value", "unknown"),
                    "severity": "critical" if a.get("EventsCount", 0) > 5 else "warning",
                },
                "annotations": {
                    "summary": f"CrowdSec: {a.get('Scenario', 'unknown')} from {src.get('Value', 'unknown')}",
                    "description": f"{src.get('Value', 'unknown')} - {a.get('Scenario', 'unknown')} - {a.get('EventsCount', 0)} events",
                },
            })

        payload = json.dumps(alerts).encode()
        req = urllib.request.Request(
            ALERTMANAGER_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        try:
            resp = urllib.request.urlopen(req, timeout=TIMEOUT)
            print(f"OK: {resp.status} - forwarded {len(alerts)} alert(s)")
            self.send_response(200)
        except Exception as e:
            print(f"Alertmanager: {e}")
            self.send_response(502)
        self.end_headers()

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")


def shutdown_handler(signum, frame):
    print(f"Received signal {signum}, shutting down...")
    sys.exit(0)


signal.signal(signal.SIGTERM, shutdown_handler)
signal.signal(signal.SIGINT, shutdown_handler)

server = HTTPServer(("127.0.0.1", 8085), Handler)
print(f"Relay listening on 127.0.0.1:8085 (auth={'enabled' if RELAY_TOKEN else 'disabled'})")
server.serve_forever()
