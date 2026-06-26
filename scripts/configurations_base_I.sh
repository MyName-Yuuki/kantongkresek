#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RESET='\033[0m'
BOX='\033[1;44m'

print_box(){ echo -e "\n${BOX} $1 ${RESET}\n"; }
print_success(){ echo -e "${GREEN}[OK] $1${RESET}"; }
print_error(){ echo -e "${RED}[ERROR] $1${RESET}"; }

run_cmd(){
    bash -c "$1" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "$2"
    else
        print_error "$2"
        exit 1
    fi
}

[ "$(id -u)" != "0" ] && { echo "Run as root"; exit 1; }

print_box "Install phpMyAdmin"

export DEBIAN_FRONTEND=noninteractive

echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections

run_cmd "apt update" "APT updated"
run_cmd "apt install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl php-xml unzip" "phpMyAdmin installed"

print_box "Configure Nginx"

cat >/etc/nginx/snippets/phpmyadmin-dbkantong.conf <<'EOF'
location /dbkantong {
    alias /usr/share/phpmyadmin;
    index index.php;

    location ~ ^/dbkantong/(.+\.php)$ {
        alias /usr/share/phpmyadmin/$1;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /usr/share/phpmyadmin/$1;
        include fastcgi_params;
    }

    location ~* ^/dbkantong/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
        alias /usr/share/phpmyadmin/$1;
    }
}
EOF

if ! grep -q "phpmyadmin-dbkantong.conf" /etc/nginx/sites-available/default; then
    sed -i '/server_name _;/a\
    include snippets/phpmyadmin-dbkantong.conf;' /etc/nginx/sites-available/default
fi

run_cmd "nginx -t" "Nginx configuration valid"
run_cmd "systemctl restart php8.4-fpm" "PHP-FPM restarted"
run_cmd "systemctl restart nginx" "Nginx restarted"

print_box "Configure Java"

JAVA_HOME="/home/tomcat9/java11"

[ ! -x "$JAVA_HOME/bin/java" ] && { print_error "Java not found"; exit 1; }

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

print_success "Java configured"

print_box "Configure MariaDB"

sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

mysql <<SQL
CREATE USER IF NOT EXISTS 'kantong'@'%' IDENTIFIED BY 'kresek';
GRANT ALL PRIVILEGES ON *.* TO 'kantong'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

run_cmd "systemctl restart mariadb" "MariaDB restarted"

echo
echo "====================================="
echo " phpMyAdmin : http://SERVER-IP/dbkantong"
echo " MySQL User : kantong"
echo " Password   : kresek"
echo " JAVA_HOME  : /home/tomcat9/java11"
echo "====================================="
