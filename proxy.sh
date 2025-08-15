#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'

# Clear screen
clear

# Menu
echo
echo -e "${MAGENTA}*********************************************${NC}"
echo -e "${BLUE}     🔧 ${WHITE}Tatkalworld Proxy Manager${NC}"
echo -e "${MAGENTA}*********************************************${NC}"
echo
echo -e "  ${CYAN}01${NC}) ${GREEN}Install Superfast Proxy IP${NC}"
echo -e "  ${CYAN}02${NC}) ${RED}Uninstall Proxy${NC}"
echo

# Get option: from argument or prompt
if [ -n "${1:-}" ]; then
    OPTION="$1"
    echo -e "${WHITE}📌 Auto option selected: $OPTION${NC}"
else
    echo -e "${WHITE}📌 Enter option (01 or 02): ${NC}\c"
    read OPTION
fi

# -------------------------------
# OPTION 1: INSTALL PROXY
# -------------------------------
if [[ "$OPTION" == "01" || "$OPTION" == "1" ]]; then

    clear
    echo -e "${MAGENTA}*********************************************${NC}"
    echo -e "${BLUE}     👨‍💻 ${WHITE}Welcome to Superfast Proxy Installer${NC}"
    echo -e "${GREEN}        Admin | Akash${NC}"
    echo -e "${YELLOW}   🔐 Scripts Designed by ${CYAN}Tatkalworld.com${NC}"
    echo -e "${MAGENTA}*********************************************${NC}"
    echo

    sleep 2

    echo -e "${GREEN}🚀 Installing Superfast Squid Proxy...${NC}"

    # Update & install
    apt-get update -qq > /dev/null 2>&1 || echo "Update warning..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y squid apache2-utils curl > /dev/null 2>&1

    SQUID_CONF="/etc/squid/squid.conf"
    SQUID_USER="proxy"

    # Generate credentials
    USERNAME="user$(tr -cd 'a-z0-9' < /dev/urandom | head -c 5)"
    PASSWORD=$(tr -cd 'A-Za-z0-9' < /dev/urandom | head -c 12)

    # Get public IP
    PUBLIC_IP=$(curl -s https://ipinfo.io/ip || curl -s ifconfig.me || echo "Failed")

    if [[ "$PUBLIC_IP" == "Failed" ]]; then
        echo -e "${RED}❌ Unable to detect public IP. Check internet.${NC}"
        echo
        echo -e "${YELLOW}→ Type 'exit' to close terminal${NC}"
        exit 1
    fi

    # Backup and configure
    mv "$SQUID_CONF" "$SQUID_CONF.bak" 2>/dev/null || true

    cat > "$SQUID_CONF" <<'EOF'
http_port 3128
cache deny all
access_log none
cache_store_log none
cache_log /dev/null

acl localhost src 127.0.0.1/32 ::1
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 21
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl SSL_ports port 443
acl CONNECT method CONNECT

http_access allow manager localhost
http_access deny manager
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost

auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid Proxy Authentication
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all

forwarded_for off
request_header_access All deny all
request_header_access Accept allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Authorization allow all
request_header_access Cache-Control allow all
request_header_access Connection allow all
request_header_access Content-Language allow all
request_header_access Content-Type allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Mime-Version allow all
request_header_access Pragma allow all
request_header_access Proxy-Authorization allow all
request_header_access User-Agent allow all
EOF

    # Create password file
    htpasswd -b -c "/etc/squid/passwd" "$USERNAME" "$PASSWORD" > /dev/null 2>&1
    chown "$SQUID_USER:" "/etc/squid/passwd" 2>/dev/null || true
    chmod 600 /etc/squid/passwd

    # Restart Squid
    systemctl stop squid > /dev/null 2>&1 || true
    systemctl enable squid > /dev/null 2>&1 || true
    systemctl restart squid > /dev/null 2>&1 || true
    sleep 3

    if ! systemctl is-active --quiet squid; then
        echo -e "${RED}❌ Squid failed to start. Check: journalctl -u squid${NC}"
        echo
        echo -e "${YELLOW}→ Type 'exit' to close terminal${NC}"
        exit 1
    fi

    # Proxy line
    PROXY_LINE="${PUBLIC_IP}:3128:${USERNAME}:${PASSWORD}"

    # Show proxy
    echo
    echo -e "${GREEN}🔐 PROXY CREATED SUCCESSFULLY!${NC}"
    echo
    echo -e "${WHITE}📋 Copy Your Proxy (IP:PORT:USERNAME:PASSWORD):${NC}"
    echo
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│  ${PROXY_LINE}  │${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo

    # Test on IRCTC using your updated code
    echo -e "${YELLOW}🔍 Testing on irctc.co.in...${NC}"
    PROXY_URL="http://$USERNAME:$PASSWORD@$PUBLIC_IP:3128"

    RESPONSE=$(curl -s --proxy "$PROXY_URL" -m 20 -L https://www.irctc.co.in/nget/train-search)

    if echo "$RESPONSE" | grep -q "JavaScript"; then
        echo -e "${YELLOW}⚠ IRCTC loaded, but requires browser with JS${NC}"
    elif echo "$RESPONSE" | grep -q "blocked\|access denied\|captcha"; then
        echo -e "${RED}❌ Your IP is blocked by IRCTC${NC}"
    else
        echo -e "${GREEN}✔ Proxy works — response received${NC}"
    fi

    echo
    echo -e "${MAGENTA}👋 Thank you for using Tatkalworld.com!${NC}"
    echo
    echo -e "${WHITE}→ Type '${CYAN}exit${WHITE}' and press Enter to close terminal${NC}"
    echo

# -------------------------------
# OPTION 2: UNINSTALL PROXY
# -------------------------------
elif [[ "$OPTION" == "02" || "$OPTION" == "2" ]]; then
    echo
    echo -e "${RED}🗑️ Uninstalling Squid Proxy...${NC}"

    systemctl stop squid > /dev/null 2>&1 || true
    systemctl disable squid > /dev/null 2>&1 || true
    apt-get purge -y squid > /dev/null 2>&1 || true
    rm -rf /etc/squid /etc/squid3
    userdel squid proxy 2>/dev/null || true

    echo -e "${GREEN}✅ Squid Proxy has been fully removed!${NC}"
    echo
    echo -e "${WHITE}→ Type '${CYAN}exit${WHITE}' to close terminal${NC}"
    echo

else
    echo
    echo -e "${RED}❌ Invalid option. Please run again.${NC}"
    echo -e "${WHITE}→ Use '01' to install or '02' to uninstall${NC}"
    echo -e "${WHITE}→ Example: ${CYAN}sudo bash proxy.sh 01${NC}"
    echo -e "${WHITE}→ Type '${CYAN}exit${WHITE}' to close terminal${NC}"
    echo
fi
