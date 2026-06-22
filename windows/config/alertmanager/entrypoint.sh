#!/bin/sh
sed "s/\${TELEGRAM_BOT_TOKEN}/$TELEGRAM_BOT_TOKEN/" /etc/alertmanager/alertmanager.yml > /tmp/alertmanager.yml
exec /bin/alertmanager --config.file=/tmp/alertmanager.yml --storage.path=/alertmanager
