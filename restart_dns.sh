#!/bin/bash
/usr/bin/inotifywait -mrq -e modify,create,move,delete,moved_to,delete_self  --format "%w%f" /etc/dnsmasq.d |
while read NEW_FILE; do
        now=$(date +%Y%m%d_%H%M%S)
        echo "$now File $NEW_FILE has changed" >> /export/restart_dns.log
        systemctl restart dnsmasq
done
