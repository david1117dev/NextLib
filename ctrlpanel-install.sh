#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/david1117dev/BashLib/main/lib.sh)

# Update system repositories
info "Updating system repositories..."
install "software-properties-common,curl,apt-transport-https,ca-certificates,gnupg"
info "Adding additional repositories for PHP."
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > "$OUTPUT_TARGET"
apt-get update > "$OUTPUT_TARGET"
install "nginx,tar,unzip,git,redis-server,mariadb-server,php8.1,php8.1-cli,php8.1-gd,php8.1-mysql,php8.1-pdo,php8.1-mbstring,php8.1-tokenizer,php8.1-bcmath,php8.1-xml,php8.1-fpm,php8.1-curl,php8.1-zip"
info "Installing Composer..."
curl -sS https://getcomposer.org/installer | php --install-dir=/usr/local/bin --filename=composer > "$OUTPUT_TARGET"
info "Creating the control panel folder and downloading files..."
rm -rf /var/www/controlpanel/
mkdir /var/www/controlpanel && cd /var/www/controlpanel
git clone https://github.com/Ctrlpanel-gg/panel.git ./ > "$OUTPUT_TARGET"

# Basic Setup
info "Setting up the database..."
# Replace 'USE_YOUR_OWN_PASSWORD' with your chosen password.
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE controlpanel;
CREATE USER 'controlpaneluser'@'127.0.0.1' IDENTIFIED BY 'USE_YOUR_OWN_PASSWORD';
GRANT ALL PRIVILEGES ON controlpanel.* TO 'controlpaneluser'@'127.0.0.1';
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

# Web server configuration
info "Configuring the web server..."
# Create the Nginx config file with the appropriate settings.
cat > /etc/nginx/sites-available/ctrlpanel.conf << NGINX_CONFIG
# Your Nginx configuration here
NGINX_CONFIG

# Enable Nginx configuration
ln -s /etc/nginx/sites-available/ctrlpanel.conf /etc/nginx/sites-enabled/ctrlpanel.conf
nginx -t > "$OUTPUT_TARGET"
systemctl restart nginx > "$OUTPUT_TARGET"

# Adding SSL (optional)
info "Adding SSL using Certbot"
apt update > "$OUTPUT_TARGET"
apt install -y certbot > "$OUTPUT_TARGET"
apt install -y python3-certbot-nginx > "$OUTPUT_TARGET"
certbot --nginx -d yourdomain.com > "$OUTPUT_TARGET"

# Panel Installation
info "Installing Composer packages..."
composer install --working-dir /var/www/controlpanel/ --no-dev --optimize-autoloader > "$OUTPUT_TARGET"

# Set Permissions
info "Setting permissions..."
# Modify permissions based on your web server (nginx, apache)
chown -R www-data:www-data /var/www/controlpanel/
chmod -R 755 storage/* bootstrap/cache/

# Additional steps...

# Running the installer
info "Access the web installer at https://yourdomain.com/install and follow the steps."

# Set up queue listeners
info "Setting up queue listeners..."
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/controlpanel/artisan schedule:run >> /dev/null 2>&1") | crontab -

# Create Queue Worker
info "Creating a Queue Worker..."
cat > /etc/systemd/system/ctrlpanel.service << QUEUE_WORKER
[Unit]
Description=Ctrlpanel Queue Worker

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/controlpanel/artisan queue:work --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
QUEUE_WORKER

# Enable Queue Worker service
systemctl enable --now ctrlpanel.service > "$OUTPUT_TARGET"

info "Installation complete. You can now access the dashboard via your web browser."
