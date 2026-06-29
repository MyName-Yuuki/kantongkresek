#!/bin/bash

# ============================================================
# configurations_base_I.sh — Nginx + phpMyAdmin + Java + MariaDB
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
# Banner (sama dengan index.js)
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
# SECTION 1: phpMyAdmin
# ============================================================
print_step "Setting up phpMyAdmin at /dbkantong..."
print_info "Installing phpMyAdmin + dependencies"
export DEBIAN_FRONTEND=noninteractive

run_cmd "APT updated" apt update
run_cmd "phpMyAdmin + extensions installed" apt install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl php-xml unzip

run_cmd "Created phpMyAdmin tmp dir" mkdir -p /var/lib/phpmyadmin/tmp
run_cmd "Set ownership on phpMyAdmin data" chown -R www-data:www-data /var/lib/phpmyadmin

cat >/etc/nginx/snippets/phpmyadmin-dbkantong.conf <<'EOF'
# phpMyAdmin served from /dbkantong
location /dbkantong {
    alias /usr/share/phpmyadmin/;
    index index.php;

    location ~ ^/dbkantong/(.+.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt|svg|woff|woff2|ttf))$ {
        alias /usr/share/phpmyadmin/$1;
        access_log off;
        expires 30d;
    }

    location ~ ^/dbkantong/(.+)$ {
        alias /usr/share/phpmyadmin/$1;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }
}
EOF

print_info "Configuring Nginx for phpMyAdmin alias"
if ! grep -q "phpmyadmin-dbkantong.conf" /etc/nginx/sites-available/default; then
    sed -i '/server_name _;/a\    include snippets/phpmyadmin-dbkantong.conf;' /etc/nginx/sites-available/default
fi
run_cmd "Nginx configuration valid" nginx -t
run_cmd "PHP-FPM restarted" systemctl restart php8.4-fpm
run_cmd "Nginx restarted" systemctl restart nginx

print_box_close 62

# ============================================================
# SECTION 2: Java 11
# ============================================================
print_box "Java 11 Configuration" 62

JAVA_HOME="/home/tomcat9/java11"

if [ -x "$JAVA_HOME/bin/java" ]; then
    print_info "Java found at $JAVA_HOME"

    cat >/etc/profile.d/java11.sh <<EOF
export JAVA_HOME=$JAVA_HOME
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

    chmod +x /etc/profile.d/java11.sh

    update-alternatives --install /usr/bin/java java $JAVA_HOME/bin/java 2000
    [ -f "$JAVA_HOME/bin/javac" ] && update-alternatives --install /usr/bin/javac javac $JAVA_HOME/bin/javac 2000
    [ -f "$JAVA_HOME/bin/jar" ] && update-alternatives --install /usr/bin/jar jar $JAVA_HOME/bin/jar 2000
    [ -f "$JAVA_HOME/bin/keytool" ] && update-alternatives --install /usr/bin/keytool keytool $JAVA_HOME/bin/keytool 2000

    update-alternatives --set java $JAVA_HOME/bin/java
    [ -f "$JAVA_HOME/bin/javac" ] && update-alternatives --set javac $JAVA_HOME/bin/javac
    [ -f "$JAVA_HOME/bin/jar" ] && update-alternatives --set jar $JAVA_HOME/bin/jar
    [ -f "$JAVA_HOME/bin/keytool" ] && update-alternatives --set keytool $JAVA_HOME/bin/keytool

    print_success "Java 11 configured"
else
    print_warn "Java 11 not found at $JAVA_HOME"
    print_dim "Skipping Java configuration"
fi

print_box_close 62

# ============================================================
# SECTION 3: MariaDB
# ============================================================
print_box "MariaDB Configuration" 62

print_info "Configuring remote bind address"
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

print_info "Creating database user 'kantong'"
mysql <<SQL >/dev/null 2>&1
CREATE USER IF NOT EXISTS 'kantong'@'%' IDENTIFIED BY 'kresek';
GRANT ALL PRIVILEGES ON *.* TO 'kantong'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

run_cmd "MariaDB restarted" systemctl restart mariadb

print_success "MariaDB configured"
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
print_success "All services configured successfully."
echo
printf "  ${PURPLE}┌─────────────────────── ${GRAY}Summary ──────────────────────${PURPLE}┐${RESET}\n"
printf "  ${PURPLE}│${GRAY} phpMyAdmin   : ${CYAN}/dbkantong${RESET}                                    ${PURPLE}│${RESET}\n"
printf "  ${PURPLE}│${GRAY} MySQL User   : ${YELLOW}kantong${RESET}                                 ${PURPLE}│${RESET}\n"
printf "  ${PURPLE}│${GRAY} Password     : ${RED}kresek${RESET}                                 ${PURPLE}│${RESET}\n"
printf "  ${PURPLE}│${GRAY} JAVA_HOME    : ${CYAN}/home/tomcat9/java11${RESET}                   ${PURPLE}│${RESET}\n"
printf "  ${PURPLE}│${GRAY} Web root     : ${CYAN}/usr/src/.main/public${RESET}                   ${PURPLE}│${RESET}\n"
printf "  ${PURPLE}└──────────────────────────────────────────────────────${PURPLE}┘${RESET}\n"
echo
