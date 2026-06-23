from http.server import HTTPServer, BaseHTTPRequestHandler
import json, os, urllib.request, socket

ALERTMANAGER_URL = os.environ.get("ALERTMANAGER_URL", "http://100.74.111.26:9093/api/v1/alerts")
TIMEOUT = int(os.environ.get("TIMEOUT", "10"))

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        try:
            body = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"JSON parse error: {e}")
            print(f"Raw: {raw[:500]}")
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
        except Exception as e:
            print(f"Alertmanager: {e}")
        self.send_response(200)
        self.end_headers()

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")

HTTPServer(("0.0.0.0", 8085), Handler).serve_forever()
