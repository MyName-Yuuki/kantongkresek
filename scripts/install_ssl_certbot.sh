#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RESET='\033[0m'
BOX='\033[1;44m'

print_box(){ echo -e "\n${BOX} $1 ${RESET}\n"; }
print_success(){ echo -e "${GREEN}[OK] $1${RESET}"; }
print_error(){ echo -e "${RED}[ERROR] $1${RESET}"; }
print_warn(){ echo -e "${YELLOW}[WARN] $1${RESET}"; }
print_info(){ echo -e "${BLUE}? $1${RESET}"; }

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

# ---- INPUT ----
DEFAULT_DOMAIN=$(hostname -f 2>/dev/null)
if [ -z "$DEFAULT_DOMAIN" ] || [ "$DEFAULT_DOMAIN" = "localhost" ]; then
    DEFAULT_DOMAIN=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

print_box "Install Let's Encrypt SSL (Certbot)"
print_info "Domain harus sudah mengarah (DNS A record) ke IP server ini."
echo

read -p "Domain utama [contoh: example.com]: " DOMAIN
DOMAIN=$(echo "$DOMAIN" | tr -d ' ')
[ -z "$DOMAIN" ] && { print_error "Domain tidak boleh kosong"; exit 1; }

read -p "Email untuk notifikasi SSL [contoh: admin@example.com]: " EMAIL
EMAIL=$(echo "$EMAIL" | tr -d ' ')
[ -z "$EMAIL" ] && { print_error "Email tidak boleh kosong"; exit 1; }

read -p "Domain tambahan (opsional, pisahkan dengan spasi): " EXTRA
EXTRA_DOMAINS=$(echo "$EXTRA" | tr -d ' ')

DOMAIN_ARGS="-d $DOMAIN"
for d in $EXTRA_DOMAINS; do
    [ -n "$d" ] && DOMAIN_ARGS="$DOMAIN_ARGS -d $d"
done

print_warn "Akan request cert untuk: $DOMAIN $EXTRA_DOMAINS"
read -p "Lanjutkan? (y/N): " CONFIRM
[ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && { print_warn "Dibatalkan"; exit 0; }

# ---- INSTALL CERTBOT ----
print_box "1/4 - Install Certbot"
export DEBIAN_FRONTEND=noninteractive

# Hapus certbot apt (biasanya versi lama) sebelum install via snap
apt-get remove -y certbot >/dev/null 2>&1 || true

run_cmd "apt update" "APT updated"
run_cmd "apt install -y snapd" "snapd installed"

# Enable snapd socket
systemctl enable snapd.service >/dev/null 2>&1 || true
systemctl start snapd.service >/dev/null 2>&1 || true

# Wait until snap is alive
for i in 1 2 3 4 5; do
    snap --version >/dev/null 2>&1 && break
    sleep 2
done

run_cmd "snap install core; snap refresh core" "snap core installed"
run_cmd "snap install --classic certbot" "certbot installed"

# Symlink for convenience
ln -sf /snap/bin/certbot /usr/local/bin/certbot >/dev/null 2>&1 || true

# ---- REQUEST CERT ----
print_box "2/4 - Request SSL Certificate"
print_info "Mode: nginx (otomatis modifikasi vhost)"
run_cmd "certbot --nginx $DOMAIN_ARGS --non-interactive --agree-tos -m $EMAIL" "SSL certificate installed"

# ---- VERIFY RENEWAL ----
print_box "3/4 - Test Renewal (dry run)"
run_cmd "certbot renew --dry-run" "Auto-renewal test passed"

# ---- SYSTEMD TIMER ----
print_box "4/4 - Systemd Auto-Renew Timer"

# Certbot snap ships its own systemd timer; ensure it's enabled.
if [ -f /etc/systemd/system/snap.certbot.renew.timer ]; then
    systemctl enable snap.certbot.renew.timer
    systemctl start snap.certbot.renew.timer
    print_success "Enabled snap.certbot.renew.timer"
else
    # Fallback: install cron job
    print_warn "systemd timer tidak ditemukan, menggunakan cron fallback"
    CRON_LINE="0 3 * * * /snap/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'"
    (crontab -l 2>/dev/null | grep -v certbot; echo "$CRON_LINE") | crontab -
    print_success "Cron job installed (daily 03:00)"
fi

systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx

echo
echo "====================================="
echo " HTTPS      : https://$DOMAIN"
[ -n "$EXTRA_DOMAINS" ] && for d in $EXTRA_DOMAINS; do echo "               https://$d"; done
echo " phpMyAdmin : https://$DOMAIN/dbkantong"
echo " Auto-renew : aktif (systemd timer atau cron)"
echo "====================================="