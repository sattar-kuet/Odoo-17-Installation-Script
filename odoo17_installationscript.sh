#!/bin/bash
################################################################################
# Script for installing Odoo 17 on Ubuntu 18.04, 20.04, 22.04
# Author: Modified from Yenthe Van Ginneken's script
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"

# Set Odoo version
OE_VERSION="17.0"

# Set default Odoo port
OE_PORT="8069"

# Install PostgreSQL 15 (recommended for Odoo 17)
INSTALL_POSTGRESQL_FIFTEEN="True"

# Set this to True if you want to install the Odoo Enterprise version
IS_ENTERPRISE="False"

# Set the superadmin password (or generate a random one)
GENERATE_RANDOM_PASSWORD="True"
OE_SUPERADMIN="admin"

# Set the website name
WEBSITE_NAME="odoo.local"

# Set the default Odoo longpolling port
LONGPOLLING_PORT="8072"

# Set to "True" to install Nginx
INSTALL_NGINX="False"

# Set to "True" to enable SSL with certbot
ENABLE_SSL="False"

# Email for SSL certificate registration
ADMIN_EMAIL="odoo@example.com"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt update && sudo apt upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
if [ $INSTALL_POSTGRESQL_FIFTEEN = "True" ]; then
    echo -e "\n---- Installing PostgreSQL 15 ----"
    sudo apt install -y postgresql-15
else
    echo -e "\n---- Installing default PostgreSQL version ----"
    sudo apt install -y postgresql postgresql-server-dev-all
fi

echo -e "\n---- Creating the ODOO PostgreSQL User ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Installing Dependencies ----"
sudo apt install -y python3 python3-pip python3-dev python3-venv python3-wheel \
    libxslt-dev libzip-dev libldap2-dev libsasl2-dev libjpeg-dev libpq-dev \
    nodejs npm git curl libxml2-dev libxslt1-dev libjpeg8-dev zlib1g-dev \
    libpng-dev gdebi

#--------------------------------------------------
# Install Python Packages
#--------------------------------------------------
echo -e "\n---- Installing Python packages ----"
sudo -H pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt
sudo -H pip3 install pillow reportlab psycopg2-binary

#--------------------------------------------------
# Install Node.js, npm, and rtlcss
#--------------------------------------------------
echo -e "\n---- Installing Node.js, npm, and rtlcss ----"
sudo npm install -g rtlcss

#--------------------------------------------------
# Create Odoo System User
#--------------------------------------------------
echo -e "\n---- Creating Odoo System User ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
sudo adduser $OE_USER sudo

#--------------------------------------------------
# Create Log Directory
#--------------------------------------------------
echo -e "\n---- Creating Log Directory ----"
sudo mkdir -p /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install Odoo
#--------------------------------------------------
echo -e "\n==== Installing Odoo Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://github.com/odoo/odoo $OE_HOME_EXT

if [ $IS_ENTERPRISE = "True" ]; then
    echo -e "\n---- Installing Odoo Enterprise ----"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"
    sudo git clone --depth 1 --branch $OE_VERSION https://github.com/odoo/enterprise "$OE_HOME/enterprise/addons"
    sudo -H pip3 install num2words ofxparse dbfread ebaysdk firebase_admin
fi

echo -e "\n---- Creating Custom Addons Directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting Permissions on Home Folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

#--------------------------------------------------
# Create Odoo Configuration File
#--------------------------------------------------
echo -e "\n---- Creating Odoo Configuration File ----"
sudo tee /etc/${OE_USER}.conf <<EOF
[options]
admin_passwd = ${OE_SUPERADMIN}
xmlrpc_port = ${OE_PORT}
longpolling_port = ${LONGPOLLING_PORT}
logfile = /var/log/${OE_USER}/${OE_USER}.log
addons_path = ${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons
EOF

sudo chown $OE_USER:$OE_USER /etc/${OE_USER}.conf
sudo chmod 640 /etc/${OE_USER}.conf

#--------------------------------------------------
# Create Systemd Service File
#--------------------------------------------------
echo -e "\n---- Creating Systemd Service File ----"
sudo tee /etc/systemd/system/odoo.service <<EOF
[Unit]
Description=Odoo 17
After=network.target

[Service]
Type=simple
User=$OE_USER
ExecStart=$OE_HOME_EXT/odoo-bin --config=/etc/${OE_USER}.conf
WorkingDirectory=$OE_HOME_EXT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable odoo
sudo systemctl start odoo

#--------------------------------------------------
# Install and Configure Nginx (Optional)
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
    echo -e "\n---- Installing and Setting Up Nginx ----"
    sudo apt install -y nginx
    sudo tee /etc/nginx/sites-available/$WEBSITE_NAME <<EOF
server {
    listen 80;
    server_name $WEBSITE_NAME;

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    location / {
        proxy_pass http://127.0.0.1:$OE_PORT;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
    }
}
EOF

    sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
fi

#--------------------------------------------------
# Enable SSL with Certbot (Optional)
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ] && [ $WEBSITE_NAME != "_" ]; then
    echo -e "\n---- Installing SSL Certificate ----"
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
    sudo systemctl reload nginx
fi

#--------------------------------------------------
# Completion Message
#--------------------------------------------------
echo "-----------------------------------------------------------"
echo "Odoo 17 Installation Completed!"
echo "Access Odoo at: http://your_server_ip:$OE_PORT"
echo "Start Odoo: sudo systemctl start odoo"
echo "Stop Odoo: sudo systemctl stop odoo"
echo "Restart Odoo: sudo systemctl restart odoo"
echo "-----------------------------------------------------------"
