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
    echo -e "${CYAN}${BOLD}REMOVE PTERODACTYL PANEL${NC}"
    echo ""
    
    check_root
    
    if ! confirm_action "This will permanently delete the Pterodactyl Panel. Continue?"; then
        return
    fi
    
    # Stop services
    echo -e "${BLUE}[${ICON_INFO}] Stopping panel services...${NC}"
    systemctl stop pteroq.service 2>/dev/null || true
    systemctl disable pteroq.service 2>/dev/null || true
    rm -f /etc/systemd/system/pteroq.service
    systemctl daemon-reload
    
    # Remove cron job
    crontab -u www-data -r 2>/dev/null || true
    
    # Remove Nginx configuration
    echo -e "${BLUE}[${ICON_INFO}] Removing Nginx configuration...${NC}"
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    
    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx
        echo -e "${GREEN}[${ICON_SUCCESS}] Nginx configuration removed${NC}"
    fi
    
    # Remove panel files
    if [[ -d "$PANEL_DIR" ]]; then
        echo -e "${BLUE}[${ICON_INFO}] Removing panel files...${NC}"
        rm -rf "$PANEL_DIR"
        echo -e "${GREEN}[${ICON_SUCCESS}] Panel files removed${NC}"
    fi
    
    # Remove database
    echo ""
    read -p "Do you want to remove the panel database? (y/n): " remove_db
    
    if [[ "$remove_db" =~ ^[Yy]$ ]]; then
        if confirm_action "This will delete the panel database. Continue?"; then
            read -p "Enter database name [panel]: " DB_NAME
            DB_NAME=${DB_NAME:-panel}
            
            mysql -u root -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" 2>/dev/null
            echo -e "${GREEN}[${ICON_SUCCESS}] Database removed${NC}"
        fi
    fi
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Panel removal completed${NC}"
    read -p "Press Enter to continue..."
}

remove_wings() {
    clear
    echo -e "${CYAN}${BOLD}REMOVE PTERODACTYL WINGS${NC}"
    echo ""
    
    check_root
    
    if ! confirm_action "This will permanently delete Pterodactyl Wings. Continue?"; then
        return
    fi
    
    # Stop Wings
    echo -e "${BLUE}[${ICON_INFO}] Stopping Wings...${NC}"
    systemctl stop wings.service 2>/dev/null || true
    systemctl disable wings.service 2>/dev/null || true
    
    # Remove systemd service
    rm -f /etc/systemd/system/wings.service
    systemctl daemon-reload
    
    # Remove Wings binary
    if [[ -f "$WINGS_BIN" ]]; then
        rm -f "$WINGS_BIN"
        echo -e "${GREEN}[${ICON_SUCCESS}] Wings binary removed${NC}"
    fi
    
    # Remove Wings configuration
    if [[ -d "$WINGS_DIR" ]]; then
        rm -rf "$WINGS_DIR"
        echo -e "${GREEN}[${ICON_SUCCESS}] Wings configuration removed${NC}"
    fi
    
    # Remove Wings data directories
    echo -e "${BLUE}[${ICON_INFO}] Removing Wings data...${NC}"
    rm -rf /var/lib/pterodactyl/volumes
    rm -rf /var/lib/pterodactyl/archives
    rm -rf /var/lib/pterodactyl/backups
    rm -rf /tmp/pterodactyl
    
    # Remove Docker network
    if docker network ls 2>/dev/null | grep -q "pterodactyl_nw"; then
        docker network rm pterodactyl_nw > /dev/null 2>&1
        echo -e "${GREEN}[${ICON_SUCCESS}] Docker network removed${NC}"
    fi
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Wings removal completed${NC}"
    read -p "Press Enter to continue..."
}

remove_both() {
    remove_panel
    remove_wings
}

remove_with_docker() {
    if ! confirm_action "This will remove everything INCLUDING Docker. All containers will be lost! Continue?"; then
        return
    fi
    
    remove_panel
    remove_wings
    
    # Remove Docker
    if confirm_action "Remove Docker completely? This affects ALL containers!"; then
        echo -e "${BLUE}[${ICON_INFO}] Removing Docker...${NC}"
        
        systemctl stop docker 2>/dev/null || true
        systemctl disable docker 2>/dev/null || true
        
        apt-get remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1
        apt-get autoremove -y > /dev/null 2>&1
        
        echo -e "${YELLOW}[${ICON_WARNING}] Docker data directories preserved at /var/lib/docker${NC}"
        read -p "Remove all Docker data? (y/n): " remove_docker_data
        if [[ "$remove_docker_data" =~ ^[Yy]$ ]]; then
            rm -rf /var/lib/docker
            rm -rf /var/lib/containerd
            echo -e "${GREEN}[${ICON_SUCCESS}] Docker data removed${NC}"
        fi
        
        echo -e "${GREEN}[${ICON_SUCCESS}] Docker removed${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    display_menu
    
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
        1) remove_panel ;;
        2) remove_wings ;;
        3) remove_both ;;
        4) remove_with_docker ;;
        5) break ;;
        *) 
            echo -e "${RED}[${ICON_ERROR}] Invalid option${NC}"
            sleep 1
            ;;
    esac
done
