#!/bin/bash

# SubhanPlays Pterodactyl Installer - Panel Installation
# Version: 1.0.0

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Icons
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✖"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_ARROW="→"

# Variables
PANEL_DIR="/var/www/pterodactyl"
TMP_DIR="/tmp/subhanplays-pterodactyl"

# Cleanup
cleanup() {
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

# Helper functions
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    wait $pid
    return $?
}

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
    fi
}

# Main installation
install_panel() {
    clear
    echo -e "${CYAN}${BOLD}PTERODACTYL PANEL INSTALLATION${NC}"
    echo ""
    
    check_root
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        echo -e "${RED}[${ICON_ERROR}] Cannot detect OS${NC}"
        exit 1
    fi
    
    if [[ "$OS" != "debian" ]] && [[ "$OS" != "ubuntu" ]]; then
        echo -e "${RED}[${ICON_ERROR}] Unsupported OS: $OS${NC}"
        echo -e "${YELLOW}This installer supports Debian and Ubuntu only${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Detected: $OS${NC}"
    
    # Get user input
    echo ""
    echo -e "${CYAN}Panel Configuration:${NC}"
    echo ""
    
    while true; do
        read -p "Enter panel domain (e.g., panel.example.com): " PANEL_DOMAIN
        if validate_domain "$PANEL_DOMAIN"; then
            break
        fi
        echo -e "${RED}[${ICON_ERROR}] Invalid domain format${NC}"
    done
    
    while true; do
        read -p "Enter admin email: " ADMIN_EMAIL
        if validate_email "$ADMIN_EMAIL"; then
            break
        fi
        echo -e "${RED}[${ICON_ERROR}] Invalid email format${NC}"
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
        echo -e "${RED}[${ICON_ERROR}] Passwords do not match${NC}"
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
        echo -e "${RED}[${ICON_ERROR}] Passwords do not match${NC}"
    done
    
    echo ""
    echo -e "${BLUE}[${ICON_ARROW}] Starting panel installation...${NC}"
    
    # Update system
    echo -e "${BLUE}[${ICON_ARROW}] Updating system packages...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y > /dev/null 2>&1 &
    spinner $!
    
    # Install dependencies
    echo -e "${BLUE}[${ICON_ARROW}] Installing dependencies...${NC}"
    apt-get install -y curl wget git unzip tar software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release > /dev/null 2>&1 &
    spinner $!
    
    # Install MariaDB
    echo -e "${BLUE}[${ICON_ARROW}] Installing MariaDB...${NC}"
    if ! command -v mysql &> /dev/null; then
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash > /dev/null 2>&1
        apt-get install -y mariadb-server mariadb-client > /dev/null 2>&1 &
        spinner $!
        systemctl start mariadb > /dev/null 2>&1
        systemctl enable mariadb > /dev/null 2>&1
    fi
    
    # Create database
    echo -e "${BLUE}[${ICON_ARROW}] Creating database...${NC}"
    mysql -u root <<EOF > /dev/null 2>&1
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
    echo -e "${GREEN}[${ICON_SUCCESS}] Database created${NC}"
    
    # Install PHP
    echo -e "${BLUE}[${ICON_ARROW}] Installing PHP...${NC}"
    if ! command -v php &> /dev/null; then
        add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1
        apt-get update > /dev/null 2>&1
    fi
    
    PHP_VERSION="8.3"
    apt-get install -y php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-common \
        php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip \
        php${PHP_VERSION}-bcmath php${PHP_VERSION}-fpm php${PHP_VERSION}-redis > /dev/null 2>&1 &
    spinner $!
    
    PHP_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"
    echo -e "${GREEN}[${ICON_SUCCESS}] PHP ${PHP_VERSION} installed${NC}"
    
    # Install Composer
    echo -e "${BLUE}[${ICON_ARROW}] Installing Composer...${NC}"
    if ! command -v composer &> /dev/null; then
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" > /dev/null 2>&1
        php composer-setup.php --quiet > /dev/null 2>&1
        rm composer-setup.php
        mv composer.phar /usr/local/bin/composer
    fi
    
    # Install Nginx
    echo -e "${BLUE}[${ICON_ARROW}] Installing Nginx...${NC}"
    if ! command -v nginx &> /dev/null; then
        apt-get install -y nginx > /dev/null 2>&1 &
        spinner $!
        systemctl start nginx > /dev/null 2>&1
        systemctl enable nginx > /dev/null 2>&1
    fi
    
    # Download panel
    echo -e "${BLUE}[${ICON_ARROW}] Downloading Pterodactyl Panel...${NC}"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"
    
    if [[ -d "$PANEL_DIR" ]]; then
        echo -e "${YELLOW}[${ICON_WARNING}] Panel directory already exists${NC}"
        read -p "Overwrite? (y/n): " overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            backup_file "$PANEL_DIR"
            rm -rf "$PANEL_DIR"
        else
            exit 1
        fi
    fi
    
    mkdir -p "$PANEL_DIR"
    cd "$TMP_DIR"
    
    # Download latest release
    curl -s https://api.github.com/repos/pterodactyl/panel/releases/latest | \
        grep "tarball_url" | cut -d'"' -f4 | wget -q -i - -O panel.tar.gz
    
    tar -xzf panel.tar.gz -C "$PANEL_DIR" --strip-components=1
    rm panel.tar.gz
    echo -e "${GREEN}[${ICON_SUCCESS}] Panel downloaded${NC}"
    
    # Configure environment
    echo -e "${BLUE}[${ICON_ARROW}] Configuring environment...${NC}"
    cd "$PANEL_DIR"
    cp .env.example .env
    
    php artisan key:generate --force > /dev/null 2>&1
    
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env
    sed -i "s|APP_URL=.*|APP_URL=https://${PANEL_DOMAIN}|" .env
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Environment configured${NC}"
    
    # Install dependencies
    echo -e "${BLUE}[${ICON_ARROW}] Installing panel dependencies...${NC}"
    composer install --no-dev --optimize-autoloader > /dev/null 2>&1 &
    spinner $!
    
    # Setup database
    echo -e "${BLUE}[${ICON_ARROW}] Setting up database...${NC}"
    php artisan migrate --seed --force > /dev/null 2>&1 &
    spinner $!
    
    # Set permissions
    echo -e "${BLUE}[${ICON_ARROW}] Setting permissions...${NC}"
    chown -R www-data:www-data "$PANEL_DIR"
    chmod -R 755 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
    
    # Configure queue service
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
    
    systemctl daemon-reload
    systemctl enable pteroq.service > /dev/null 2>&1
    systemctl start pteroq.service > /dev/null 2>&1
    
    # Add cron job
    echo "* * * * * php $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1" | \
        crontab -u www-data -
    
    # Configure Nginx
    echo -e "${BLUE}[${ICON_ARROW}] Configuring Nginx...${NC}"
    
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

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
}
EOF
    
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx > /dev/null 2>&1
        echo -e "${GREEN}[${ICON_SUCCESS}] Nginx configured${NC}"
    else
        echo -e "${RED}[${ICON_ERROR}] Nginx configuration test failed${NC}"
        exit 1
    fi
    
    # Setup SSL
    echo -e "${BLUE}[${ICON_ARROW}] Setting up SSL...${NC}"
    read -p "Configure SSL/HTTPS? (y/n): " setup_ssl
    if [[ "$setup_ssl" =~ ^[Yy]$ ]]; then
        if ! command -v certbot &> /dev/null; then
            apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1
        fi
        certbot --nginx -d "$PANEL_DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" > /dev/null 2>&1 &
        spinner $!
    fi
    
    # Create admin user
    echo -e "${BLUE}[${ICON_ARROW}] Creating admin user...${NC}"
    cd "$PANEL_DIR"
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" \
        --name-first="Admin" --name-last="User" --password="$ADMIN_PASSWORD" \
        --admin=1 > /dev/null 2>&1 &
    spinner $!
    
    # Clear cache
    php artisan config:cache > /dev/null 2>&1
    php artisan view:cache > /dev/null 2>&1
    php artisan route:cache > /dev/null 2>&1
    
    # Display completion
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
    echo -e "${WHITE}1. Configure firewall to allow ports 80, 443, 8080, 2022${NC}"
    echo -e "${WHITE}2. Create a node in the panel before installing Wings${NC}"
    echo -e "${WHITE}3. Keep your credentials secure${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run installation
install_panel
