import os
import json
import re
import yaml
from datetime import datetime, timezone

CONFIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'config')
STATE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'state')
PENDING_FILE = os.path.join(STATE_DIR, 'approval_pending.json')


def load_approval_rules():
    path = os.path.join(CONFIG_DIR, 'approval_rules.yaml')
    if not os.path.exists(path):
        return {'risk_levels': {}, 'action_patterns': []}
    with open(path) as f:
        return yaml.safe_load(f) or {}


def classify_risk(packet):
    rules = load_approval_rules()
    action_desc = packet.get('latest_user_instruction', '')
    for rule in rules.get('action_patterns', []):
        if re.search(rule['pattern'], action_desc):
            return rule.get('risk', 'low')
    return 'low'


def needs_approval(packet):
    return classify_risk(packet) in ('high', 'medium')


def request_approval(packet):
    pending = load_pending_approvals()
    entry = {
        'approval_id': f"A{len(pending) + 1:04d}",
        'packet': packet,
        'risk': classify_risk(packet),
        'created_at': datetime.now(timezone.utc).isoformat(),
        'status': 'pending',
    }
    pending.append(entry)
    with open(PENDING_FILE, 'w') as f:
        json.dump(pending, f, indent=2)
    return entry


def load_pending_approvals():
    if not os.path.exists(PENDING_FILE):
        return []
    with open(PENDING_FILE) as f:
        return json.load(f)


def save_pending_approvals(approvals):
    with open(PENDING_FILE, 'w') as f:
        json.dump(approvals, f, indent=2)


def handle_approval_response(approval_id, decision, reason=''):
    approvals = load_pending_approvals()
    for i, entry in enumerate(approvals):
        if entry['approval_id'] == approval_id:
            if decision == 'approve':
                entry['status'] = 'approved'
                save_pending_approvals([a for a in approvals if a['approval_id'] != approval_id])
                return 'approved', entry['packet']
            elif decision == 'reject':
                entry['status'] = 'rejected'
                entry['reason'] = reason
                save_pending_approvals([a for a in approvals if a['approval_id'] != approval_id])
                return 'rejected', entry['packet']
            elif decision == 'defer':
                entry['status'] = 'deferred'
                entry['rescheduled_at'] = reason
                approvals[i] = entry
                save_pending_approvals(approvals)
                return 'deferred', entry['packet']
    return None, None
