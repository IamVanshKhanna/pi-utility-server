#!/bin/sh
sed -e "s|\${TELEGRAM_BOT_TOKEN}|$TELEGRAM_BOT_TOKEN|g" -e "s|\${TELEGRAM_CHAT_ID}|$TELEGRAM_CHAT_ID|g" /etc/alertmanager/alertmanager.yml > /tmp/alertmanager.yml
exec /bin/alertmanager --config.file=/tmp/alertmanager.yml --storage.path=/alertmanager
