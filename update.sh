#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'; BOLD='\033[1m'

[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }

echo -e "${CYAN}${BOLD}Updating Pterodactyl Panel + Wings${RESET}"
echo

if [[ -d /var/www/pterodactyl ]]; then
    cd /var/www/pterodactyl

    echo -e "${YELLOW}Backing up .env...${RESET}"
    cp -a .env "/root/pterodactyl-env-backup-$(date +%Y%m%d-%H%M%S)"

    echo -e "${YELLOW}Downloading latest Panel release...${RESET}"
    TMP="/tmp/panel-update.$$"
    mkdir -p "$TMP"
    curl -fL -o "$TMP/panel.tar.gz" https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz

    # Keep .env while replacing application files.
    tar -xzf "$TMP/panel.tar.gz" -C /var/www/pterodactyl
    rm -rf "$TMP"

    composer install --no-dev --optimize-autoloader --no-interaction
    php artisan migrate --seed --force
    php artisan view:clear
    php artisan config:clear
    php artisan cache:clear

    chown -R www-data:www-data /var/www/pterodactyl
    chmod -R 755 storage bootstrap/cache

    systemctl restart pteroq 2>/dev/null || true
    systemctl restart php8.3-fpm 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true

    echo -e "${GREEN}Panel updated.${RESET}"
else
    echo -e "${YELLOW}Panel directory not found; skipping Panel update.${RESET}"
fi

echo
echo -e "${YELLOW}Updating Wings...${RESET}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/wings.sh"

echo
echo -e "${GREEN}${BOLD}Update process completed.${RESET}"
