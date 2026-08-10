#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'; BOLD='\033[1m'

[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }

echo -e "${CYAN}${BOLD}Pterodactyl Wings Installer / Updater${RESET}"
echo

if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker is missing. Installing Docker CE...${RESET}"
    apt-get update
    apt-get install -y ca-certificates curl
    curl -fsSL https://get.docker.com/ | CHANNEL=stable bash
fi

systemctl enable --now docker 2>/dev/null || true

mkdir -p /etc/pterodactyl

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64) WINGS_ARCH="amd64" ;;
    aarch64|arm64) WINGS_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

TMP="/tmp/wings.$$"
curl -fL -o "$TMP" "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"
install -m 0755 "$TMP" /usr/local/bin/wings
rm -f "$TMP"

cat >/etc/systemd/system/wings.service <<'SERVICE'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable wings

echo
if [[ ! -f /etc/pterodactyl/config.yml ]]; then
    echo -e "${YELLOW}Wings binary is installed, but config.yml does not exist yet.${RESET}"
    echo
    echo "Create a Node in your Pterodactyl Panel, open its Configuration tab,"
    echo "and paste the generated configuration into:"
    echo
    echo "  /etc/pterodactyl/config.yml"
    echo
    echo "Then run:"
    echo "  systemctl enable --now wings"
else
    systemctl restart wings
fi

echo
echo -e "${GREEN}Wings version:${RESET}"
wings version 2>/dev/null || /usr/local/bin/wings --version 2>/dev/null || true

echo
echo -e "${GREEN}Wings installation/update completed.${RESET}"
