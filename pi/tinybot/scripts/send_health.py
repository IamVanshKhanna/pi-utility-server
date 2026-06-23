import os
import subprocess
import psutil
import requests

TINYBOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env_var(key):
    path = os.path.join(TINYBOT_DIR, ".env")
    if not os.path.exists(path):
        return os.environ.get(key)
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith(f"{key}="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ.get(key)


def run_safe(cmd):
    try:
        return subprocess.check_output(cmd, timeout=10).decode().strip()
    except Exception:
        return ""


def get_stats():
    ram = psutil.virtual_memory()
    temp_raw = run_safe(["vcgencmd", "measure_temp"]).replace("temp=", "").strip()
    gpio = run_safe(["pinctrl", "12"]).strip()
    deskpi = run_safe(["systemctl", "is-active", "deskpi.service"]).strip()
    with open("/proc/loadavg") as f:
        load = f.read().split()[:3]
    load_str = " ".join(load)
    if deskpi == "active":
        fan_status = "ON (PWM auto)"
    elif "hi" in gpio.lower():
        fan_status = "ON (GPIO fixed)"
    else:
        fan_status = "OFF"
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            temp_c = "{:.1f}C".format(int(f.read().strip()) / 1000)
    except Exception:
        temp_c = temp_raw
    msg = "Scheduled Health Report:\n"
    msg += "Temp: {}\n".format(temp_c)
    msg += "RAM: {:.2f}GB / {:.2f}GB\n".format(ram.used / (1024**3), ram.total / (1024**3))
    msg += "Load: {}\n".format(load_str)
    msg += "Fan: {}\n".format(fan_status)
    msg += "GPIO12: {}".format(gpio)
    return msg


token = load_env_var("TELEGRAM_BOT_TOKEN")
chat_id = load_env_var("TELEGRAM_CHAT_ID")
if token and chat_id:
    url = "https://api.telegram.org/bot{}/sendMessage".format(token)
    requests.post(url, json={"chat_id": chat_id, "text": get_stats()})
