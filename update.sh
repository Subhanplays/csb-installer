#!/bin/bash

# SubhanPlays Pterodactyl Installer - Update Manager
# Version: 1.0.0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PANEL_DIR="/var/www/pterodactyl"
WINGS_DIR="/etc/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"

display_menu() {
    clear
    header "UPDATE MANAGER"
    echo ""
    echo -e "${WHITE}[1]${NC} Update Pterodactyl Panel"
    echo -e "${WHITE}[2]${NC} Update Wings"
    echo -e "${WHITE}[3]${NC} Update Both"
    echo -e "${WHITE}[4]${NC} Back"
    echo ""
}

update_panel() {
    clear
    header "UPDATE PTERODACTYL PANEL"
    echo ""
    
    check_root
    
    if [[ ! -d "$PANEL_DIR" ]]; then
        error "Panel not found at $PANEL_DIR"
        return 1
    fi
    
    # Backup important files
    info "Creating backup..."
    backup_file "$PANEL_DIR/.env"
    
    local backup_dir="/tmp/pterodactyl_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$PANEL_DIR" "$backup_dir/"
    success "Backup created: $backup_dir"
    
    # Enter maintenance mode
    info "Entering maintenance mode..."
    cd "$PANEL_DIR"
    php artisan down > /dev/null 2>&1
    
    # Update panel
    info "Downloading latest panel..."
    
    cd /tmp
    curl -s https://api.github.com/repos/pterodactyl/panel/releases/latest | \
        grep "tarball_url" | cut -d'"' -f4 | wget -q -i - -O panel-latest.tar.gz
    
    tar -xzf panel-latest.tar.gz -C /tmp
    rm panel-latest.tar.gz
    
    # Find extracted directory
    local extracted_dir=$(ls -d /tmp/pterodactyl-panel-*)
    
    # Copy new files
    cp -rf "$extracted_dir"/* "$PANEL_DIR/"
    rm -rf "$extracted_dir"
    
    # Restore .env
    cp "$backup_dir/pterodactyl/.env" "$PANEL_DIR/.env"
    
    # Update dependencies
    info "Updating dependencies..."
    cd "$PANEL_DIR"
    composer install --no-dev --optimize-autoloader > /dev/null 2>&1 &
    spinner $!
    
    # Run migrations
    info "Running database migrations..."
    php artisan migrate --force > /dev/null 2>&1 &
    spinner $!
    
    # Clear cache
    php artisan config:cache > /dev/null 2>&1
    php artisan view:cache > /dev/null 2>&1
    php artisan route:cache > /dev/null 2>&1
    
    # Fix permissions
    chown -R www-data:www-data "$PANEL_DIR"
    chmod -R 755 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
    
    # Exit maintenance mode
    php artisan up > /dev/null 2>&1
    
    # Restart services
    systemctl restart pteroq.service
    
    success "Panel updated successfully"
    
    # Verify panel is responding
    info "Verifying panel..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302"; then
        success "Panel is responding"
    else
        warning "Panel might need additional configuration"
    fi
    
    pause_screen
}

update_wings() {
    clear
    header "UPDATE PTERODACTYL WINGS"
    echo ""
    
    check_root
    
    if [[ ! -f "$WINGS_BIN" ]]; then
        error "Wings not found at $WINGS_BIN"
        return 1
    fi
    
    # Stop Wings
    info "Stopping Wings..."
    systemctl stop wings.service > /dev/null 2>&1
    
    # Backup current binary
    backup_file "$WINGS_BIN"
    
    # Backup config
    if [[ -f "$WINGS_DIR/config.yml" ]]; then
        backup_file "$WINGS_DIR/config.yml"
    fi
    
    # Download latest Wings
    info "Downloading latest Wings..."
    
    local latest_wings=$(curl -s https://api.github.com/repos/pterodactyl/wings/releases/latest | \
        grep "browser_download_url.*linux_amd64" | cut -d'"' -f4)
    
    download_file "$latest_wings" "$WINGS_BIN"
    chmod u+x "$WINGS_BIN"
    
    # Start Wings
    info "Starting Wings..."
    systemctl start wings.service > /dev/null 2>&1 &
    spinner $!
    
    sleep 3
    
    if systemctl is-active --quiet wings; then
        success "Wings updated and running"
    else
        error "Wings failed to start"
        error_exit "Check logs: journalctl -u wings" \
            "Restore backup from: $WINGS_BIN.backup.*"
    fi
    
    pause_screen
}

update_both() {
    update_panel
    update_wings
}

# Main loop
while true; do
    display_menu
    
    read -p "Enter your choice [1-4]: " choice
    
    case $choice in
        1) update_panel ;;
        2) update_wings ;;
        3) update_both ;;
        4) break ;;
        *) 
            error "Invalid option"
            sleep 1
            ;;
    esac
done
