import os
import json
import shutil
import yaml
from datetime import datetime, timezone

HERMES_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECTS_DIR = os.path.join(HERMES_ROOT, 'projects')
QUEUE_DIR = os.path.join(HERMES_ROOT, 'queue')
STATE_DIR = os.path.join(HERMES_ROOT, 'state')
LOGS_DIR = os.path.join(HERMES_ROOT, 'logs')
CONFIG_DIR = os.path.join(HERMES_ROOT, 'config')
PROFILES_DIR = os.path.join(HERMES_ROOT, 'pi', 'profiles')


def load_global_state():
    path = os.path.join(STATE_DIR, 'global.yaml')
    if not os.path.exists(path):
        return {'devices': {}, 'projects': {}, 'queue_depth': 0}
    with open(path) as f:
        return yaml.safe_load(f) or {}


def save_global_state(state):
    path = os.path.join(STATE_DIR, 'global.yaml')
    with open(path, 'w') as f:
        yaml.dump(state, f, default_flow_style=False)


def create_project(project_id, name, thread_id):
    project_dir = os.path.join(PROJECTS_DIR, project_id)
    state_dir = os.path.join(project_dir, 'state')
    os.makedirs(state_dir, exist_ok=True)
    os.makedirs(os.path.join(project_dir, 'artifacts'), exist_ok=True)
    os.makedirs(os.path.join(project_dir, 'history'), exist_ok=True)
    base = {
        'project_id': project_id,
        'name': name,
        'thread_id': thread_id,
        'created_at': datetime.now(timezone.utc).isoformat(),
        'status': 'active',
    }
    with open(os.path.join(state_dir, 'base.json'), 'w') as f:
        json.dump(base, f, indent=2)
    with open(os.path.join(state_dir, 'summary.md'), 'w') as f:
        f.write(f'# {name}\n\nProject created.\n')
    return project_id


def write_packet(project_id, packet):
    state_dir = os.path.join(PROJECTS_DIR, project_id, 'state')
    os.makedirs(state_dir, exist_ok=True)
    with open(os.path.join(state_dir, 'current.json'), 'w') as f:
        json.dump(packet, f, indent=2)
    history_dir = os.path.join(PROJECTS_DIR, project_id, 'history')
    os.makedirs(history_dir, exist_ok=True)
    step = packet.get('step_number', 1)
    with open(os.path.join(history_dir, f'packet_{step:03d}.json'), 'w') as f:
        json.dump(packet, f, indent=2)


def route_packet(packet):
    target = packet.get('target_device', 'pending')
    queue_file = os.path.join(QUEUE_DIR, target, f"{packet['packet_id']}.json")
    os.makedirs(os.path.dirname(queue_file), exist_ok=True)
    with open(queue_file, 'w') as f:
        json.dump(packet, f, indent=2)


def get_queue_length():
    pending_dir = os.path.join(QUEUE_DIR, 'pending')
    if not os.path.exists(pending_dir):
        return 0
    return len([f for f in os.listdir(pending_dir) if f.endswith('.json')])


def log_audit(action, profile, details, result='success'):
    os.makedirs(LOGS_DIR, exist_ok=True)
    entry = {
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'action': action,
        'profile': profile,
        'details': details,
        'result': result,
    }
    with open(os.path.join(LOGS_DIR, 'audit.log'), 'a') as f:
        f.write(json.dumps(entry) + '\n')
