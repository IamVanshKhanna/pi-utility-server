#!/bin/sh
set -e
mkdir -p /etc/samba/private /var/lib/samba/private
exec smbd -F --no-process-group
