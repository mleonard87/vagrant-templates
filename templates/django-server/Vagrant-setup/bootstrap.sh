#!/usr/bin/env bash

POSTGRES_VERSION="9.3"
POSTGRES_PASSWORD="dev"

# Set the following in secrets.json.
APP_DB_USER=`python /vagrant/foxfoi/settings/secrets.py DB_USERNAME`
APP_DB_PASSWORD=`python /vagrant/foxfoi/settings/secrets.py DB_PASSWORD`
APP_DB_NAME=`python /vagrant/foxfoi/settings/secrets.py DB_NAME`

apt-get update

# Apache and WSGI module
apt-get install -y apache2
apt-get install -y libapache2-mod-wsgi

# Git
apt-get install -y git

# Python
apt-get install -y python-dev
apt-get install -y python-setuptools
easy_install pip

# Postgres
apt-get install -y "postgresql-$POSTGRES_VERSION" "postgresql-contrib-$POSTGRES_VERSION"

# python/postgres bindings/drivers:
apt-get install -y python-psycopg2

# Node.js, npm and bower
apt-get install -y node
apt-get install -y npm
npm install -g bower

# Apache config
a2enmod headers

if ! grep -1 "ServerSignature off" /etc/apache2/apache2.conf; then
  echo "ServerSignature off" >> /etc/apache2/apache2.conf
fi
if ! grep -1 "ServerTokens Prod" /etc/apache2/apache2.conf; then
  echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
fi
# sendfile needs to be off due to VirtualBox bug, see https://github.com/mitchellh/vagrant/issues/351#issuecomment-1339640
if ! grep -1 "EnableSendfile Off" /etc/apache2/apache2.conf; then
  echo "EnableSendfile Off" >> /etc/apache2/apache2.conf  
fi

if ! grep -1 "Include httpd.conf" /etc/apache2/apache2.conf; then
  echo "Include httpd.conf" >> /etc/apache2/apache2.conf  
fi

sudo cp /vagrant/Vagrant-setup/httpd.conf /etc/apache2/httpd.conf

sudo service apache2 restart


# PostgreSQL
PG_CONF="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf"
# PG_DIR="/var/lib/postgresql/$POSTGRES_VERSION/main"

echo -e "$POSTGRES_PASSWORD\n$POSTGRES_PASSWORD" | (sudo passwd postgres)

# Edit postgresql.conf to change listen address to '*':
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

# Append to pg_hba.conf to add password auth:
echo "host    $APP_DB_NAME      $APP_DB_USER             samenet                 md5" >> "$PG_HBA"

# Explicitly set default client_encoding
echo "client_encoding = utf8" >> "$PG_CONF"

# Restart so that all new config is loaded:
service postgresql restart

cat << EOF | su - postgres -c psql
CREATE USER $APP_DB_USER WITH PASSWORD '$APP_DB_PASSWORD';
CREATE DATABASE $APP_DB_NAME WITH OWNER=$APP_DB_USER ENCODING='UTF8' TEMPLATE=template1;
EOF


# Django
sudo pip install -r /vagrant/requirements.txt
chmod u+x /vagrant/manage.py
/vagrant/manage.py migrate

sudo service apache2 restart