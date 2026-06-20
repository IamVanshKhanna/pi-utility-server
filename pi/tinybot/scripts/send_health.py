import os
import subprocess
import psutil
import requests

TINYBOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_token():
    path = os.path.join(TINYBOT_DIR, '.env')
    with open(path, 'r') as f:
        for line in f:
            if line.startswith('TELEGRAM_BOT_TOKEN='):
                return line.split('=')[1].strip().strip('"').strip("'")
    return None

def load_chat_id():
    path = os.path.join(TINYBOT_DIR, 'state', 'admin_chat.txt')
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except:
        return None

def get_stats():
    ram = psutil.virtual_memory()
    temp_raw = subprocess.getoutput('vcgencmd measure_temp').replace('temp=', '').strip()
    gpio = subprocess.getoutput('pinctrl 12 2>/dev/null').strip()
    deskpi = subprocess.getoutput('systemctl is-active deskpi.service 2>/dev/null').strip()
    load = open('/proc/loadavg').read().split()[:3]
    load_str = ' '.join(load)
    if deskpi == 'active':
        fan_status = 'ON (PWM auto)'
    elif 'hi' in gpio.lower():
        fan_status = 'ON (GPIO fixed)'
    else:
        fan_status = 'OFF'
    try:
        with open('/sys/class/thermal/thermal_zone0/temp') as f:
            temp_c = '{:.1f}C'.format(int(f.read().strip()) / 1000)
    except:
        temp_c = temp_raw
    msg = 'Scheduled Health Report:\n'
    msg += 'Temp: {}\n'.format(temp_c)
    msg += 'RAM: {:.2f}GB / {:.2f}GB\n'.format(ram.used / (1024**3), ram.total / (1024**3))
    msg += 'Load: {}\n'.format(load_str)
    msg += 'Fan: {}\n'.format(fan_status)
    msg += 'GPIO12: {}'.format(gpio)
    return msg

token = load_token()
chat_id = load_chat_id()
if token and chat_id:
    url = 'https://api.telegram.org/bot{}/sendMessage'.format(token)
    requests.post(url, json={'chat_id': chat_id, 'text': get_stats()})

