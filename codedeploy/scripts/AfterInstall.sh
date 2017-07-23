#!/usr/bin/env bash

echo -e "\n\nDeployed at: $(date)" >> /var/www/public/info

echo -e "\n\n* Caddy Plugins *\n-------------------\n" > /var/www/public/info
/usr/local/bin/caddy -plugins >> /var/www/public/info

chown www-data:www-data /var/www/public/info
chmod 0644 /var/www/public/info
