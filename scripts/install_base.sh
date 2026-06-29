#!/bin/bash

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'
BOX='\033[1;44m'

# Spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while ps a | awk '{print $1}' | grep -q "$pid"; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    wait $pid
    return $?
}

# Message and UI functions
print_box() { echo -e "\n${BOX} $1 ${RESET}\n"; }
print_info() { echo -e "${BLUE}? $1${RESET}"; }
print_success() { echo -e "${GREEN}[?] $1${RESET}"; }
print_error() { echo -e "${RED}[?] $1${RESET}"; }

progress_bar() {
    local i=0; local total=20
    while [ $i -le $total ]; do
        sleep 0.05
        printf "["
        for ((j=0; j<=i; j++)); do printf "�"; done
        for ((j=i; j<total; j++)); do printf " "; done
        printf "] %d%%\r" $(( i * 100 / total ))
        ((i++))
    done
    echo ""
}

run_cmd() {
    eval "$1" &> /dev/null &
    spinner
    if [ $? -eq 0 ]; then print_success "$2"
    else print_error "$2"; fi
}

# Check root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

print_box "?? STARTING INSTALLATION"
progress_bar

# Step 1: Display current i386 packages
print_box "?? Checking installed i386 packages"
dpkg -l | grep i386

# Step 2: Add WTF Bookworm source
print_box "?? Adding WTF repository for additional i386 support"
run_cmd "wget http://www.mirbsd.org/~tg/Debs/sources.txt/wtf-bookworm.sources" "Downloaded WTF source list"
run_cmd "mkdir -p /etc/apt/sources.list.d && mv wtf-bookworm.sources /etc/apt/sources.list.d/" "Moved source list"
run_cmd "apt update" "System updated"

# Step 3: Install extra required libraries
print_box "?? Installing required packages for build and i386"
run_cmd "apt-get install -y libssl-dev libstdc++6:i386 libxml2:i386 libpcre3-dev libpcre3 libc6-dev-i386-cross" "Core i386 build deps installed"
run_cmd "apt install -y libncurses5:i386 libstdc++6:i386 libc6:i386 nginx expect whiptail" "Base runtime libs installed"

# Step 4: Add Sury PHP 8.4 repository
print_box "?? Adding PHP 8.4 repository (Sury)"
run_cmd "wget -qO - https://packages.sury.org/php/apt.gpg | tee /etc/apt/trusted.gpg.d/php.gpg > /dev/null" "Added Sury GPG key"
run_cmd "echo 'deb https://packages.sury.org/php/ $(lsb_release -sc) main' | tee /etc/apt/sources.list.d/php.list" "Added Sury repo"
run_cmd "apt update -y" "Repository list updated"

# Step 5: Package lists
required_packages1=(mc screen htop mono-complete exim4 p7zip-full libpcap-dev curl wget ipset net-tools tzdata ntpdate mariadb-server mariadb-client)
required_packages2=(make gcc g++ libssl-dev:i386 libssl-dev libcrypto++-dev libpcre3 libpcre3-dev libpcre3:i386 libpcre3-dev:i386 libtesseract-dev libx11-dev:i386 libx11-dev gcc-multilib libc6-dev:i386 build-essential gcc-multilib g++-multilib libtemplate-plugin-xml-perl libxml2-dev libxml2-dev:i386 libxml2:i386 libstdc++6:i386 libmariadb-dev-compat:i386 libmariadb-dev:i386)
required_packages3=(make gcc g++ libssl-dev libcrypto++-dev libpcre3 libpcre3-dev libtesseract-dev libx11-dev gcc-multilib libc6-dev build-essential g++-multilib libtemplate-plugin-xml-perl libxml2-dev libstdc++6 libmariadb-dev-compat libmariadb-dev cmake)
required_packages4=(php8.4 php8.4-cli php8.4-fpm php8.4-json php8.4-pdo php8.4-zip php8.4-gd php8.4-mbstring php8.4-curl php8.4-xml php-pear php8.4-bcmath php8.4-cgi php8.4-mysqli php8.4-common php-phpseclib php8.4-mysql)

print_box "?? Installing required packages"

for pkg in "${required_packages1[@]}"; do run_cmd "apt -y install $pkg" "Installed $pkg"; done
for pkg in "${required_packages2[@]}"; do run_cmd "apt -y install $pkg" "Installed $pkg"; done
for pkg in "${required_packages3[@]}"; do run_cmd "apt -y install $pkg" "Installed $pkg"; done
for pkg in "${required_packages4[@]}"; do run_cmd "apt -y install $pkg" "Installed PHP package: $pkg"; done

# Restart Nginx + PHP-FPM (Apache tidak dipakai, pakai Nginx dari konfigurasi)
run_cmd "systemctl enable php8.4-fpm" "Enabled PHP-FPM"
run_cmd "systemctl restart php8.4-fpm" "Restarted PHP-FPM"
run_cmd "systemctl enable nginx" "Enabled Nginx"
run_cmd "systemctl restart nginx" "Restarted Nginx"

print_box "? INSTALLATION COMPLETE"
