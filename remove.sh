#!/bin/bash

# SubhanPlays Pterodactyl Installer - Removal Tool
# Version: 1.0.0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PANEL_DIR="/var/www/pterodactyl"
WINGS_DIR="/etc/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"

display_menu() {
    clear
    header "PTERODACTYL REMOVAL"
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
    header "REMOVE PTERODACTYL PANEL"
    echo ""
    
    check_root
    
    if ! confirm_action "This will permanently delete the Pterodactyl Panel. Continue?" "YES"; then
        return
    fi
    
    # Stop services
    info "Stopping panel services..."
    systemctl stop pteroq.service > /dev/null 2>&1 || true
    systemctl disable pteroq.service > /dev/null 2>&1 || true
    rm -f /etc/systemd/system/pteroq.service
    
    # Remove cron job
    crontab -u www-data -r > /dev/null 2>&1 || true
    
    # Remove Nginx configuration
    info "Removing Nginx configuration..."
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    
    if test_nginx_config; then
        systemctl reload nginx
        success "Nginx configuration removed"
    fi
    
    # Remove panel files
    if [[ -d "$PANEL_DIR" ]]; then
        info "Removing panel files..."
        rm -rf "$PANEL_DIR"
        success "Panel files removed"
    fi
    
    # Remove database
    echo ""
    echo -n "Do you want to remove the panel database? (y/n): "
    read -r remove_db
    
    if [[ "$remove_db" =~ ^[Yy]$ ]]; then
        if confirm_action "This will delete the panel database. Continue?" "YES"; then
            read -p "Enter database name [panel]: " DB_NAME
            DB_NAME=${DB_NAME:-panel}
            
            mysql -u root -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" > /dev/null 2>&1
            success "Database removed"
        fi
    fi
    
    success "Panel removal completed"
    pause_screen
}

remove_wings() {
    clear
    header "REMOVE PTERODACTYL WINGS"
    echo ""
    
    check_root
    
    if ! confirm_action "This will permanently delete Pterodactyl Wings. Continue?" "YES"; then
        return
    fi
    
    # Stop Wings
    info "Stopping Wings..."
    systemctl stop wings.service > /dev/null 2>&1 || true
    systemctl disable wings.service > /dev/null 2>&1 || true
    
    # Remove systemd service
    rm -f /etc/systemd/system/wings.service
    systemctl daemon-reload
    
    # Remove Wings binary
    if [[ -f "$WINGS_BIN" ]]; then
        rm -f "$WINGS_BIN"
        success "Wings binary removed"
    fi
    
    # Remove Wings configuration
    if [[ -d "$WINGS_DIR" ]]; then
        rm -rf "$WINGS_DIR"
        success "Wings configuration removed"
    fi
    
    # Remove Wings data directories
    info "Removing Wings data..."
    rm -rf /var/lib/pterodactyl/volumes
    rm -rf /var/lib/pterodactyl/archives
    rm -rf /var/lib/pterodactyl/backups
    rm -rf /tmp/pterodactyl
    
    # Remove Docker network
    if docker network ls | grep -q "pterodactyl_nw"; then
        docker network rm pterodactyl_nw > /dev/null 2>&1
        success "Docker network removed"
    fi
    
    success "Wings removal completed"
    pause_screen
}

remove_both() {
    remove_panel
    remove_wings
}

remove_with_docker() {
    if ! confirm_action "This will remove everything INCLUDING Docker. All containers will be lost! Continue?" "YES"; then
        return
    fi
    
    remove_panel
    remove_wings
    
    # Remove Docker
    if confirm_action "Remove Docker completely? This affects ALL containers!" "YES"; then
        info "Removing Docker..."
        
        systemctl stop docker > /dev/null 2>&1 || true
        systemctl disable docker > /dev/null 2>&1 || true
        
        apt-get remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1
        apt-get autoremove -y > /dev/null 2>&1
        
        # Remove Docker data
        warning "Docker data directories preserved at /var/lib/docker"
        echo -n "Remove all Docker data? (y/n): "
        read -r remove_docker_data
        if [[ "$remove_docker_data" =~ ^[Yy]$ ]]; then
            rm -rf /var/lib/docker
            rm -rf /var/lib/containerd
            success "Docker data removed"
        fi
        
        success "Docker removed"
    fi
    
    pause_screen
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
            error "Invalid option"
            sleep 1
            ;;
    esac
done
