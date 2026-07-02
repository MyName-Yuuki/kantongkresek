#!/bin/bash

# ============================================================
# configurations.sh — Nginx + PHP-FPM
# UI palette matches index.js (npm installer)
# ============================================================

PURPLE='\033[38;2;124;58;237m'
CYAN='\033[38;2;6;182;212m'
GREEN='\033[38;2;16;185;129m'
YELLOW='\033[38;2;245;158;11m'
RED='\033[38;2;239;68;68m'
GRAY='\033[38;2;156;163;175m'
WHITE='\033[38;2;229;231;235m'
BG_PURPLE='\033[48;2;124;58;237m'
BOLD='\033[1m'
RESET='\033[0m'

print_box() {
    local title="$1"
    local width=${2:-62}
    printf "\n${PURPLE}╭─ ${CYAN}${BOLD}%s${RESET}${PURPLE} $(printf '─%.0s' $(seq 1 $(( width - ${#title} - 4 ))))╮${RESET}\n" "$title"
}

print_box_close() {
    local width=${1:-62}
    printf "${PURPLE}╰$(printf '─%.0s' $(seq 1 $width))╯${RESET}\n"
}

print_step() {
    printf "${CYAN}${BOLD}◆ %s${RESET}\n" "$1"
}

print_success() {
    printf "  ${GREEN}${BOLD}✔ %s${RESET}\n" "$1"
}

print_error() {
    printf "  ${RED}${BOLD}✖ %s${RESET}\n" "$1"
}

print_warn() {
    printf "  ${YELLOW}${BOLD}⚠ %s${RESET}\n" "$1"
}

print_info() {
    printf "  ${CYAN}${BOLD}▶ %s${RESET}\n" "$1"
}

print_dim() {
    printf "  ${GRAY}%s${RESET}\n" "$1"
}

spinner() {
    local pid=$1
    local delay=0.08
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    tput civis 2>/dev/null
    while ps -p "$pid" > /dev/null 2>&1; do
        local char=${spinstr:$i:1}
        printf "\r  ${CYAN}${BOLD}%s${RESET}  ${GRAY}working...${RESET}" "$char"
        i=$(( (i + 1) % ${#spinstr} ))
        sleep $delay
    done
    tput cnorm 2>/dev/null
    printf "\r"
}

run_cmd() {
    local desc="$1"
    shift
    "$@" >/dev/null 2>&1 &
    local pid=$!
    spinner "$pid"
    wait "$pid"
    local rc=$?
    if [ $rc -eq 0 ]; then
        print_success "$desc"
    else
        print_error "$desc"
    fi
    return $rc
}

[ "$(id -u)" != "0" ] && { print_error "Must run as root"; exit 1; }

# ============================================================
# Banner
# ============================================================
clear
echo
printf "${PURPLE}${BOLD}"
cat <<'BANNER'
  ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ██╗ ██████╗
  ██║ ██╔╝██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗  ██║██╔════╝
  ██████╔╝ ███████║██╔██╗ ██║   ██║   ██║   ██║██╔██╗ ██║██║  ███╗
  ██╔═██╗ ██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╗██║██║   ██║
  ██║  ██╗██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚████║╚██████╔╝
  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝
BANNER
printf "${RESET}\n"
printf "  ${CYAN}${BOLD}INSTALLER${RESET}  ${GRAY}•  ${YELLOW}SSH Friendly${RESET}  ${GRAY}•  ${GREEN}Server Deploy${RESET}\n"
printf "  ${GRAY}v1.1.1${RESET}\n"
echo
print_box "  KANTONGKRESEK INSTALLER  "

# ============================================================
# SECTION 1: Remove Apache
# ============================================================
print_step "Removing Apache (switching to Nginx)..."

run_cmd "Stopped Apache" systemctl stop apache2 2>/dev/null || true
run_cmd "Disabled Apache" systemctl disable apache2 2>/dev/null || true
run_cmd "Removed Apache packages" apt purge -y apache2 apache2-bin apache2-data apache2-utils >/dev/null 2>&1 || true

print_box_close 62

# ============================================================
# SECTION 2: Enable PHP-FPM
# ============================================================
print_box "PHP-FPM Configuration" 62

print_info "Enabling PHP-FPM service"
run_cmd "PHP-FPM enabled" systemctl enable php8.4-fpm
run_cmd "PHP-FPM restarted" systemctl restart php8.4-fpm

print_info "Creating document root"
WEB_ROOT="/usr/src/.main/public"
run_cmd "Created $WEB_ROOT" bash -c "mkdir -p $WEB_ROOT && chown -R www-data:www-data $WEB_ROOT"

print_info "Writing placeholder index.php"
cat > $WEB_ROOT/index.php <<'INDEXEOF'
<?php
echo '<h1>KantongKresek</h1>';
echo '<p>Document root: /usr/src/.main/public</p>';
echo '<p>phpMyAdmin: <a href="/dbkantong">/dbkantong</a></p>';
INDEXEOF
run_cmd "Set index.php permissions" chown www-data:www-data $WEB_ROOT/index.php

print_box_close 62

# ============================================================
# SECTION 3: Nginx configuration
# ============================================================
print_box "Nginx Configuration" 62

print_info "Backing up old config"
[ -f /etc/nginx/sites-available/default ] && mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak

print_info "Writing Nginx config"
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /usr/src/.main/public;
    index index.php index.html index.htm;

    charset utf-8;
    client_max_body_size 1024M;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;

    # phpMyAdmin
    include snippets/phpmyadmin-dbkantong.conf;

    ##################################
    ## Rewrite
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

        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    ##################################
    ## Static Files
    ##################################
    location ~* \.(jpg|jpeg|png|gif|css|js|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        access_log off;
        log_not_found off;
    }

    ##################################
    ## Block Hidden Files (allow .well-known for ACME challenge)
    ##################################
    location ~ /\.(?!well-known).* {
        deny all;
    }

    ##################################
    ## Gzip
    ##################################
    gzip on;
    gzip_vary on;
    gzip_comp_level 5;
    gzip_min_length 1024;

    gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        application/xml
        application/xml+rss
        application/xhtml+xml
        image/svg+xml;
}
EOF

print_info "Testing Nginx configuration"
run_cmd "Nginx configuration valid" nginx -t

print_info "Enabling Nginx site"
run_cmd "Symlinked Nginx site" ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

print_info "Enabling Nginx service"
run_cmd "Nginx enabled" systemctl enable nginx

print_info "Restarting Nginx"
run_cmd "Nginx restarted" systemctl restart nginx

print_success "Nginx + PHP-FPM configured successfully"
print_box_close 62

# ============================================================
# SUMMARY
# ============================================================
echo
printf "${PURPLE}${BOLD}"
cat <<'BANNER'
  ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ██╗ ██████╗
  ██║ ██╔╝██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗  ██║██╔════╝
  ██████╔╝ ███████║██╔██╗ ██║   ██║   ██║   ██║██╔██╗ ██║██║  ███╗
  ██╔═██╗ ██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╗██║██║   ██║
  ██║  ██╗██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚████║╚██████╔╝
  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝
BANNER
printf "${RESET}\n"
printf "  ${GREEN}${BOLD}✓ INSTALLATION COMPLETE${RESET}\n"
echo
print_success "Nginx + PHP-FPM configured successfully."
print_dim "Document root: $WEB_ROOT"
print_dim "Next step: choose menu option 2 (Configurations)"
echo
