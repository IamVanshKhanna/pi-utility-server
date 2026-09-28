#!/usr/bin/env bash
# Render the private Headscale config from a template before starting the stack.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -n "${PI_ENV_FILE:-}" ]]; then
  ENV_FILE="$PI_ENV_FILE"
elif [[ -f "$ROOT_DIR/.env" ]]; then
  ENV_FILE="$ROOT_DIR/.env"
elif [[ -f /home/vansh/.secrets/pi-utility-server.env ]]; then
  ENV_FILE=/home/vansh/.secrets/pi-utility-server.env
else
  ENV_FILE="$ROOT_DIR/pi/.env"
fi
[[ -f "$ENV_FILE" ]] || { echo 'Headscale env file missing; set PI_ENV_FILE' >&2; exit 1; }
python3 - "$ENV_FILE" "$ROOT_DIR/pi/config/headscale/config.yaml.template" "$ROOT_DIR/pi/config/headscale/config.yaml" <<'PY'
import ipaddress
import os
from pathlib import Path
import sys
import tempfile

env_file, template_file, output_file = map(Path, sys.argv[1:])
values = {}
for line in env_file.read_text().splitlines():
    if not line or line.lstrip().startswith('#') or '=' not in line:
        continue
    key, value = line.split('=', 1)
    values[key.strip()] = value.strip().strip('"\'')
ip = values.get('HEADSCALE_PUBLIC_IP', '')
try:
    ipaddress.IPv4Address(ip)
except ipaddress.AddressValueError:
    raise SystemExit('HEADSCALE_PUBLIC_IP must be a valid IPv4 address in the private env file')
template = template_file.read_text()
if template.count('<PUBLIC_IP>') != 1:
    raise SystemExit('Expected exactly one <PUBLIC_IP> placeholder in Headscale template')
output_file.parent.mkdir(parents=True, exist_ok=True)
fd, temporary = tempfile.mkstemp(prefix='.headscale-config-', dir=output_file.parent)
try:
    with os.fdopen(fd, 'w') as stream:
        stream.write(template.replace('<PUBLIC_IP>', ip))
    os.chmod(temporary, 0o600)
    os.replace(temporary, output_file)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print('Rendered private Headscale config')
PY
