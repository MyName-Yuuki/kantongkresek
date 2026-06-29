#!/bin/bash

# ============================================================
# database.sh — Database provisioning
# UI palette matches index.js (npm installer)
# Arguments: <db_file>   — e.g. "ykpw144-155.sql" or "ykpw16*-17*.sql"
# ============================================================

PURPLE='\033[38;2;124;58;237m'
CYAN='\033[38;2;6;182;212m'
GREEN='\033[38;2;16;185;129m'
YELLOW='\033[38;2;245;158;11m'
RED='\033[38;2;239;68;68m'
GRAY='\033[38;2;156;163;175m'
WHITE='\033[38;2;229;231;235m'
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
# Argument validation
# ============================================================
DB_FILE="${1:-}"
if [ -z "$DB_FILE" ]; then
    print_error "No database selection provided."
    print_info "Expected: database.sh <db_file>"
    print_dim "e.g. database.sh ykpw144-155.sql"
    exit 1
fi

SQL_DIR="/opt/Github/KantongKresek/databases_sql"
SQL_PATH="$SQL_DIR/$DB_FILE"

# Handle wildcard globbing
if [[ "$DB_FILE" == *"*"* ]]; then
    SQL_PATH=$(ls "$SQL_DIR"/$DB_FILE 2>/dev/null | head -1)
fi

if [ ! -f "$SQL_PATH" ]; then
    print_error "Database file not found: $SQL_PATH"
    print_info "Available files in $SQL_DIR:"
    ls -1 "$SQL_DIR"/*.sql 2>/dev/null | xargs -I{} basename {}
    exit 1
fi

print_step "Installing Database"
print_info "File: $SQL_PATH ($(du -h "$SQL_PATH" | cut -f1))"
print_info "Size: $(wc -l < "$SQL_PATH") lines"
echo

# ============================================================
# Step 1: Stop MySQL if running (clean start)
# ============================================================
print_box "1/4 — Prepare MySQL" 62

print_info "Stopping MariaDB service (safe)"
systemctl stop mariadb.service 2>/dev/null || systemctl stop mysql.service 2>/dev/null
print_success "MariaDB stopped"

# Drop existing DBs to ensure clean install
print_info "Dropping existing databases to ensure clean install"
mysql -u root -e "DROP DATABASE IF EXISTS ykpw;" 2>/dev/null
mysql -u root -e "DROP DATABASE IF EXISTS pw_new;" 2>/dev/null
print_success "Old databases cleared"
print_box_close 62

# ============================================================
# Step 2: Start MySQL & wait for ready
# ============================================================
print_box "2/4 — Start MySQL" 62

systemctl start mariadb.service 2>/dev/null || systemctl start mysql.service 2>/dev/null
print_info "Waiting for MySQL to be ready..."
for i in $(seq 1 15); do
    mysql -u root -e "SELECT 1" >/dev/null 2>&1 && { print_success "MySQL is ready"; break; }
    sleep 1
done
print_box_close 62

# ============================================================
# Step 3: Import the database
# ============================================================
print_box "3/4 — Import Database" 62

print_info "Importing database..."
mysql -u root < "$SQL_PATH" 2>&1
IMPORT_RC=$?

if [ $IMPORT_RC -eq 0 ]; then
    print_success "Database imported successfully"
else
    print_error "Database import failed (exit code: $IMPORT_RC)"
    print_warn "Check mysql error log: /var/log/mysql/error.log"
    print_box_close 62
    exit 1
fi
print_box_close 62

# ============================================================
# Step 4: Verify installation
# ============================================================
print_box "4/4 — Verify Installation" 62

print_info "Creating mysql credentials file..."
mkdir -p ~/.ssh/.mysql_backup
cat > /root/.my.cnf <<'MYCNF'
[client]
user=kantor
password=kresek
MYCNF
chmod 600 /root/.my.cnf
print_success "Credentials configured"

print_info "Detecting installed database..."
INSTALLED_DB=$(mysql -u root -e "SHOW DATABASES LIKE '%pw_new%';" 2>/dev/null | grep -v "pw_new")
PW_NEW_EXISTS=$(mysql -u root -e "SHOW DATABASES LIKE 'pw_new';" 2>/dev/null | wc -l)
YKPW_EXISTS=$(mysql -u root -e "SHOW DATABASES LIKE 'ykpw';" 2>/dev/null | wc -l)

if [ "$PW_NEW_EXISTS" -gt 0 ]; then
    TABLES=$(mysql -u root pw_new -e "SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='pw_new';" 2>/dev/null | tail -1)
    print_success "pw_new installed — $TABLES tables"
elif [ "$YKPW_EXISTS" -gt 0 ]; then
    TABLES=$(mysql -u root ykpw -e "SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='ykpw';" 2>/dev/null | tail -1)
    print_success "ykpw installed — $TABLES tables"
else
    print_error "No database detected after import"
    print_box_close 62
    exit 1
fi
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
printf "  ${GREEN}${BOLD}✓ DATABASE INSTALLATION COMPLETE${RESET}\n"
echo
print_success "Database installed from: $SQL_PATH"
echo
printf "  ${PURPLE}┌─────────────────────── ${GRAY}Summary ──────────────────────${PURPLE}┐${RESET}\n"
printf "  ${PURPLE}│${GRAY} File          : ${CYAN}$DB_FILE${RESET}\n"
printf "  ${PURPLE}│${GRAY} MySQL User    : ${CYAN}kantor${RESET}\n"
printf "  ${PURPLE}│${GRAY} Config        : ${CYAN}~/.my.cnf${RESET}\n"
printf "  ${PURPLE}│${GRAY} Credential    : ${CYAN}kresek${RESET}\n"
printf "  ${PURPLE}└──────────────────────────────────────────────────────${PURPLE}┘${RESET}\n"
echo
