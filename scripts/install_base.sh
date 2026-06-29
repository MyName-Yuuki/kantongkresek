#!/bin/bash

# ============================================================
# KantongKresek Install Base — UI matches the npm installer
# Palette: Purple #7C3AED, Cyan #06B6D4, Green #10B981,
#          Yellow #F59E0B, Red #EF4444, Gray #9CA3AF
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

# ---- Banner header (mirrors Node.js "KANTONGKRESEK INSTALLER" header) ----
banner_header() {
    local text="$1"
    local width=${2:-50}
    local pad_total=$(( width - ${#text} - 4 ))
    local pad_l=$(( pad_total / 2 ))
    local pad_r=$(( pad_total - pad_l ))
    printf "${PURPLE}╭$(printf '─%.0s' $(seq 1 $width))╮${RESET}\n"
    printf "${PURPLE}│${RESET}${BG_PURPLE}${WHITE}${BOLD}%*s%s%*s${RESET}${PURPLE}│${RESET}\n" "$pad_l" "" "$text" "$pad_r" ""
    printf "${PURPLE}╰$(printf '─%.0s' $(seq 1 $width))╯${RESET}\n"
}

# ---- Section box (rounded, like boxen) ----
print_box() {
    local title="$1"
    local width=${2:-62}
    printf "\n${PURPLE}╭─ ${CYAN}${BOLD}%s${RESET}${PURPLE} $(printf '─%.0s' $(seq 1 $(( width - ${#title} - 4 ))))╮${RESET}\n" "$title"
}

print_box_close() {
    local width=${1:-62}
    printf "${PURPLE}╰$(printf '─%.0s' $(seq 1 $width))╯${RESET}\n"
}

# ---- Step icon header (used inside print_box) ----
print_step() {
    printf "${CYAN}${BOLD}◆ %s${RESET}\n" "$1"
}

# ---- Status messages (mirrors ora spinner / chalk colors) ----
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

# ---- Spinner (replaces bash spinner with a better one) ----
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

# ---- Progress bar (better, blocks instead of garbage chars) ----
progress_bar() {
    local i=0
    local total=24
    printf "  ${GRAY}"
    while [ $i -le $total ]; do
        local pct=$(( i * 100 / total ))
        printf "\r  ${PURPLE}["
        for ((j=0; j<total; j++)); do
            if [ $j -lt $i ]; then printf "${GREEN}█${PURPLE}"; else printf "${GRAY}░${PURPLE}"; fi
        done
        printf "${PURPLE}]${RESET} ${WHITE}${BOLD}%3d%%${RESET}" "$pct"
        sleep 0.04
        ((i++))
    done
    printf "\n"
}

# ---- run_cmd with spinner + status ----
run_cmd() {
    local desc="$1"
    shift
    "$@" >/dev/null 2>&1 &
    local pid=$!
    spinner "$pid
"
    wait "$pid
"
    local rc=$?
    if [ $rc -eq 0 ]; then
        print_success "$desc"
    else
        print_error "$desc"
        return 1
    fi
}

# ============================================================
# ROOT CHECK
# ============================================================
if [ "$(id -u)" -ne 0 ]; then
    print_error "Script ini harus dijalankan sebagai root"
    exit 1
fi

# ============================================================
# BANNER
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

# ============================================================
# MAIN
# ============================================================
banner_header "  KANTONGKRESEK INSTALLER  "

print_step "Preparing installation..."
progress_bar

# Step 1: Display current i386 packages
print_box "Checking installed i386 packages" 62
print_dim "$(dpkg -l | grep i386 | head -5)"
print_dim "..."
print_box_close 62

# Step 2: Add WTF Bookworm source
print_box "Adding WTF repository for additional i386 support" 62
print_info "WTF Bookworm sources"
run_cmd "Downloaded WTF source list" wget -q http://www.mirbsd.org/~tg/Debs/sources.txt/wtf-bookworm.sources -O wtf-bookworm.sources
run_cmd "Moved source list" bash -c "mkdir -p /etc/apt/sources.list.d && mv wtf-bookworm.sources /etc/apt/sources.list.d/"
run_cmd "System updated" apt update
print_box_close 62

# Step 3: Install extra required libraries
print_box "Installing required packages for build and i386" 62
print_info "Core i386 build deps"
run_cmd "libssl-dev libstdc++6:i386 libxml2:i386 libpcre3-dev libpcre3 libc6-dev-i386-cross" \
    bash -c "apt-get install -y libssl-dev libstdc++6:i386 libxml2:i386 libpcre3-dev libpcre3 libc6-dev-i386-cross"
print_info "Base runtime libs"
run_cmd "libncurses5:i386 libstdc++6:i386 libc6:i386 nginx expect whiptail" \
    bash -c "apt install -y libncurses5:i386 libstdc++6:i386 libc6:i386 nginx expect whiptail"
print_box_close 62

# Step 4: Add Sury PHP 8.4 repository
print_box "Adding PHP 8.4 repository (Sury)" 62
print_info "Sury GPG key"
run_cmd "Added Sury GPG key" bash -c "wget -qO - https://packages.sury.org/php/apt.gpg | tee /etc/apt/trusted.gpg.d/php.gpg > /dev/null"
print_info "Sury APT source"
run_cmd "Added Sury repo" bash -c "echo 'deb https://packages.sury.org/php/ \$(lsb_release -sc) main' | tee /etc/apt/sources.list.d/php.list"
run_cmd "Repository list updated" apt update -y
print_box_close 62

# Step 5: Package lists
required_packages1=(mc screen htop mono-complete exim4 p7zip-full libpcap-dev curl wget ipset net-tools tzdata ntpdate mariadb-server mariadb-client)
required_packages2=(make gcc g++ libssl-dev:i386 libssl-dev libcrypto++-dev libpcre3 libpcre3-dev libpcre3:i386 libpcre3-dev:i386 libtesseract-dev libx11-dev:i386 libx11-dev gcc-multilib libc6-dev:i386 build-essential gcc-multilib g++-multilib libtemplate-plugin-xml-perl libxml2-dev libxml2-dev:i386 libxml2:i386 libstdc++6:i386 libmariadb-dev-compat:i386 libmariadb-dev:i386)
required_packages3=(make gcc g++ libssl-dev libcrypto++-dev libpcre3 libpcre3-dev libtesseract-dev libx11-dev gcc-multilib libc6-dev build-essential g++-multilib libtemplate-plugin-xml-perl libxml2-dev libstdc++6 libmariadb-dev-compat libmariadb-dev cmake)
required_packages4=(php8.4 php8.4-cli php8.4-fpm php8.4-json php8.4-pdo php8.4-zip php8.4-gd php8.4-mbstring php8.4-curl php8.4-xml php-pear php8.4-bcmath php8.4-cgi php8.4-mysqli php8.4-common php-phpseclib php8.4-mysql)

print_box "Installing required packages" 62
print_info "Group 1: System utilities & DB"
for pkg in "${required_packages1[@]}"; do
    run_cmd "Installed $pkg" bash -c "apt -y install $pkg"
done
print_info "Group 2: Build & i386 toolchain"
for pkg in "${required_packages2[@]}"; do
    run_cmd "Installed $pkg" bash -c "apt -y install $pkg"
done
print_info "Group 3: Native build tools"
for pkg in "${required_packages3[@]}"; do
    run_cmd "Installed $pkg" bash -c "apt -y install $pkg"
done
print_info "Group 4: PHP 8.4 packages"
for pkg in "${required_packages4[@]}"; do
    run_cmd "Installed PHP: $pkg" bash -c "apt -y install $pkg"
done
print_box_close 62

# Step 6: Enable services
print_box "Enabling services" 62
run_cmd "Enabled PHP-FPM" systemctl enable php8.4-fpm
run_cmd "Restarted PHP-FPM" systemctl restart php8.4-fpm
run_cmd "Enabled Nginx" systemctl enable nginx
run_cmd "Restarted Nginx" systemctl restart nginx
print_box_close 62

# Done
echo
banner_header "  ✓ INSTALLATION COMPLETE  "
echo
print_success "All packages installed successfully."
print_dim "Document root: /usr/src/.main/public"
print_dim "Next step: choose menu option 2 (Configurations)"
echo