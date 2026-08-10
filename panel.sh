#!/bin/bash

# SubhanPlays Pterodactyl Installer - Panel Installation
# Version: 1.0.0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Panel installation variables
PANEL_DIR="/var/www/pterodactyl"
PANEL_REPO="https://github.com/pterodactyl/panel.git"
PANEL_VERSION=""  # Will be set to latest release

install_panel() {
    clear
    header "PTERODACTYL PANEL INSTALLATION"
    echo ""
    
    # Check requirements
    check_root
    detect_os
    
    # Get user input
    echo -e "${CYAN}Panel Configuration:${NC}"
    echo ""
    
    while true; do
        read -p "Enter panel domain (e.g., panel.example.com): " PANEL_DOMAIN
        if validate_domain "$PANEL_DOMAIN"; then
            break
        fi
        error "Invalid domain format"
    done
    
    while true; do
        read -p "Enter admin email: " ADMIN_EMAIL
        if validate_email "$ADMIN_EMAIL"; then
            break
        fi
        error "Invalid email format"
    done
    
    read -p "Enter admin username: " ADMIN_USERNAME
    
    while true; do
        read -s -p "Enter admin password: " ADMIN_PASSWORD
        echo ""
        read -s -p "Confirm admin password: " ADMIN_PASSWORD_CONFIRM
        echo ""
        if [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONFIRM" ]]; then
            break
        fi
        error "Passwords do not match"
    done
    
    read -p "Enter database name [panel]: " DB_NAME
    DB_NAME=${DB_NAME:-panel}
    
    read -p "Enter database user [pterodactyl]: " DB_USER
    DB_USER=${DB_USER:-pterodactyl}
    
    while true; do
        read -s -p "Enter database password: " DB_PASS
        echo ""
        read -s -p "Confirm database password: " DB_PASS_CONFIRM
        echo ""
        if [[ "$DB_PASS" == "$DB_PASS_CONFIRM" ]]; then
            break
        fi
        error "Passwords do not match"
    done
    
    echo ""
    info "Starting panel installation..."
    
    # Install dependencies
    install_dependencies
    
    # Install MariaDB
    install_mariadb
    
    # Create database
    create_database
    
    # Install PHP
    install_php
    
    # Install Composer
    install_composer
    
    # Install Nginx
    install_nginx
    
    # Download and configure panel
    download_panel
    
    # Configure environment
    configure_environment
    
    # Install panel
    run_panel_install
    
    # Configure services
    configure_services
    
    # Configure Nginx
    configure_nginx
    
    # Setup SSL
    setup_ssl
    
    # Create admin user
    create_admin_user
    
    # Final cleanup
    final_cleanup
    
    # Display completion info
    display_completion
}

install_dependencies() {
    info "Installing system dependencies..."
    
    local deps=(
        curl
        wget
        git
        unzip
        tar
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
    )
    
    install_packages "${deps[@]}"
    progress_bar 2 "Dependencies installed"
}

install_mariadb() {
    info "Installing MariaDB..."
    
    if check_command mariadb || check_command mysql; then
        success "MariaDB/MySQL already installed"
        return 0
    fi
    
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash > /dev/null 2>&1
    install_packages mariadb-server mariadb-client
    
    systemctl start mariadb > /dev/null 2>&1
    systemctl enable mariadb > /dev/null 2>&1
    
    # Secure installation
    mysql -u root <<EOF > /dev/null 2>&1
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('');
FLUSH PRIVILEGES;
EOF
    
    success "MariaDB installed and configured"
}

create_database() {
    info "Creating database..."
    
    if create_mysql_db "$DB_NAME" "$DB_USER" "$DB_PASS"; then
        success "Database created"
    else
        error_exit "Database creation failed" \
            "Check MySQL logs: journalctl -u mariadb"
    fi
}

install_php() {
    info "Installing PHP and extensions..."
    
    # Add PHP repository
    if ! check_command php; then
        add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1
        apt-get update > /dev/null 2>&1
    fi
    
    # Detect latest PHP version available
    local php_version="8.3"
    
    local php_packages=(
        "php${php_version}"
        "php${php_version}-cli"
        "php${php_version}-common"
        "php${php_version}-curl"
        "php${php_version}-gd"
        "php${php_version}-mysql"
        "php${php_version}-mbstring"
        "php${php_version}-xml"
        "php${php_version}-zip"
        "php${php_version}-bcmath"
        "php${php_version}-fpm"
        "php${php_version}-redis"
    )
    
    install_packages "${php_packages[@]}"
    
    # Detect installed PHP version
    PHP_VERSION=$(detect_php_version)
    PHP_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"
    
    success "PHP ${PHP_VERSION} installed"
}

install_composer() {
    info "Installing Composer..."
    
    if check_command composer; then
        success "Composer already installed"
        return 0
    fi
    
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" > /dev/null 2>&1
    php composer-setup.php --quiet > /dev/null 2>&1
    rm composer-setup.php
    mv composer.phar /usr/local/bin/composer
    
    success "Composer installed"
}

install_nginx() {
    info "Installing Nginx..."
    
    if check_command nginx; then
        success "Nginx already installed"
        return 0
    fi
    
    install_packages nginx
    systemctl start nginx > /dev/null 2>&1
    systemctl enable nginx > /dev/null 2>&1
    
    success "Nginx installed"
}

download_panel() {
    info "Downloading Pterodactyl Panel..."
    
    if [[ -d "$PANEL_DIR" ]]; then
        warning "Panel directory already exists"
        if ! confirm_action "Do you want to overwrite existing installation?" "YES"; then
            error_exit "Installation cancelled by user" ""
        fi
        backup_file "$PANEL_DIR"
        rm -rf "$PANEL_DIR"
    fi
    
    mkdir -p "$PANEL_DIR"
    
    # Get latest release
    cd /tmp
    curl -s https://api.github.com/repos/pterodactyl/panel/releases/latest | \
        grep "tarball_url" | cut -d'"' -f4 | wget -q -i - -O panel.tar.gz
    
    tar -xzf panel.tar.gz -C "$PANEL_DIR" --strip-components=1
    rm panel.tar.gz
    
    success "Panel downloaded"
}

configure_environment() {
    info "Configuring environment..."
    
    cd "$PANEL_DIR"
    
    cp .env.example .env
    
    # Generate app key
    php artisan key:generate --force > /dev/null 2>&1
    
    # Update .env with database and other settings
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env
    sed -i "s|APP_URL=.*|APP_URL=https://${PANEL_DOMAIN}|" .env
    
    success "Environment configured"
}

run_panel_install() {
    info "Installing panel dependencies..."
    
    cd "$PANEL_DIR"
    
    composer install --no-dev --optimize-autoloader > /dev/null 2>&1 &
    spinner $!
    
    success "Dependencies installed"
    
    info "Setting up database..."
    php artisan migrate --seed --force > /dev/null 2>&1 &
    spinner $!
    
    success "Database migrated"
}

configure_services() {
    info "Configuring services..."
    
    # Set permissions
    chown -R www-data:www-data "$PANEL_DIR"
    chmod -R 755 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
    
    # Configure queue worker
    cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php $PANEL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # Configure scheduler
    cat > /etc/systemd/system/pteroq.service.d/override.conf <<EOF
[Service]
Environment="HOME=/var/www"
EOF

    # Add cron job
    echo "* * * * * php $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1" | \
        crontab -u www-data -
    
    systemctl daemon-reload
    systemctl enable pteroq.service > /dev/null 2>&1
    systemctl start pteroq.service > /dev/null 2>&1
    
    success "Services configured"
}

configure_nginx() {
    info "Configuring Nginx..."
    
    # Backup existing config if exists
    if [[ -f "/etc/nginx/sites-enabled/pterodactyl.conf" ]]; then
        backup_file "/etc/nginx/sites-enabled/pterodactyl.conf"
    fi
    
    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name ${PANEL_DOMAIN};
    root ${PANEL_DIR}/public;

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${PHP_SOCKET};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    
    # Remove default site if exists
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload nginx
    if test_nginx_config; then
        systemctl reload nginx > /dev/null 2>&1
        success "Nginx configured"
    else
        error "Nginx configuration test failed"
        error_exit "Please check /etc/nginx/sites-available/pterodactyl.conf" \
            "Run: nginx -t"
    fi
}

setup_ssl() {
    info "Setting up SSL..."
    
    if ! check_command certbot; then
        install_packages certbot python3-certbot-nginx
    fi
    
    echo -e "${YELLOW}Do you want to configure SSL/HTTPS? (y/n)${NC}"
    read -r ssl_choice
    
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        certbot --nginx -d "$PANEL_DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" > /dev/null 2>&1 &
        spinner $!
        
        if [[ $? -eq 0 ]]; then
            success "SSL configured successfully"
        else
            warning "SSL setup failed. You can run certbot manually later."
        fi
    fi
}

create_admin_user() {
    info "Creating admin user..."
    
    cd "$PANEL_DIR"
    
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" \
        --name-first="Admin" --name-last="User" --password="$ADMIN_PASSWORD" \
        --admin=1 > /dev/null 2>&1 &
    spinner $!
    
    success "Admin user created"
}

final_cleanup() {
    info "Cleaning up..."
    
    # Clear and cache config
    cd "$PANEL_DIR"
    php artisan config:cache > /dev/null 2>&1
    php artisan view:cache > /dev/null 2>&1
    php artisan route:cache > /dev/null 2>&1
    
    # Fix permissions
    chown -R www-data:www-data "$PANEL_DIR"
    find "$PANEL_DIR" -type f -exec chmod 644 {} \;
    find "$PANEL_DIR" -type d -exec chmod 755 {} \;
    chmod -R 755 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
    
    success "Cleanup completed"
}

display_completion() {
    clear
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Pterodactyl Panel Installation Completed!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}Panel URL:${NC} ${WHITE}https://${PANEL_DOMAIN}${NC}"
    echo -e "${CYAN}Admin Email:${NC} ${WHITE}${ADMIN_EMAIL}${NC}"
    echo -e "${CYAN}Admin Username:${NC} ${WHITE}${ADMIN_USERNAME}${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo -e "${WHITE}1. Configure your firewall to allow ports 80, 443, 8080, and 2022${NC}"
    echo -e "${WHITE}2. Create a node in the panel before installing Wings${NC}"
    echo -e "${WHITE}3. Keep your credentials secure${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run installation
install_panel
