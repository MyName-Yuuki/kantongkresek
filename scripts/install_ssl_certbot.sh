#!/bin/bash

# ============================================================
# install_ssl_certbot.sh — Let's Encrypt SSL
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

print_prompt() {
    printf "  ${PURPLE}${BOLD}?${RESET} ${WHITE}${BOLD}%s${RESET} ${GRAY}%s${RESET}" "$1" "$2"
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
# STEP 1: Collect inputs
# Arguments (optional, passed by npm installer):
#   $1 = domain utama
#   $2 = email SSL
#   $3 = domain tambahan (space-separated, opsional)
# Falls back to interactive prompts when run manually via `bash install_ssl_certbot.sh`.
# ============================================================
DOMAIN="${1:-}"
EMAIL="${2:-}"
EXTRA_DOMAINS="${3:-}"

DEFAULT_DOMAIN=$(hostname -f 2>/dev/null)
if [ -z "$DEFAULT_DOMAIN" ] || [ "$DEFAULT_DOMAIN" = "localhost" ]; then
    DEFAULT_DOMAIN=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

print_step "Let's Encrypt SSL Setup"
print_info "Domain harus sudah mengarah (DNS A record) ke IP server ini."
echo

if [ -z "$DOMAIN" ]; then
    print_prompt "Domain utama" "[contoh: example.com]: "
    read DOMAIN
    DOMAIN=$(echo "$DOMAIN" | tr -d ' ')
    [ -z "$DOMAIN" ] && { print_error "Domain tidak boleh kosong"; exit 1; }
fi

if [ -z "$EMAIL" ]; then
    print_prompt "Email SSL" "[contoh: admin@example.com]: "
    read EMAIL
    EMAIL=$(echo "$EMAIL" | tr -d ' ')
    [ -z "$EMAIL" ] && { print_error "Email tidak boleh kosong"; exit 1; }
fi

if [ -z "$EXTRA_DOMAINS" ]; then
    print_prompt "Domain tambahan" "(opsional, pisahkan dengan spasi): "
    read EXTRA
    EXTRA_DOMAINS=$(echo "$EXTRA" | tr -d ' ')
fi

DOMAIN_ARGS="-d $DOMAIN"
for d in $EXTRA_DOMAINS; do
    [ -n "$d" ] && DOMAIN_ARGS="$DOMAIN_ARGS -d $d"
done

print_warn "Akan request cert untuk: $DOMAIN $EXTRA_DOMAINS"

if [ -n "${1:-}" ]; then
    # Args provided (npm flow): skip confirmation prompt
    print_info "Args dari npm installer — skip konfirmasi"
else
    print_prompt "Lanjutkan?" "(y/N): "
    read CONFIRM
    [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && { print_warn "Dibatalkan"; exit 0; }
fi

print_box_close 62

# ============================================================
# STEP 2: Install Certbot
# ============================================================
print_box "1/4 — Install Certbot" 62

print_info "Removing old certbot from apt"
apt-get remove -y certbot >/dev/null 2>&1 || true

run_cmd "APT updated" apt update
run_cmd "snapd installed" apt install -y snapd

print_info "Starting snapd service"
systemctl enable snapd.service >/dev/null 2>&1 || true
systemctl start snapd.service >/dev/null 2>&1 || true

print_info "Waiting for snap socket"
for i in 1 2 3 4 5; do
    snap --version >/dev/null 2>&1 && break
    sleep 2
done

run_cmd "snap core installed" bash -c "snap install core && snap refresh core"
run_cmd "certbot installed" bash -c "snap install --classic certbot"

ln -sf /snap/bin/certbot /usr/local/bin/certbot >/dev/null 2>&1 || true
print_box_close 62

# ============================================================
# STEP 3: Request SSL Certificate
# ============================================================
print_box "2/4 — Request SSL Certificate" 62

print_info "Mode: nginx (auto-modify vhost)"
run_cmd "SSL certificate installed" bash -c "certbot --nginx $DOMAIN_ARGS --non-interactive --agree-tos -m $EMAIL"

print_box_close 62

# ============================================================
# STEP 4: Verify Renewal
# ============================================================
print_box "3/4 — Test Renewal (dry run)" 62

run_cmd "Auto-renewal test passed" certbot renew --dry-run
print_box_close 62

# ============================================================
# STEP 5: Auto-renew Timer
# ============================================================
print_box "4/4 — Systemd Auto-Renew Timer" 62

print_info "Enabling snap.certbot.renew.timer"
if [ -f /etc/systemd/system/snap.certbot.renew.timer ]; then
    systemctl enable snap.certbot.renew.timer
    systemctl start snap.certbot.renew.timer
    print_success "Enabled snap.certbot.renew.timer"
else
    print_warn "systemd timer tidak ditemukan, fallback ke cron"
    CRON_LINE="0 3 * * * /snap/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'"
    (crontab -l 2>/dev/null | grep -v certbot; echo "$CRON_LINE") | crontab -
    print_success "Cron job installed (daily 03:00)"
fi

systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx
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
  ╚═╝  ��═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝
BANNER
printf "${RESET}\n"
printf "  ${GREEN}${BOLD}✓ SSL INSTALLATION COMPLETE${RESET}\n"
echo
print_success "SSL certificate installed."
echo
printf "  ${PURPLE}┌─────────────────────── ${GRAY}Summary ──────────────────────${PURPLE}┐${RESET}\n"
printf "  ${PURPLE}│${GRAY} HTTPS       : ${CYAN}https://$DOMAIN${RESET}\n"
for d in $EXTRA_DOMAINS; do
    [ -n "$d" ] && printf "  ${PURPLE}│${GRAY}               ${CYAN}https://$d${RESET}\n"
done
printf "  ${PURPLE}│${GRAY} phpMyAdmin  : ${CYAN}https://$DOMAIN/dbkantong${RESET}\n"
printf "  ${PURPLE}│${GRAY} Auto-renew  : ${GREEN}aktif${GRAY} (systemd timer atau cron)${RESET}\n"
printf "  ${PURPLE}└──────────────────────────────────────────────────────${PURPLE}┘${RESET}\n"
echo