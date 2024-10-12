# newznab-installer.sh
bash script for ubuntu 20.x - tested on Ubuntu server clean install.
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 24.04.1 LTS
Release:        24.04
Codename:       noble

Edit the script to your needs, your domain and your passwords, etc.
chmod +x nn-installer.sh
sudo ./nn-installer.sh

* be sure to edit your domain for SSL via LE cerbot.
* also the script will create your DB, so us that information when on database install step of the NN installer. Otherwise you'll get a 590 err.
  

See also : https://github.com/nakedgoat/newznab-backfill.php/tree/main
for issues running screen update script, pear.php and client.php errors.

