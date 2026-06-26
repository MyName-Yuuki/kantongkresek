print_box "?? Configuring Nginx + PHP-FPM"

# Stop & Remove Apache (jika ada)
run_cmd "systemctl stop apache2 2>/dev/null || true" "Stopped Apache"
run_cmd "systemctl disable apache2 2>/dev/null || true" "Disabled Apache"
run_cmd "apt purge -y apache2 apache2-bin apache2-data apache2-utils >/dev/null 2>&1 || true" "Removed Apache"

# Enable PHP-FPM
run_cmd "systemctl enable php8.4-fpm" "Enabled PHP-FPM"
run_cmd "systemctl restart php8.4-fpm" "Started PHP-FPM"

# Backup konfigurasi lama
[ -f /etc/nginx/sites-available/default ] && \
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak

cat > /etc/nginx/sites-available/default << 'EOF'
server {

    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /var/www/html;
    index index.php index.html index.htm;

    charset utf-8;

    client_max_body_size 1024M;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;

    ##################################
    ## Rewrite (pengganti .htaccess)
    ##################################

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    ##################################
    ## PHP-FPM
    ##################################

    location ~ \.php$ {

        include snippets/fastcgi-php.conf;

        fastcgi_pass unix:/run/php/php8.4-fpm.sock;

        fastcgi_index index.php;

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        include fastcgi_params;

        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    ##################################
    ## Cache File
    ##################################

    location ~* \.(jpg|jpeg|gif|png|css|js|ico|svg|woff|woff2|ttf)$ {
        expires 30d;
        access_log off;
    }

    ##################################
    ## Block hidden files
    ##################################

    location ~ /\. {
        deny all;
    }

    ##################################
    ## Gzip
    ##################################

    gzip on;
    gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        application/xml
        text/xml
        image/svg+xml;
}
EOF

# Enable site
run_cmd "ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default" "Enabled Nginx Site"

# Test konfigurasi
run_cmd "nginx -t" "Nginx Configuration OK"

# Enable nginx
run_cmd "systemctl enable nginx" "Enabled Nginx"

# Restart nginx
run_cmd "systemctl restart nginx" "Restarted Nginx"

print_success "Nginx + PHP-FPM configured successfully"