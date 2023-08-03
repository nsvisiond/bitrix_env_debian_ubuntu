#!/bin/bash

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}${BOLD}Bitrix Enviroment Debian/Ubuntu installer [PHP 8.2]${NORMAL}${NC}"

echo -e "${RED}${BOLD}Update system and install needed packages. Please wait...${NORMAL}${NC}"
apt-get -qqy update && apt-get -qqy upgrade 2> /dev/null
apt-get -qqy install unzip mc htop 2> /dev/null
if [ ! -f /etc/selinux/config ]; then
	echo -e "${RED}${BOLD}It needs to disable SELINUX and reboot server for continue. Confirm?${NORMAL}${NC}";
	select yn in "Yes" "No"; do
    		case $yn in
        		Yes ) echo 'SELINUX=disabled' > /etc/selinux/config; echo -e "${RED}${BOLD}Reboot!${NORMAL}${NC}"; reboot; exit;;
        		No ) echo -e "${RED}${BOLD}Installer stopped.${NORMAL}${NC}"; exit;;
    		esac
	done
fi

echo -e "${RED}${BOLD}Unpacking configs${NORMAL}${NC}"
wget -q https://dev.1c-bitrix.ru/docs/chm_files/debian.zip
unzip -qqo debian.zip 2> /dev/null

echo -e "${RED}${BOLD}Installing PHP 8.2${NORMAL}${NC}"
apt-get install -qqy lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 > /dev/null
add-apt-repository -y ppa:ondrej/php > /dev/null
apt-get -qqy update > /dev/null
apt-get -qqy install php8.2 php8.2-cli \
    php8.2-common php8.2-gd php8.2-ldap \
    php8.2-mbstring php8.2-mysql \
    php8.2-opcache \
    php-pear php8.2-apcu php-geoip \
    php8.2-mcrypt php8.2-memcache\
    php8.2-zip php8.2-pspell php8.2-xml > /dev/null
echo -e "${RED}${BOLD}Installing nginx${NORMAL}${NC}"
apt-get -qqy install nginx > /dev/null
echo -e "${RED}${BOLD}Installing MariaDB${NORMAL}${NC}"
apt-get -qqy install mariadb-server mariadb-common 2> /dev/null
echo -e "${RED}${BOLD}Installing NodeJS & npm${NORMAL}${NC}"
apt-get -qqy install nodejs npm 2> /dev/null
echo -e "${RED}${BOLD}Installing Redis${NORMAL}${NC}"
apt-get -qqy install redis 2> /dev/null
echo -e "${RED}${BOLD}Installing Composer${NORMAL}${NC}"
apt-get -qqy install composer 2> /dev/null

echo -e "${RED}${BOLD}Configure nginx${NORMAL}${NC}"
rsync -avq debian/nginx/ /etc/nginx/
echo "127.0.0.1 push httpd" >> /etc/hosts
systemctl --quiet stop apache2
systemctl --now --quiet enable nginx

echo -e "${RED}${BOLD}Configure PHP${NORMAL}${NC}"
rsync -avq debian/php.d/ /etc/php/8.2/mods-available/
 ln -sf /etc/php/8.2/mods-available/zbx-bitrix.ini  /etc/php/8.2/apache2/conf.d/99-bitrix.ini
 ln -sf /etc/php/8.2/mods-available/zbx-bitrix.ini  /etc/php/8.2/cli/conf.d/99-bitrix.ini

echo -e "${RED}${BOLD}Configure Apache${NORMAL}${NC}"
rsync -avq debian/apache2/ /etc/apache2/
a2dismod --quiet --force autoindex
a2enmod --quiet rewrite
systemctl --now --quiet enable apache2
systemctl --now --quiet restart apache2

echo -e "${RED}${BOLD}Configure MariaDB${NORMAL}${NC}"
rsync -avq debian/mysql/ /etc/mysql/
systemctl --now --quiet enable mariadb
systemctl --quiet restart mariadb
# Make sure that NOBODY can access the server without a password
mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('root')";
# Kill the anonymous users
mysql -u root -e "DROP USER IF EXISTS ''@'localhost'"
# Because our hostname varies we'll use some Bash magic here.
mysql -u root -e "DROP USER IF EXISTS ''@'$(hostname)'"
# Kill off the demo database
mysql -u root -e "DROP DATABASE IF EXISTS test"
# Make our changes take effect
mysql -u root -e "FLUSH PRIVILEGES"
# Any subsequent tries to run queries this way will get access denied because lack of usr/pwd param

echo -e "${RED}${BOLD}Configure Redis${NORMAL}${NC}"
rsync -avq debian/redis/redis.conf /etc/redis/redis.conf
usermod -g www-data redis > /dev/null
chown root:www-data /etc/redis/ /var/log/redis/
[[ ! -d /etc/systemd/system/redis.service.d ]] && mkdir /etc/systemd/system/redis.service.d
echo -e '[Service]\nGroup=www-data' > /etc/systemd/system/redis.service.d/custom.conf
systemctl --quiet daemon-reload > /dev/null
systemctl --quiet enable redis > /dev/null
systemctl --quiet restart redis.service > /dev/null


echo -e "${RED}${BOLD}Create Base Site${NORMAL}${NC}"
mkdir /var/www/html/bx-site > /dev/null
cd /var/www/html/bx-site
rm bitrixsetup.php > /dev/null
wget -q https://www.1c-bitrix.ru/download/scripts/bitrixsetup.php
chown www-data:www-data /var/www/html/bx-site -R

mysql -u root -e "create database if not exists portal"
mysql -u root -e "CREATE USER IF NOT EXISTS 'bitrix'@'localhost' IDENTIFIED BY 'bitrix'"
mysql -u root -e "GRANT ALL PRIVILEGES ON portal.* to 'bitrix'@'localhost'"
systemctl --quiet restart apache2


echo -e "${RED}${BOLD}Bitrix Enviroment successfully installed${NORMAL}${NC}";

