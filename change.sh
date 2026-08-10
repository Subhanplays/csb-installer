#!/bin/bash

# SubhanPlays Pterodactyl Installer - Configuration Manager
# Version: 1.0.0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PANEL_DIR="/var/www/pterodactyl"

display_menu() {
    clear
    header "CONFIGURATION MANAGEMENT"
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
    header "CHANGE PANEL DOMAIN"
    echo ""
    
    check_root
    
    while true; do
        read -p "Enter new domain: " NEW_DOMAIN
        if validate_domain "$NEW_DOMAIN"; then
            break
        fi
        error "Invalid domain format"
    done
    
    # Update .env file
    if [[ -f "$PANEL_DIR/.env" ]]; then
        backup_file "$PANEL_DIR/.env"
        sed -i "s|APP_URL=.*|APP_URL=https://${NEW_DOMAIN}|" "$PANEL_DIR/.env"
        success "Panel configuration updated"
    fi
    
    # Update Nginx configuration
    if [[ -f "/etc/nginx/sites-available/pterodactyl.conf" ]]; then
        backup_file "/etc/nginx/sites-available/pterodactyl.conf"
        sed -i "s|server_name .*|server_name ${NEW_DOMAIN};|" /etc/nginx/sites-available/pterodactyl.conf
        
        if test_nginx_config; then
            systemctl reload nginx
            success "Nginx configuration updated"
        else
            error "Nginx configuration test failed"
            error_exit "Restore from backup and fix manually" \
                "Backup: /etc/nginx/sites-available/pterodactyl.conf.backup.*"
        fi
    fi
    
    # Configure SSL for new domain
    echo -n "Configure SSL for new domain? (y/n): "
    read -r setup_ssl
    
    if [[ "$setup_ssl" =~ ^[Yy]$ ]]; then
        if check_command certbot; then
            certbot --nginx -d "$NEW_DOMAIN"
        else
            install_packages certbot python3-certbot-nginx
            certbot --nginx -d "$NEW_DOMAIN"
        fi
    fi
    
    # Clear cache
    cd "$PANEL_DIR"
    php artisan config:cache > /dev/null 2>&1
    php artisan view:cache > /dev/null 2>&1
    
    success "Domain changed successfully"
    pause_screen
}

change_admin_email() {
    clear
    header "CHANGE ADMIN EMAIL"
    echo ""
    
    check_root
    
    read -p "Enter current admin username: " CURRENT_USERNAME
    
    while true; do
        read -p "Enter new email: " NEW_EMAIL
        if validate_email "$NEW_EMAIL"; then
            break
        fi
        error "Invalid email format"
    done
    
    cd "$PANEL_DIR"
    php artisan p:user:disable "$CURRENT_USERNAME" > /dev/null 2>&1
    php artisan p:user:make --email="$NEW_EMAIL" --username="$CURRENT_USERNAME" \
        --name-first="Admin" --name-last="User" --password="temp123" \
        --admin=1 > /dev/null 2>&1
    
    success "Email updated. Please update password using option 3"
    pause_screen
}

change_admin_password() {
    clear
    header "CHANGE ADMIN PASSWORD"
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
        error "Passwords do not match"
    done
    
    cd "$PANEL_DIR"
    php artisan p:user:make --username="$ADMIN_USERNAME" \
        --email="temp@temp.com" --name-first="Admin" --name-last="User" \
        --password="$NEW_PASSWORD" --admin=1 > /dev/null 2>&1
    
    success "Password changed successfully"
    pause_screen
}

change_admin_username() {
    clear
    header "CHANGE ADMIN USERNAME"
    echo ""
    
    check_root
    
    read -p "Enter current username: " CURRENT_USERNAME
    read -p "Enter new username: " NEW_USERNAME
    
    cd "$PANEL_DIR"
    php artisan p:user:disable "$CURRENT_USERNAME" > /dev/null 2>&1
    php artisan p:user:make --username="$NEW_USERNAME" \
        --email="temp@temp.com" --name-first="Admin" --name-last="User" \
        --password="temp123" --admin=1 > /dev/null 2>&1
    
    success "Username changed. Please update email and password"
    pause_screen
}

change_nginx_config() {
    clear
    header "CHANGE NGINX CONFIGURATION"
    echo ""
    
    check_root
    
    if [[ ! -f "/etc/nginx/sites-available/pterodactyl.conf" ]]; then
        error "Nginx configuration not found"
        pause_screen
        return
    fi
    
    # Create backup
    backup_file "/etc/nginx/sites-available/pterodactyl.conf"
    
    echo -e "${CYAN}Opening Nginx configuration in editor...${NC}"
    echo -e "${WHITE}Current configuration:${NC}"
    echo ""
    cat /etc/nginx/sites-available/pterodactyl.conf
    echo ""
    
    read -p "Press Enter to edit (nano will open)..." 
    nano /etc/nginx/sites-available/pterodactyl.conf
    
    if test_nginx_config; then
        systemctl reload nginx
        success "Nginx configuration updated and reloaded"
    else
        error "Invalid Nginx configuration. Restoring backup..."
        cp "/etc/nginx/sites-available/pterodactyl.conf.backup."* \
           /etc/nginx/sites-available/pterodactyl.conf
        systemctl reload nginx
        error "Backup restored"
    fi
    
    pause_screen
}

configure_ssl() {
    clear
    header "CONFIGURE SSL"
    echo ""
    
    check_root
    
    if ! check_command certbot; then
        install_packages certbot python3-certbot-nginx
    fi
    
    read -p "Enter domain for SSL: " DOMAIN
    
    if validate_domain "$DOMAIN"; then
        certbot --nginx -d "$DOMAIN"
        success "SSL configured"
    else
        error "Invalid domain"
    fi
    
    pause_screen
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
            error "Invalid option"
            sleep 1
            ;;
    esac
done
