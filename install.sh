#!/usr/bin/env bash

# Exit this script on the first error.
#------------------------------------------------------------------------------
set -e


# Define Operating system
#------------------------------------------------------------------------------
OS=$(uname -s)
if [[ $OS == Linux ]]; then
    DISTID=$(lsb_release -i |awk '{print $3}')
    if [[ $DISTID == Ubuntu ]]; then
        RELEASE=$(lsb_release -r |awk '{print $2}')
        if [[ $RELEASE == "16.04" ]]; then
            echo "Installing for $DISTID $RELEASE"
        else
            echo "installation for $DISTID $RELEASE not implemented"
            exit 1
        fi
    else
        echo "$DISTID installation not implemented"
        exit 1
    fi
else
    echo "$OS installation not implemented."
    exit 1
fi


# Exit this script on the first error.
#------------------------------------------------------------------------------
WEBGUI_USERNAME=$(< /dev/urandom tr -dc a-z | head -c${1:-8};echo;)
WEBGUI_PASSWORD="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c${1:-32};echo;)$(date +%s | sha256sum | base64 | head -c 32 ; echo)"
WEBGUI_PASSWORD_HASH=$(openssl passwd -crypt $WEBGUI_PASSWORD);


# Create self signed passwordless certificate generation
#------------------------------------------------------------------------------
if [ ! -f /etc/ssl/private/btsync-$(hostname).key ]; then
    sudo openssl req \
        -new \
        -newkey rsa:4096 \
        -days 365 \
        -nodes \
        -x509 \
        -subj "/" \
        -keyout /etc/ssl/private/btsync-$(hostname).key \
        -out /etc/ssl/private/btsync-$(hostname).csr
    sudo chmod 0400 /etc/ssl/private/btsync-$(hostname).key
    sudo chmod 0400 /etc/ssl/private/btsync-$(hostname).csr
fi

#if [ ! -f /etc/ssl/private/dhparams.pem ]; then
#    sudo openssl dhparam -out /etc/ssl/private/dhparams.pem 4096
#    sudo rm ~/.rnd 
#    sudo chmod 0400 /etc/ssl/private/dhparams.pem
#fi


# Add btsync official Linux repository
#------------------------------------------------------------------------------
sudo sh -c 'echo "deb http://linux-packages.getsync.com/btsync/deb btsync non-free" > /etc/apt/sources.list.d/btsync.list'


# Install the public key so that your system will trust the packages from that repository
#------------------------------------------------------------------------------
wget -qO - http://linux-packages.getsync.com/btsync/key.asc | sudo apt-key add -


# Update your system cache and finally install btsync
#------------------------------------------------------------------------------
sudo apt-get update && sudo apt-get install -y btsync


# Config btsync
#------------------------------------------------------------------------------
sudo mkdir -p /MySharedFolders
sudo chown btsync:btsync /MySharedFolders

BTSYNC_PORT=43215
sudo sh -c "echo '{
    \"device_name\": \"'$(hostname)'\",
    \"listening_port\" : '"$(echo $BTSYNC_PORT)"',
    \"storage_path\" : \"/var/lib/btsync/\",
    \"pid_file\" : \"/var/run/btsync/btsync.pid\",
    \"agree_to_EULA\": \"yes\",

    \"webui\" :
    {
        \"listen\" : \"127.0.0.1:8888\"
        ,\"login\" : \"'"$(echo $WEBGUI_USERNAME)"'\"
        ,\"password_hash\" : \"'"$(echo $WEBGUI_PASSWORD_HASH)"'\"
        ,\"allow_empty_password\" : false
        ,\"directory_root\" : \"/MySharedFolders\"
    }
}' > /etc/btsync/config.json"


# Activate and start btsync
#------------------------------------------------------------------------------
sudo systemctl start btsync
sudo systemctl enable btsync
systemctl status btsync


# Install nginx
#------------------------------------------------------------------------------
sudo apt-get install -y nginx
sudo systemctl stop nginx


# Config nginx
#------------------------------------------------------------------------------
sudo sh -c "echo '
server {
    listen 80;
    server_name ~.;
    server_tokens off;
    add_header X-Frame-Options \"SAMEORIGIN\";
    add_header X-XSS-Protection \"1; mode=block\";
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name ~.;
    server_tokens off;
    add_header X-Frame-Options \"SAMEORIGIN\";
    add_header X-XSS-Protection \"1; mode=block\";

    ssl on;
    ssl_certificate /etc/ssl/private/btsync-'$(hostname)'.csr;
    ssl_certificate_key /etc/ssl/private/btsync-'$(hostname)'.key;
    # ssl_dhparam /etc/ssl/private/dhparams.pem;

    ssl_session_cache shared:SSL:20m;
    ssl_session_timeout 60m;
    ssl_prefer_server_ciphers on;

    ssl_ciphers \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA HIGH "!"RC4 "!"aNULL "!"eNULL "!"LOW "!"3DES "!"MD5 "!"EXP "!"PSK "!"SRP "!"DSS\";
    ssl_protocols TLSv1.1 TLSv1.2; 
    ssl_stapling on;
    ssl_stapling_verify on;


    access_log /var/log/nginx/sync-'$(hostname)'.log;
    location / {
        proxy_pass http://127.0.0.1:8888;
    }
}
' > /etc/nginx/conf.d/btsync.conf"


# Activate and start nginx
#------------------------------------------------------------------------------
sudo systemctl start nginx
sudo systemctl enable nginx
systemctl status nginx


# Update firewall rules
#------------------------------------------------------------------------------
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow "$BTSYNC_PORT"/udp


# Finish installation
#------------------------------------------------------------------------------
echo "Installation complete"
echo "Web GUI username: $WEBGUI_USERNAME"
echo "Web GUI password: $WEBGUI_PASSWORD"
cat /dev/null > ~/.bash_history && history -c && exit 0
