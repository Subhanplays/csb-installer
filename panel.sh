#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; RESET='\033[0m'; BOLD='\033[1m'

[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }

if [[ ! -r /etc/os-release ]]; then
    echo "Cannot detect operating system."; exit 1
fi
. /etc/os-release

if [[ "${ID:-}" != "debian" ]]; then
    echo -e "${YELLOW}This starter installer targets Debian.${RESET}"
    echo "Detected: ${PRETTY_NAME:-unknown}"
    read -r -p "Continue anyway? [y/N]: " ok
    [[ "$ok" =~ ^[Yy]$ ]] || exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl is-system-running >/dev/null 2>&1 || true
fi

echo -e "${CYAN}${BOLD}Pterodactyl Panel Installer${RESET}"
echo

read -r -p "Panel domain (example: panel.example.com): " DOMAIN
DOMAIN="${DOMAIN,,}"
[[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]] || { echo "Invalid domain."; exit 1; }

read -r -p "Enable HTTPS with Certbot after installation? [Y/n]: " SSL
SSL="${SSL:-Y}"

echo
echo -e "${YELLOW}Installing Panel dependencies...${RESET}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg unzip tar git nginx mariadb-server redis-server \
    cron openssl software-properties-common apt-transport-https

# Pterodactyl currently documents PHP 8.2/8.3. Try Debian packages first.
apt-get install -y php8.3 php8.3-cli php8.3-common php8.3-gd php8.3-mysql \
    php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip \
    php8.3-opcache php8.3-readline 2>/dev/null || {
    echo -e "${RED}PHP 8.3 packages were not available from this system's repositories.${RESET}"
    echo "Install PHP 8.3 from a trusted repository before continuing."
    exit 1
}

if ! command -v composer >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing Composer...${RESET}"
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm -f /tmp/composer-setup.php
fi

systemctl enable --now mariadb redis-server nginx php8.3-fpm

DB_PASS="$(openssl rand -hex 20)"
echo -e "${YELLOW}Creating Pterodactyl database...${RESET}"
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

if [[ ! -f artisan ]]; then
    echo -e "${YELLOW}Downloading latest Pterodactyl Panel...${RESET}"
    curl -fL -o /tmp/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzf /tmp/panel.tar.gz -C /var/www/pterodactyl
    rm -f /tmp/panel.tar.gz
fi

chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 storage bootstrap/cache

if [[ ! -f .env ]]; then
    cp .env.example .env
fi

sed -i "s|^APP_URL=.*|APP_URL=http://${DOMAIN}|" .env
sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=mariadb|" .env
sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env
sed -i "s|^DB_PORT=.*|DB_PORT=3306|" .env
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=panel|" .env
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=pterodactyl|" .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env

if grep -q '^APP_KEY=$' .env || ! grep -q '^APP_KEY=' .env; then
    sudo -u www-data php artisan key:generate --force
fi

echo -e "${YELLOW}Installing PHP dependencies...${RESET}"
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction

echo -e "${YELLOW}Running migrations...${RESET}"
php artisan migrate --seed --force

cat >/etc/systemd/system/pteroq.service <<'SERVICE'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5s
[Install]
WantedBy=multi-user.target
SERVICE

cat >/etc/nginx/sites-available/pterodactyl.conf <<NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log /var/log/nginx/pterodactyl-access.log;
    error_log /var/log/nginx/pterodactyl-error.log;

    client_max_body_size 100m;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf

nginx -t
systemctl daemon-reload
systemctl enable --now pteroq
systemctl restart nginx php8.3-fpm

# Create admin interactively using the official artisan command.
echo
echo -e "${GREEN}Panel files and database are installed.${RESET}"
echo -e "${CYAN}Now create the first administrator account:${RESET}"
cd /var/www/pterodactyl
php artisan p:user:make

if [[ "$SSL" =~ ^[Yy]$ ]]; then
    apt-get install -y certbot python3-certbot-nginx
    if certbot --nginx -d "$DOMAIN"; then
        sed -i "s|^APP_URL=.*|APP_URL=https://${DOMAIN}|" .env
        php artisan config:clear
    else
        echo -e "${YELLOW}Certbot could not issue the certificate. The panel remains available over HTTP.${RESET}"
    fi
fi

chown -R www-data:www-data /var/www/pterodactyl

echo
echo -e "${GREEN}${BOLD}Panel installation completed.${RESET}"
echo -e "URL: ${CYAN}http${SSL:+s}://${DOMAIN}${RESET}"
echo -e "Database password was generated automatically."
echo -e "${YELLOW}Back up /var/www/pterodactyl/.env securely because it contains APP_KEY and database credentials.${RESET}"
