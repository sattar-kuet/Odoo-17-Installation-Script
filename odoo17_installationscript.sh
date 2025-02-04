#!/bin/bash
################################################################################
# Script to install Odoo 17 on Ubuntu 24.04 LTS with Nginx and SSL
################################################################################


ODOO_USER="odoo17"
ODOO_HOME="/opt/$ODOO_USER"
ODOO_CONFIG="/etc/${ODOO_USER}_userfantasy.conf" # <-- Replace userfantasy
ODOO_PORT="8069"
ODOO_SERVICE="odoo17_userfantasy.service"  #<-- Replace userfantasy
DOMAIN="biz.userfantasy.com"  # <-- Replace with your domain
EMAIL="sattar.kuet@email.com"   


echo -e "\nUpdating system..."
sudo apt update && sudo apt upgrade -y


echo -e "\nInstalling required packages..."
sudo apt install -y python3 python3-pip python3-venv python3-dev \
    libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev \
    libldap2-dev build-essential libjpeg-dev libpq-dev \
    libffi-dev libmysqlclient-dev libtiff5-dev libopenjp2-7-dev \
    liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev \
    libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi \
    xfonts-base wkhtmltopdf git curl nginx certbot python3-certbot-nginx


echo -e "\nInstalling PostgreSQL..."
sudo apt install -y postgresql
sudo systemctl enable --now postgresql


echo -e "\nCreating PostgreSQL user..."
sudo -u postgres createuser -s $ODOO_USER || true


echo -e "\nCreating Odoo system user..."
sudo useradd -m -d $ODOO_HOME -U -r -s /bin/bash $ODOO_USER
sudo mkdir -p $ODOO_HOME/custom-addons
sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME


echo -e "\nCloning Odoo 17 repository..."
sudo -u $ODOO_USER git clone --depth 1 --branch 17.0 https://github.com/odoo/odoo.git $ODOO_HOME/odoo


echo -e "\nSetting up Python virtual environment..."
sudo -u $ODOO_USER python3 -m venv $ODOO_HOME/venv
sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install --upgrade pip wheel
sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install -r $ODOO_HOME/odoo/requirements.txt


echo -e "\nCreating Odoo configuration file..."
sudo bash -c "cat > $ODOO_CONFIG" <<EOF
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo17
db_password = False
addons_path = $ODOO_HOME/odoo/addons,$ODOO_HOME/custom-addons
xmlrpc_port = $ODOO_PORT
logfile = /var/log/$ODOO_USER.log
EOF

sudo chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG
sudo chmod 640 $ODOO_CONFIG


echo -e "\nCreating systemd service file..."
sudo bash -c "cat > /etc/systemd/system/$ODOO_SERVICE" <<EOF
[Unit]
Description=Odoo 17
After=network.target postgresql.service

[Service]
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 $ODOO_HOME/odoo/odoo-bin -c $ODOO_CONFIG
StandardOutput=journal+console
Restart=always

[Install]
WantedBy=multi-user.target
EOF


echo -e "\nStarting Odoo service..."
sudo systemctl daemon-reload
sudo systemctl enable --now $ODOO_SERVICE


echo -e "\nConfiguring Nginx as reverse proxy..."
sudo bash -c "cat > /etc/nginx/sites-available/odoo" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://127.0.0.1:$ODOO_PORT;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
sudo nginx -t && sudo systemctl restart nginx


echo -e "\nInstalling SSL certificate..."
sudo certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email $EMAIL -d $DOMAIN


echo -e "\nOdoo 17 with Nginx and SSL installation completed!"
echo -e "Access Odoo at: https://$DOMAIN"
echo -e "To check logs: sudo journalctl -u $ODOO_SERVICE -f"
