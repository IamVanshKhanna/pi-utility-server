#!/usr/bin/env python3
"""Tinybot health report - sends system status to Telegram every 6 hours."""
import os
import json
import subprocess
import urllib.request
import yaml
from datetime import datetime

HERMES_ROOT = os.path.expanduser("~/hermes-bot")
QUEUE_DIR = os.path.join(HERMES_ROOT, "queue")
ENV_PATH = os.path.join(HERMES_ROOT, ".env")

def get_token():
    if os.path.exists(ENV_PATH):
        with open(ENV_PATH) as f:
            for line in f:
                line = line.strip()
                if line.startswith("TELEGRAM_BOT_TOKEN="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ.get("TELEGRAM_BOT_TOKEN")

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, timeout=10).decode().strip()
    except Exception:
        return "N/A"

def queue_counts():
    counts = {}
    for d in ["pending", "running", "completed"]:
        path = os.path.join(QUEUE_DIR, d)
        if os.path.isdir(path):
            counts[d] = len([f for f in os.listdir(path) if f.endswith(".json")])
        else:
            counts[d] = 0
    return counts

def recent_logs(n=5):
    log_file = os.path.join(HERMES_ROOT, "logs", "audit.log")
    if not os.path.exists(log_file):
        return []
    with open(log_file) as f:
        lines = f.readlines()
    return [json.loads(l) for l in lines[-n:]]

def send_telegram(token, chat_id, text):
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = json.dumps({"chat_id": chat_id, "text": text, "parse_mode": "HTML"}).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())

def active_chat_ids():
    path = os.path.join(HERMES_ROOT, "state", "global.yaml")
    if not os.path.exists(path):
        return []
    with open(path) as f:
        state = yaml.safe_load(f) or {}
    return list(state.get("projects", {}).keys())

def main():
    token = get_token()
    if not token:
        print("No bot token found")
        return

    chat_ids = active_chat_ids()
    uptime = run("uptime -p")
    temp = run("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
    if temp != "N/A":
        temp_c = round(int(temp) / 1000, 1)
        temp_str = f"{temp_c}°C"
    else:
        temp_str = "N/A"
    disk = run("df -h / | tail -1 | awk '{print $3, \"/\", $2, \"(\", $5, \")\"}'")
    mem = run("free -h | grep Mem | awk '{print $3, \"/\", $2}'")
    load = run("cat /proc/loadavg | awk '{print $1, $2, $3}'")

    q = queue_counts()
    logs = recent_logs()

    msg = f"""<b>Tinybot Health Report</b> — {datetime.now().strftime('%Y-%m-%d %H:%M UTC')}

<b>System</b>
Uptime: {uptime}
Temp: {temp_str}
Disk: {disk}
Memory: {mem}
Load: {load}

<b>Queue</b>
Pending: {q['pending']} | Running: {q['running']} | Completed: {q['completed']}

<b>Recent Activity</b>
"""
    if logs:
        for entry in logs[-3:]:
            ts = entry.get("timestamp", "?")[11:19]
            action = entry.get("action", "?")
            details = str(entry.get("details", ""))[:80]
            msg += f"  {ts} — {action}: {details}\n"
    else:
        msg += "  (no activity yet)\n"

    msg += "\n<i>Next report in ~6 hours</i>"

    if chat_ids:
        for cid in chat_ids:
            try:
                send_telegram(token, cid, msg)
                print(f"Report sent to {cid}")
            except Exception as e:
                print(f"Failed to send to {cid}: {e}")
    else:
        print("No active chats found. Message the bot first to register a chat.")
        print("Report:")
        print(msg)

if __name__ == "__main__":
    main()
