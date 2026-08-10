#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'; BOLD='\033[1m'

[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }

echo -e "${RED}${BOLD}Pterodactyl Removal${RESET}"
echo
echo "1) Remove Panel files/services"
echo "2) Remove Wings"
echo "3) Remove Panel + Wings"
echo "4) Cancel"
echo
read -r -p "Select [1-4]: " choice

confirm() {
    local text="$1"
    echo -e "${RED}${text}${RESET}"
    read -r -p "Type REMOVE to continue: " x
    [[ "$x" == "REMOVE" ]]
}

remove_panel() {
    confirm "This removes the Panel installation and its database." || {
        echo "Cancelled."; return
    }

    systemctl disable --now pteroq 2>/dev/null || true
    rm -f /etc/systemd/system/pteroq.service
    systemctl daemon-reload

    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    nginx -t && systemctl reload nginx 2>/dev/null || true

    rm -rf /var/www/pterodactyl

    echo
    read -r -p "Also DROP the MariaDB database/user? [y/N]: " db
    if [[ "$db" =~ ^[Yy]$ ]]; then
        mariadb <<'SQL'
DROP DATABASE IF EXISTS panel;
DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
    fi

    echo -e "${GREEN}Panel removal completed.${RESET}"
}

remove_wings() {
    confirm "This removes Wings, its service, and its binary. Docker data is NOT automatically deleted." || {
        echo "Cancelled."; return
    }

    systemctl disable --now wings 2>/dev/null || true
    rm -f /etc/systemd/system/wings.service
    rm -f /usr/local/bin/wings
    systemctl daemon-reload

    read -r -p "Also remove /etc/pterodactyl/config.yml? [y/N]: " cfg
    if [[ "$cfg" =~ ^[Yy]$ ]]; then
        rm -f /etc/pterodactyl/config.yml
    fi

    echo -e "${GREEN}Wings removal completed. Docker and server volumes were left intact.${RESET}"
}

case "$choice" in
    1) remove_panel ;;
    2) remove_wings ;;
    3)
        remove_panel
        echo
        remove_wings
        ;;
    4) echo "Cancelled." ;;
    *) echo "Invalid option." ;;
esac
