#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "================================================================"
echo "||                  Reverse Proxy Setup Script                ||"
echo "================================================================"


echo "Enter the frontend web server's IP address (e.g., 192.168.1.10): "
read WEB_SERVER_IP
[ -z "$WEB_SERVER_IP" ] && { echo "Frondend web server IP cannot be empty"; exit 1; }

echo "Enter the domain name of website (e.g., example.com): "
read DOMAIN_NAME
[ -z "$DOMAIN_NAME" ] && { echo "Domain name cannot be empty"; exit 1; }

echo "Enter the port number on which the frontend web server is running (default is 3000): "
read FE_WEB_SERVER_PORT
FE_WEB_SERVER_PORT=${FE_WEB_SERVER_PORT:-3000}
[[ "$FE_WEB_SERVER_PORT" =~ ^[0-9]+$ ]] || { echo "Invalid port"; exit 1; }

echo "Enter the port number on which the backend web server is running (default is 5000): "
read BE_WEB_SERVER_PORT
BE_WEB_SERVER_PORT=${BE_WEB_SERVER_PORT:-5000}
[[ "$BE_WEB_SERVER_PORT" =~ ^[0-9]+$ ]] || { echo "Invalid port"; exit 1; }

echo "Enter the file path of SSL certificates: "
read SSL_CERT_PATH
FILE_NAME_SSL_CERT=$(basename "$SSL_CERT_PATH")

echo "Enter the file path of intermediate1 certificates: "
read INTERMEDIATE1_CERT_PATH
FILE_NAME_INTERMEDIATE1_CERT=$(basename "$INTERMEDIATE1_CERT_PATH")

echo "Enter the file path of intermediate2 certificates: "
read INTERMEDIATE2_CERT_PATH
FILE_NAME_INTERMEDIATE2_CERT=$(basename "$INTERMEDIATE2_CERT_PATH")

echo "Enter the file path of the private key: "
read PRIVATE_KEY_PATH
FILE_NAME_PRIVATE_KEY=$(basename "$PRIVATE_KEY_PATH")

apt update && apt install -y nginx
systemctl start nginx
systemctl enable nginx

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt

for f in "$SSL_CERT_PATH" "$INTERMEDIATE1_CERT_PATH" "$INTERMEDIATE2_CERT_PATH" "$PRIVATE_KEY_PATH"; do
    [ -f "$f" ] || { echo "File not found: $f"; exit 1; }
done

cp "$SSL_CERT_PATH" /etc/ssl/certs/
cp "$INTERMEDIATE1_CERT_PATH" /etc/ssl/certs/
cp "$INTERMEDIATE2_CERT_PATH" /etc/ssl/certs/
cp "$PRIVATE_KEY_PATH" /etc/ssl/private/

NEW_PATH_SSL_CERT="/etc/ssl/certs/$FILE_NAME_SSL_CERT"
NEW_PATH_INTERMEDIATE1_CERT="/etc/ssl/certs/$FILE_NAME_INTERMEDIATE1_CERT"
NEW_PATH_INTERMEDIATE2_CERT="/etc/ssl/certs/$FILE_NAME_INTERMEDIATE2_CERT"
NEW_PATH_PRIVATE_KEY="/etc/ssl/private/$FILE_NAME_PRIVATE_KEY"
NEW_PATH_FULLCHAIN="/etc/ssl/certs/${DOMAIN_NAME}_fullchain.cer"

cat "$NEW_PATH_SSL_CERT" "$NEW_PATH_INTERMEDIATE1_CERT" "$NEW_PATH_INTERMEDIATE2_CERT" > "$NEW_PATH_FULLCHAIN"

chown root:root "$NEW_PATH_SSL_CERT"
chmod 644 "$NEW_PATH_SSL_CERT"
chown root:root "$NEW_PATH_INTERMEDIATE1_CERT"
chmod 644 "$NEW_PATH_INTERMEDIATE1_CERT"
chown root:root "$NEW_PATH_INTERMEDIATE2_CERT"
chmod 644 "$NEW_PATH_INTERMEDIATE2_CERT"
chown root:root "$NEW_PATH_PRIVATE_KEY"
chmod 600 "$NEW_PATH_PRIVATE_KEY"
chown root:root "$NEW_PATH_FULLCHAIN"
chmod 644 "$NEW_PATH_FULLCHAIN"

rm -f /etc/nginx/sites-enabled/default

tee /etc/nginx/sites-available/"$DOMAIN_NAME" <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 444;
}

server {
    listen 443 ssl default_server;
    server_name _;

    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

    return 444;
}

server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;

    client_max_body_size 20M;

    ssl_certificate $NEW_PATH_FULLCHAIN;
    ssl_certificate_key $NEW_PATH_PRIVATE_KEY;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://$WEB_SERVER_IP:$FE_WEB_SERVER_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /api/ {
        proxy_pass http://$WEB_SERVER_IP:$BE_WEB_SERVER_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

EOF

ln -sf /etc/nginx/sites-available/"$DOMAIN_NAME" /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
echo "Reverse proxy setup completed successfully!"
