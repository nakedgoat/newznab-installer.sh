#!/bin/bash

# Step 1: Install required packages
echo "Updating and installing required packages..."
sudo apt update && sudo apt upgrade -y
if ! sudo apt install -y ssh screen apache2 php mariadb-server php-fpm php-pear php-gd php-mysql php-redis php-curl php-json php-mbstring unrar lame mediainfo subversion ffmpeg redis memcached pear; then
    echo "Error: Failed to install required packages"
    exit 1
fi

# Step 2: Configure MariaDB
echo "Configuring MariaDB..."
sudo mysql -u root <<EOF
CREATE USER 'newznab'@'localhost' IDENTIFIED BY '<yourpassdhere>';
GRANT ALL PRIVILEGES ON newznab.* TO 'newznab'@'localhost' WITH GRANT OPTION;
EOF

# Edit MariaDB configuration
echo -e "[mysqld]\ngroup_concat_max_len=8192\ninnodb_flush_log_at_trx_commit = 2" | sudo tee /etc/mysql/conf.d/mysql.cnf

# Step 3: Create web directories
echo "Creating necessary directories..."
sudo mkdir -p /var/www/newznab/htdocs /var/www/newznab/logs

# Removed as NN provides this, edit it with the correct info.
# Step 4: Create a script for keeping Newznab up to date
# echo "Creating update script..."
# echo -e "#!/bin/bash\nsvn export --no-auth-cache --force --username <username> --password <password> svn://svn.newznab.com/nn/branches/nnplus /var/www/newznab/htdocs/\n\ncd /var/www/newznab/htdocs/misc/update_scripts\nphp update_database_version.php\n\nsystemctl restart memcached\nsystemctl restart apache2\nsystemctl restart php8.3-fpm" | sudo tee /var/www/newznab/svn.sh
# sudo chmod +x /var/www/newznab/svn.sh
# sudo /var/www/newznab/svn.sh 2> /dev/null

# Step 5: Setup website permissions
echo "Setting directory permissions..."
sudo chmod -R 777 /var/www/newznab/htdocs/www/lib/smarty/templates_c /var/www/newznab/htdocs/www/covers /var/www/newznab/htdocs/www/install /var/www/newznab/htdocs/db/cache /var/www/newznab/htdocs/nzbfiles/

# Replace default Apache config
echo "Configuring Apache for Newznab..."
echo -e "<VirtualHost *:80>\n\t<Directory /var/www/newznab/htdocs/www/>\n\t\tOptions FollowSymLinks\n\t\tAllowOverride All\n\t\tOrder allow,deny\n\t\tallow from all\n\t</Directory>\n\n\tDocumentRoot /var/www/newznab/htdocs/www\n\tErrorLog /var/www/newznab/logs/error.log\n\tCustomLog /var/www/newznab/logs/access.log combined\n</VirtualHost>" | sudo tee /etc/apache2/sites-available/000-default.conf

# Step 6: Update PHP settings
echo "Updating PHP settings..."
sudo sed -i "s/;date.timezone =/date.timezone = 'America\/Phoenix'/g" /etc/php/8.3/fpm/php.ini
sudo sed -i "s/max_execution_time = 30/max_execution_time = 120/g" /etc/php/8.3/fpm/php.ini
sudo sed -i "s/memory_limit =  -1/memory_limit = -1/g" /etc/php/8.3/fpm/php.ini

# Enable Apache mod_rewrite and php-fpm, then restart services
echo "Enabling necessary Apache modules..."
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php8.3-fpm
sudo a2enmod rewrite
sudo systemctl restart php8.3-fpm
sudo systemctl restart apache2
sudo systemctl restart mysql

# Step 7: Check if Newznab+ installation wizard is accessible
echo "Checking Newznab+ installation wizard..."
if curl --output /dev/null --silent --head --fail "http://localhost/install"; then
  echo "Newznab+ installation wizard is accessible at http://localhost/install"
else
  echo "Unable to access the Newznab+ installation wizard at http://localhost/install"
fi

# REMOVED NN provides newznab_screen.sh 
#echo "Configuring Newznab+ to run in the background using screen..."
#echo -e "export NEWZNAB_PATH=\"/var/www/newznab/htdocs/misc/update_scripts\"\nexport NEWZNAB_SLEEP_TIME=\"30\" # in seconds\n/usr/bin/php \${NEWZNAB_PATH}/update_binaries_threaded.php" | sudo tee /var/www/newznab/htdocs/misc/update_scripts/nix_scripts/newznab_local.sh
#sudo chmod +x /var/www/newznab/htdocs/misc/update_scripts/nix_scripts/newznab_local.sh
#screen -dmS newznab /var/www/newznab/htdocs/misc/update_scripts/nix_scripts/newznab_local.sh

# Optional Step 2: Configure Elasticsearch (Optional)
echo "Installing and configuring Elasticsearch..."
sudo apt install apt-transport-https
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update
sudo apt install elasticsearch -y
sudo systemctl enable --now elasticsearch.service
sudo sed -i "s/xpack.security.enabled: true/xpack.security.enabled: false/g" /etc/elasticsearch/elasticsearch.yml
sudo systemctl restart elasticsearch

# Optional Step 3: Install phpMemcachedAdmin
echo "Installing phpMemcachedAdmin..."
cd /tmp
wget https://github.com/wp-cloud/phpmemcacheadmin/archive/refs/heads/master.zip
cd /var/www
sudo mkdir phpmemcacheadmin
cd phpmemcacheadmin
sudo unzip /tmp/master.zip
sudo mv phpMemcachedAdmin-master/* .
sudo rmdir phpMemcachedAdmin-master
rm /tmp/master.zip

# Set permissions for Newznab directories
echo "Setting permissions for Newznab directories..."
sudo chmod 755 -R /var/www/newznab/
sudo chown www-data:www-data -R /var/www/newznab

# Step 8: Enable Apache SSL and obtain certificates using Certbot
echo "Setting up SSL with Certbot..."
sudo apt install snapd -y
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --apache -d <your-domain.here>

# Ask if the user wants to install Spotweb
read -p "Do you want to install Spotweb? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing Spotweb..."
    sudo git clone https://github.com/spotweb/spotweb.git /var/www/spotweb
fi

echo "Installation complete. Visit http://yourhost/spotweb/install.php to continue the setup."
