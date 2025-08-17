#!/bin/bash
# Tatkalworld Proxy Manager – includes auto firewall rule (2024-05-29)

# -------------------- colours --------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
WHITE='\033[0;37m'; NC='\033[0m'

clear
echo
echo -e "${MAGENTA}*********************************************${NC}"
echo -e "${BLUE}     🔧 ${WHITE}Tatkalworld Proxy Manager${NC}"
echo -e "${MAGENTA}*********************************************${NC}"
echo
echo -e "  ${CYAN}01${NC}) ${GREEN}Install Superfast Proxy IP${NC}"
echo -e "  ${CYAN}02${NC}) ${RED}Uninstall Proxy${NC}"
echo

# -------------------- option --------------------
if [ -n "${1:-}" ]; then OPTION="$1"
else read -rp $'\e[37m📌 Enter option (01 or 02): \e[0m' OPTION; fi
[[ "$OPTION" =~ ^0?1$ ]] && OPTION=01
[[ "$OPTION" =~ ^0?2$ ]] && OPTION=02

# -------------------- fast-mode flags --------------------
if [[ -n "${FAST:-}" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    APT_OPTS="-yqq --no-install-recommends -o Dpkg::Options::=--force-confold"
else
    APT_OPTS="-y"
fi

# -------------------- 01: INSTALL --------------------
if [[ "$OPTION" == "01" ]]; then
    clear
    echo -e "${MAGENTA}*********************************************${NC}"
    echo -e "${BLUE}     👨‍💻 ${WHITE}Welcome to Superfast Proxy Installer${NC}"
    echo -e "${GREEN}        Admin | Akash${NC}"
    echo -e "${YELLOW}   🔐 Scripts Designed by ${CYAN}Tatkalworld.com${NC}"
    echo -e "${MAGENTA}*********************************************${NC}"
    echo; sleep 2

    echo -e "${GREEN}🚀 Installing Superfast Squid Proxy...${NC}"

    # update & install
    apt-get update $APT_OPTS
    apt-get install $APT_OPTS squid apache2-utils curl

    SQUID_CONF="/etc/squid/squid.conf"
    SQUID_USER="proxy"

    # credentials
    USERNAME="user$(tr -cd 'a-z0-9' </dev/urandom | head -c5)"
    PASSWORD=$(tr -cd 'A-Za-z0-9' </dev/urandom | head -c12)

    # public IP
    PUBLIC_IP=$(curl -s https://ipinfo.io/ip || curl -s ifconfig.me || echo "Failed")
    [[ "$PUBLIC_IP" == "Failed" ]] && {
        echo -e "${RED}❌ Unable to detect public IP. Check internet.${NC}"
        echo -e "${YELLOW}→ Type 'exit' to close terminal${NC}"; exit 1
    }

    # backup & write config
    mv "$SQUID_CONF" "$SQUID_CONF.bak" 2>/dev/null || true
    cat >"$SQUID_CONF" <<'EOF'
http_port 3128
cache deny all
access_log none
cache_store_log none
cache_log /dev/null

acl localhost src 127.0.0.1/32 ::1
acl Safe_ports port 80 443 21 70 210 1025-65535
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

    # password file
    htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD" >/dev/null 2>&1
    chown "$SQUID_USER": /etc/squid/passwd 2>/dev/null || true
    chmod 600 /etc/squid/passwd

    # restart squid
    systemctl stop squid 2>/dev/null || true
    systemctl enable squid 2>/dev/null || true
    systemctl restart squid

    # ---------- NEW: automatic firewall rule ----------
    echo -e "${YELLOW}🔓 Configuring firewall (if any)...${NC}"
    if command -v ufw &>/dev/null; then
        ufw allow 3128/tcp comment "Tatkalworld Squid proxy" >/dev/null 2>&1
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=3128/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    elif command -v iptables &>/dev/null; then
        iptables -C INPUT -p tcp --dport 3128 -j ACCEPT 2>/dev/null \
        || iptables -I INPUT -p tcp --dport 3128 -j ACCEPT
        netfilter-persistent save >/dev/null 2>&1 \
        || iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    # ---------- end firewall ----------

    sleep 3
    if ! systemctl is-active --quiet squid; then
        echo -e "${RED}❌ Squid failed to start. Check: journalctl -u squid${NC}"
        echo -e "${YELLOW}→ Type 'exit' to close terminal${NC}"; exit 1
    fi

    PROXY_LINE="${PUBLIC_IP}:3128:${USERNAME}:${PASSWORD}"

    echo
    echo -e "${GREEN}🔐 PROXY CREATED SUCCESSFULLY!${NC}"
    echo -e "${WHITE}📋 Copy Your Proxy (IP:PORT:USERNAME:PASSWORD):${NC}"
    echo
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│  ${PROXY_LINE}  │${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo

    # quick test
    echo -e "${YELLOW}🔍 Testing on irctc.co.in...${NC}"
    PROXY_URL="http://$USERNAME:$PASSWORD@$PUBLIC_IP:3128"
    RESPONSE=$(curl -s --proxy "$PROXY_URL" -m20 -L https://www.irctc.co.in/nget/train-search)
    if grep -qi "JavaScript" <<<"$RESPONSE"; then
        echo -e "${YELLOW}⚠ IRCTC loaded, but requires browser with JS${NC}"
    elif grep -qi "blocked\|access denied\|captcha" <<<"$RESPONSE"; then
        echo -e "${RED}❌ Your IP is blocked by IRCTC${NC}"
    else
        echo -e "${GREEN}✔ Proxy works — response received${NC}"
    fi

    echo
    echo -e "${MAGENTA}👋 Thank you for using Tatkalworld.com!${NC}"
    echo -e "${WHITE}→ Type '${CYAN}exit${WHITE}' to close terminal${NC}"
    echo

# -------------------- 02: UNINSTALL --------------------
elif [[ "$OPTION" == "02" ]]; then
    echo -e "${RED}🗑️ Uninstalling Squid Proxy...${NC}"
    systemctl stop squid 2>/dev/null || true
    systemctl disable squid 2>/dev/null || true
    apt-get purge $APT_OPTS squid 2>/dev/null || true
    rm -rf /etc/squid /etc/squid3
    userdel squid proxy 2>/dev/null || true
    echo -e "${GREEN}✅ Squid Proxy has been fully removed!${NC}"
    echo -e "${WHITE}→ Type '${CYAN}exit${WHITE}' to close terminal${NC}"
    echo

# -------------------- invalid --------------------
else
    echo -e "${RED}❌ Invalid option. Please run again.${NC}"
    echo -e "${WHITE}→ Use '01' to install or '02' to uninstall${NC}"
    echo -e "${WHITE}→ Example: ${CYAN}sudo bash proxy.sh 01${NC}"
    echo -e "${WHITE}→ Type '${CYAN}exit${WHITE}' to close terminal${NC}"
    echo
fi
