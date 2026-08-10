#!/bin/bash

# SubhanPlays Pterodactyl Installer - Configuration Manager
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[${ICON_ERROR}] This script must be run as root${NC}"
        exit 1
    fi
}

validate_domain() {
    if [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

validate_email() {
    if [[ $1 =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        echo -e "${GREEN}[${ICON_SUCCESS}] Backed up: $file -> $backup${NC}"
        echo "$backup"
    fi
}

display_menu() {
    clear
    echo -e "${CYAN}${BOLD}CONFIGURATION MANAGEMENT${NC}"
    echo ""
    echo -e "${WHITE}[1]${NC} Change Panel Domain"
    echo -e "${WHITE}[2]${NC} Change Admin Email"
    echo -e "${WHITE}[3]${NC} Change Admin Password"
    echo -e "${WHITE}[4]${NC} Change Admin Username"
    echo -e "${WHITE}[5]${NC} Change Nginx Configuration"
    echo -e "${WHITE}[6]${NC} Configure SSL"
    echo -e "${WHITE}[7]${NC} Back"
    echo ""
}

change_domain() {
    clear
    echo -e "${CYAN}${BOLD}CHANGE PANEL DOMAIN${NC}"
    echo ""
    
    check_root
    
    while true; do
        read -p "Enter new domain: " NEW_DOMAIN
        if validate_domain "$NEW_DOMAIN"; then
            break
        fi
        echo -e "${RED}[${ICON_ERROR}] Invalid domain format${NC}"
    done
    
    # Update .env file
    if [[ -f "$PANEL_DIR/.env" ]]; then
        backup_file "$PANEL_DIR/.env"
        sed -i "s|APP_URL=.*|APP_URL=https://${NEW_DOMAIN}|" "$PANEL_DIR/.env"
        echo -e "${GREEN}[${ICON_SUCCESS}] Panel configuration updated${NC}"
    fi
    
    # Update Nginx configuration
    if [[ -f "/etc/nginx/sites-available/pterodactyl.conf" ]]; then
        backup_file "/etc/nginx/sites-available/pterodactyl.conf"
        sed -i "s|server_name .*|server_name ${NEW_DOMAIN};|" /etc/nginx/sites-available/pterodactyl.conf
        
        if nginx -t > /dev/null 2>&1; then
            systemctl reload nginx
            echo -e "${GREEN}[${ICON_SUCCESS}] Nginx configuration updated${NC}"
        else
            echo -e "${RED}[${ICON_ERROR}] Nginx configuration test failed${NC}"
            echo -e "${YELLOW}[${ICON_WARNING}] Restoring from backup...${NC}"
            cp /etc/nginx/sites-available/pterodactyl.conf.backup.* /etc/nginx/sites-available/pterodactyl.conf 2>/dev/null
            systemctl reload nginx
        fi
    fi
    
    # Configure SSL for new domain
    read -p "Configure SSL for new domain? (y/n): " setup_ssl
    if [[ "$setup_ssl" =~ ^[Yy]$ ]]; then
        if command -v certbot &> /dev/null; then
            certbot --nginx -d "$NEW_DOMAIN"
        else
            apt-get update > /dev/null 2>&1
            apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1
            certbot --nginx -d "$NEW_DOMAIN"
        fi
    fi
    
    # Clear cache
    cd "$PANEL_DIR"
    php artisan config:cache > /dev/null 2>&1
    php artisan view:cache > /dev/null 2>&1
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Domain changed successfully${NC}"
    read -p "Press Enter to continue..."
}

change_admin_email() {
    clear
    echo -e "${CYAN}${BOLD}CHANGE ADMIN EMAIL${NC}"
    echo ""
    
    check_root
    
    read -p "Enter admin username: " ADMIN_USERNAME
    
    while true; do
        read -p "Enter new email: " NEW_EMAIL
        if validate_email "$NEW_EMAIL"; then
            break
        fi
        echo -e "${RED}[${ICON_ERROR}] Invalid email format${NC}"
    done
    
    cd "$PANEL_DIR"
    php artisan p:user:make --email="$NEW_EMAIL" --username="$ADMIN_USERNAME" \
        --name-first="Admin" --name-last="User" --password="temp123" \
        --admin=1 > /dev/null 2>&1
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Email updated. Please update password using option 3${NC}"
    read -p "Press Enter to continue..."
}

change_admin_password() {
    clear
    echo -e "${CYAN}${BOLD}CHANGE ADMIN PASSWORD${NC}"
    echo ""
    
    check_root
    
    read -p "Enter admin username: " ADMIN_USERNAME
    
    while true; do
        read -s -p "Enter new password: " NEW_PASSWORD
        echo ""
        read -s -p "Confirm new password: " NEW_PASSWORD_CONFIRM
        echo ""
        if [[ "$NEW_PASSWORD" == "$NEW_PASSWORD_CONFIRM" ]]; then
            break
        fi
        echo -e "${RED}[${ICON_ERROR}] Passwords do not match${NC}"
    done
    
    cd "$PANEL_DIR"
    php artisan p:user:make --username="$ADMIN_USERNAME" \
        --email="temp@temp.com" --name-first="Admin" --name-last="User" \
        --password="$NEW_PASSWORD" --admin=1 > /dev/null 2>&1
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Password changed successfully${NC}"
    read -p "Press Enter to continue..."
}

change_admin_username() {
    clear
    echo -e "${CYAN}${BOLD}CHANGE ADMIN USERNAME${NC}"
    echo ""
    
    check_root
    
    read -p "Enter current username: " CURRENT_USERNAME
    read -p "Enter new username: " NEW_USERNAME
    
    cd "$PANEL_DIR"
    php artisan p:user:make --username="$NEW_USERNAME" \
        --email="temp@temp.com" --name-first="Admin" --name-last="User" \
        --password="temp123" --admin=1 > /dev/null 2>&1
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Username changed. Please update email and password${NC}"
    read -p "Press Enter to continue..."
}

change_nginx_config() {
    clear
    echo -e "${CYAN}${BOLD}CHANGE NGINX CONFIGURATION${NC}"
    echo ""
    
    check_root
    
    if [[ ! -f "/etc/nginx/sites-available/pterodactyl.conf" ]]; then
        echo -e "${RED}[${ICON_ERROR}] Nginx configuration not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    backup_file "/etc/nginx/sites-available/pterodactyl.conf"
    
    echo -e "${CYAN}Opening Nginx configuration in editor...${NC}"
    read -p "Press Enter to edit (nano will open)..."
    nano /etc/nginx/sites-available/pterodactyl.conf
    
    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx
        echo -e "${GREEN}[${ICON_SUCCESS}] Nginx configuration updated and reloaded${NC}"
    else
        echo -e "${RED}[${ICON_ERROR}] Invalid Nginx configuration. Restoring backup...${NC}"
        cp /etc/nginx/sites-available/pterodactyl.conf.backup.* /etc/nginx/sites-available/pterodactyl.conf 2>/dev/null
        systemctl reload nginx
    fi
    
    read -p "Press Enter to continue..."
}

configure_ssl() {
    clear
    echo -e "${CYAN}${BOLD}CONFIGURE SSL${NC}"
    echo ""
    
    check_root
    
    if ! command -v certbot &> /dev/null; then
        apt-get update > /dev/null 2>&1
        apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1
    fi
    
    read -p "Enter domain for SSL: " DOMAIN
    
    if validate_domain "$DOMAIN"; then
        certbot --nginx -d "$DOMAIN"
        echo -e "${GREEN}[${ICON_SUCCESS}] SSL configured${NC}"
    else
        echo -e "${RED}[${ICON_ERROR}] Invalid domain${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    display_menu
    
    read -p "Enter your choice [1-7]: " choice
    
    case $choice in
        1) change_domain ;;
        2) change_admin_email ;;
        3) change_admin_password ;;
        4) change_admin_username ;;
        5) change_nginx_config ;;
        6) configure_ssl ;;
        7) break ;;
        *) 
            echo -e "${RED}[${ICON_ERROR}] Invalid option${NC}"
            sleep 1
            ;;
    esac
done
