#!/bin/bash

# SubhanPlays Pterodactyl Installer - Removal Tool
# Version: 1.0.0

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✖"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"

PANEL_DIR="/var/www/pterodactyl"
WINGS_DIR="/etc/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[${ICON_ERROR}] This script must be run as root${NC}"
        exit 1
    fi
}

confirm_action() {
    local message=$1
    echo -e "${RED}${BOLD}WARNING!${NC}"
    echo -e "${YELLOW}$message${NC}"
    echo ""
    echo -e "${WHITE}Type ${BOLD}YES${NC}${WHITE} to continue:${NC}"
    read -r response
    
    if [[ "$response" != "YES" ]]; then
        echo -e "${RED}[${ICON_ERROR}] Operation cancelled${NC}"
        return 1
    fi
    return 0
}

display_menu() {
    clear
    echo -e "${CYAN}${BOLD}PTERODACTYL REMOVAL${NC}"
    echo ""
    echo -e "${RED}${BOLD}WARNING: These operations are destructive!${NC}"
    echo ""
    echo -e "${WHITE}[1]${NC} Remove Panel"
    echo -e "${WHITE}[2]${NC} Remove Wings"
    echo -e "${WHITE}[3]${NC} Remove Panel + Wings"
    echo -e "${WHITE}[4]${NC} Remove Panel + Wings + Docker"
    echo -e "${WHITE}[5]${NC} Back"
    echo ""
}

remove_panel() {
    clear
    echo -e "${CYAN}${B
