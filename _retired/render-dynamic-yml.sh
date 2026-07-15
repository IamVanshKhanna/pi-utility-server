#!/usr/bin/env bash
# render-dynamic-yml.sh - Render dynamic.yml from template with env substitution
# Uses python3 for safe substitution (avoids shell $ expansion issues with htpasswd hashes)
# Reads: pi/config/traefik/dynamic.yml.template + .env
# Writes: pi/config/traefik/dynamic.yml

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
REPO_DIR="$(cd "$REPO_DIR" && pwd)"
TEMPLATE="$REPO_DIR/pi/config/traefik/dynamic.yml.template"
OUTPUT="$REPO_DIR/pi/config/traefik/dynamic.yml"
ENV_FILE="$REPO_DIR/.env"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: Template not found at $TEMPLATE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found at $ENV_FILE"
  exit 1
fi

export RENDER_TEMPLATE="$TEMPLATE"
export RENDER_OUTPUT="$OUTPUT"
export RENDER_ENV="$ENV_FILE"

python3 << 'PYEOF'
import os

template_path = os.environ["RENDER_TEMPLATE"]
output_path = os.environ["RENDER_OUTPUT"]
env_path = os.environ["RENDER_ENV"]

with open(template_path) as f:
    content = f.read()

env = {}
with open(env_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, val = line.split("=", 1)
            val = val.strip('"').strip("'")
            env[key.strip()] = val

defaults = {
    "WINDOWS_IP": "100.64.0.2",
    "TRAEFIK_BASICAUTH": "REPLACE_WITH_htpasswd_hash",
}

for var, default in defaults.items():
    value = env.get(var, default)
    content = content.replace("${" + var + ":-" + default + "}", value)
    content = content.replace("${" + var + "}", value)

if "TRAEFIK_BASICAUTH" in env:
    basicauth_val = env["TRAEFIK_BASICAUTH"]
    content = content.replace('"REPLACE_WITH_htpasswd_hash"', '"' + basicauth_val + '"')
    content = content.replace("REPLACE_WITH_htpasswd_hash", basicauth_val)

content = content.replace("\r\n", "\n")

with open(output_path, "w") as f:
    f.write(content)

print("Rendered " + output_path)
windows_ip = env.get("WINDOWS_IP", "100.64.0.2")
basicauth_set = "TRAEFIK_BASICAUTH" in env
print("WINDOWS_IP: " + windows_ip)
print("TRAEFIK_BASICAUTH: " + ("SET" if basicauth_set else "NOT SET (using placeholder)"))
PYEOF

sed -i 's/\r$//' "$OUTPUT" 2>/dev/null || true
