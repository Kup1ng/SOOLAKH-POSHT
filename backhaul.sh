SCRIPT_VERSION="v0.6.3"
service_dir="/etc/systemd/system"
config_dir="/root/backhaul-core"
if [[ $EUID -ne 0 ]]; then
echo "This script must be run as root"
sleep 1
exit 1
fi
press_key(){
read -p "Press any key to continue..."
}
colorize() {
local color="$1"
local text="$2"
local style="${3:-normal}"
local black="\033[30m"
local red="\033[31m"
local green="\033[32m"
local yellow="\033[33m"
local blue="\033[34m"
local magenta="\033[35m"
local cyan="\033[36m"
local white="\033[37m"
local reset="\033[0m"
local normal="\033[0m"
local bold="\033[1m"
local underline="\033[4m"
local color_code
case $color in
black) color_code=$black ;;
red) color_code=$red ;;
green) color_code=$green ;;
yellow) color_code=$yellow ;;
blue) color_code=$blue ;;
magenta) color_code=$magenta ;;
cyan) color_code=$cyan ;;
white) color_code=$white ;;
*) color_code=$reset ;;  # Default case, no color
esac
local style_code
case $style in
bold) style_code=$bold ;;
underline) style_code=$underline ;;
normal | *) style_code=$normal ;;  # Default case, normal text
esac
echo -e "${style_code}${color_code}${text}${reset}"
}
install_unzip() {
if ! command -v unzip &> /dev/null; then
if command -v apt-get &> /dev/null; then
echo -e "${RED}unzip is not installed. Installing...${NC}"
sleep 1
sudo apt-get update
sudo apt-get install -y unzip
else
echo -e "${RED}Error: Unsupported package manager. Please install unzip manually.${NC}\n"
press_key
exit 1
fi
fi
}
install_jq() {
if ! command -v jq &> /dev/null; then
if command -v apt-get &> /dev/null; then
echo -e "${RED}jq is not installed. Installing...${NC}"
sleep 1
sudo apt-get update
sudo apt-get install -y jq
else
echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
press_key
exit 1
fi
fi
}
download_and_extract_backhaul() {
if [[ "$1" == "menu" ]]; then
rm -rf "${config_dir}/backhaul_premium" >/dev/null 2>&1
echo
colorize cyan "Restart all services after updating to new core" bold
sleep 2
fi
if [[ -f "${config_dir}/backhaul_premium" ]]; then
return 1
fi
if [[ $(uname) != "Linux" ]]; then
echo -e "${RED}Unsupported operating system.${NC}"
sleep 1
exit 1
fi
ARCH=$(uname -m)
case "$ARCH" in
x86_64)
PRIMARY_URL="https://raw.githubusercontent.com/Kup1ng/SOOLAKH-POSHT-DOCTOR/main/backhaul-patch-amd64"
FALLBACK_URL="http://185.212.50.96/backhaul-patch-amd64"
;;
arm64|aarch64)
PRIMARY_URL="https://raw.githubusercontent.com/Kup1ng/SOOLAKH-POSHT-DOCTOR/main/backhaul-patch-arm64"
FALLBACK_URL="http://127.0.0.1/backhaul-patch-arm64"
;;
*)
echo -e "${RED}Unsupported architecture: $ARCH.${NC}"
sleep 1
exit 1
;;
esac
DOWNLOAD_DIR=$(mktemp -d)
echo -e "Downloading Backhaul from primary source (15s timeout)...\n"
sleep 1
if ! curl -sSL --ipv4 --max-time 10 -o "$DOWNLOAD_DIR/backhaul.tar.gz" "$PRIMARY_URL"; then
echo -e "${YELLOW}Primary download failed or timed out. Trying fallback URL...${NC}\n"
if ! curl -sSL --ipv4 --max-time 30 -o "$DOWNLOAD_DIR/backhaul.tar.gz" "$FALLBACK_URL"; then
echo -e "${RED}Both download attempts failed.${NC}"
rm -rf "$DOWNLOAD_DIR"
exit 1
fi
fi
echo -e "Extracting Backhaul...\n"
sleep 1
mkdir -p "$config_dir"
tar -xzf "$DOWNLOAD_DIR/backhaul.tar.gz" -C "$config_dir"
echo -e "${GREEN}Backhaul installation completed.${NC}\n"
chmod u+x "${config_dir}/backhaul_premium"
rm -rf "$DOWNLOAD_DIR"
rm -rf "${config_dir}/LICENSE" >/dev/null 2>&1
rm -rf "${config_dir}/README.md" >/dev/null 2>&1
}
download_and_extract_backhaul
SERVER_IP=$(hostname -I | awk '{print $1}')
check_config_backup() {
missing_services=()
for config in "${config_dir}"/iran*.toml "${config_dir}"/kharej*.toml; do
[ -e "$config" ] || continue
fname=$(basename "$config")
if [[ "$fname" =~ ^(iran|kharej)([0-9]+)\.toml$ ]]; then
location="${BASH_REMATCH[1]}"
tunnel_port="${BASH_REMATCH[2]}"
service_file="${service_dir}/backhaul-${location}${tunnel_port}.service"
if [[ ! -f "$service_file" ]]; then
missing_services+=("$service_file:$location:$tunnel_port")
fi
fi
done
if [[ ${#missing_services[@]} -eq 0 ]]; then
colorize green "All related service files exist." bold
return 0
fi
echo
colorize red "Missing service files:" bold
for entry in "${missing_services[@]}"; do
service_file="${entry%%:*}"
location="${entry#*:}"; location="${location%%:*}"
tunnel_port="${entry##*:}"
echo "- $service_file (type: $location, port: $tunnel_port)"
done
echo
read -p "Do you want to create missing service files? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
for entry in "${missing_services[@]}"; do
service_file="${entry%%:*}"
location="${entry#*:}"; location="${location%%:*}"
tunnel_port="${entry##*:}"
config_file="${config_dir}/${location}${tunnel_port}.toml"
desc_loc="$(tr '[:lower:]' '[:upper:]' <<< ${location:0:1})${location:1}"
cat > "$service_file" <<EOF
[Unit]
Description=Backhaul $desc_loc Port $tunnel_port
After=network.target
[Service]
Type=simple
ExecStart=${config_dir}/backhaul_premium -c $config_file
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
echo "Created $service_file"
sudo systemctl daemon-reload
sudo systemctl enable --now "$(basename "$service_file")"
echo "Enabled and started $(basename "$service_file")"
done
else
echo "No files created."
fi
sleep 2
}
check_config_backup
display_logo() {
echo -e "${CYAN}"
cat << "EOF"
  _________________   ________   .____        _____    ____  __. ___ ___  
 /   _____/\_____  \  \_____  \  |    |      /  _  \  |    |/ _|/   |   \ 
 \_____  \  /   |   \  /   |   \ |    |     /  /_\  \ |      < /    ~    \
 /        \/    |    \/    |    \|    |___ /    |    \|    |  \\    Y    /
/_______  /\_______  /\_______  /|_______ \\____|__  /|____|__ \\___|_  / 
        \/         \/         \/         \/        \/         \/      \/  
Lightning-fast reverse tunneling solution
EOF
echo -e "${NC}${GREEN}"
echo -e "Script Version: ${YELLOW}${SCRIPT_VERSION}${GREEN}"
if [[ -f "${config_dir}/backhaul_premium" ]]; then
echo -e "Core Version: ${YELLOW}$($config_dir/backhaul_premium -v)${GREEN}"
fi
echo -e "Telegram Channel: ${YELLOW}@Gozar_XRay${NC}"
}
display_server_info() {
echo -e "\e[93m═══════════════════════════════════════════\e[0m"
echo -e "${CYAN}IP Address:${NC} $SERVER_IP"
echo -e "${CYAN}Location:${NC} Koone Doctor"
echo -e "${CYAN}Datacenter:${NC} doctor kooni"
}
display_backhaul_core_status() {
if [[ -f "${config_dir}/backhaul_premium" ]]; then
echo -e "${CYAN}Backhaul Core:${NC} ${GREEN}Installed${NC}"
else
echo -e "${CYAN}Backhaul Core:${NC} ${RED}Not installed${NC}"
fi
echo -e "\e[93m═══════════════════════════════════════════\e[0m"
}
check_ipv6() {
local ip=$1
ipv6_pattern="^([0-9a-fA-F]{1,4}:){7}([0-9a-fA-F]{1,4}|:)$|^(([0-9a-fA-F]{1,4}:){1,7}|:):((:[0-9a-fA-F]{1,4}){1,7}|:)$"
ip="${ip#[}"
ip="${ip%]}"
if [[ $ip =~ $ipv6_pattern ]]; then
return 0  # Valid IPv6 address
else
return 1  # Invalid IPv6 address
fi
}
check_port() {
local PORT=$1
local TRANSPORT=$2
if [ -z "$PORT" ]; then
echo "Usage: check_port <port> <transport>"
return 1
fi
if [[ "$TRANSPORT" == "tcp" ]]; then
if ss -tlnp "sport = :$PORT" | grep "$PORT" > /dev/null; then
return 0
else
return 1
fi
elif [[ "$TRANSPORT" == "udp" ]]; then
if ss -ulnp "sport = :$PORT" | grep "$PORT" > /dev/null; then
return 0
else
return 1
fi
else
return 1
fi
}
configure_tunnel() {
if [[ ! -d "$config_dir" ]]; then
echo -e "\n${RED}Backhaul-Core directory not found. Install it first through 'Install Backhaul core' option.${NC}\n"
read -p "Press Enter to continue..."
return 1
fi
clear
echo
colorize green "1) Configure for IRAN server" bold
colorize magenta "2) Configure for KHAREJ server" bold
echo
read -p "Enter your choice: " configure_choice
case "$configure_choice" in
1) iran_server_configuration ;;
2) kharej_server_configuration ;;
*) echo -e "${RED}Invalid option!${NC}" && sleep 1 ;;
esac
echo
read -p "Press Enter to continue..."
}
iran_server_configuration() {
clear
colorize cyan "Configuring IRAN server" bold
echo
while true; do
echo -ne "[*] Tunnel port: "
read -r tunnel_port
if [[ "$tunnel_port" =~ ^[0-9]+$ ]] && [ "$tunnel_port" -gt 22 ] && [ "$tunnel_port" -le 65535 ]; then
if check_port "$tunnel_port" "tcp"; then
colorize red "Port $tunnel_port is in use."
else
break
fi
else
colorize red "Please enter a valid port number between 23 and 65535."
echo
fi
done
echo
local transport=""
while [[ ! "$transport" =~ ^(tcp|tcpmux|utcpmux|ws|wsmux|uwsmux|udp|tcptun|faketcptun)$ ]]; do
echo -ne "[*] Transport type (tcp/tcpmux/utcpmux/ws/wsmux/uwsmux/udp/tcptun/faketcptun): "
read -r transport
if [[ ! "$transport" =~ ^(tcp|tcpmux|utcpmux|ws|wsmux|uwsmux|udp|tcptun|faketcptun)$ ]]; then
colorize red "Invalid transport type. Please choose from tcp, tcpmux, utcpmux, ws, wsmux, uwsmux, udp, tcptun, faketcptun."
echo
fi
done
echo
local tun_name="backhaul"
if [[ "$transport" == "tcptun" || "$transport" == "faketcptun" ]]; then
while true; do
echo -ne "[-] TUN Device Name (default backhaul): "
read -r tun_name
if [[ -z "$tun_name" ]]; then
tun_name="backhaul"
fi
if [[ "$tun_name" =~ ^[a-zA-Z0-9]+$ ]]; then
echo
break
else
colorize red "Please enter a valid TUN device name."
echo
fi
done
fi
local tun_subnet="10.10.10.0/24"
if [[ "$transport" == "tcptun" || "$transport" == "faketcptun" ]]; then
while true; do
echo -ne "[-] TUN Subnet (default 10.10.10.0/24): "
read -r tun_subnet
if [[ -z "$tun_subnet" ]]; then
tun_subnet="10.10.10.0/24"
fi
if [[ "$tun_subnet" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]]; then
IFS='/' read -r ip subnet <<< "$tun_subnet"
if [[ "$subnet" -le 32 && "$subnet" -ge 1 ]]; then
IFS='.' read -r a b c d <<< "$ip"
if [[ "$a" -le 255 && "$b" -le 255 && "$c" -le 255 && "$d" -le 255 ]]; then
echo
break
fi
fi
fi
colorize red "Please enter a valid subnet in CIDR notation (e.g., 10.10.10.0/24)."
echo
done
fi
local mtu="1500"
if [[ "$transport" == "tcptun" || "$transport" == "faketcptun" ]]; then
while true; do
echo -ne "[-] TUN MTU (default 1500): "
read -r mtu
if [[ -z "$mtu" ]]; then
mtu=1500
fi
if [[ "$mtu" =~ ^[0-9]+$ ]] && [ "$mtu" -ge 576 ] && [ "$mtu" -le 9000 ]; then
break
fi
colorize red "Please enter a valid MTU value between 576 and 9000."
echo
done
fi
local accept_udp=""
if [[ "$transport" == "tcp" ]]; then
while [[ "$accept_udp" != "true" && "$accept_udp" != "false" ]]; do
echo -ne "[-] Accept UDP connections over TCP transport (true/false)(default false): "
read -r accept_udp
if [[ -z "$accept_udp" ]]; then
accept_udp="false"
fi
if [[ "$accept_udp" != "true" && "$accept_udp" != "false" ]]; then
colorize red "Invalid input. Please enter 'true' or 'false'."
echo
fi
done
else
accept_udp="false"
fi
echo
local channel_size="2048"
if [[ "$transport" != "tcptun" && "$transport" != "faketcptun" ]]; then
while true; do
echo -ne "[-] Channel Size (default 2048): "
read -r channel_size
if [[ -z "$channel_size" ]]; then
channel_size=2048
fi
if [[ "$channel_size" =~ ^[0-9]+$ ]] && [ "$channel_size" -gt 64 ] && [ "$channel_size" -le 8192 ]; then
break
else
colorize red "Please enter a valid channel size between 64 and 8192."
echo
fi
done
echo
fi
local nodelay=""
if [[ "$transport" == "udp" ]]; then
nodelay=false
else
while [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; do
echo -ne "[-] Enable TCP_NODELAY (true/false)(default true): "
read -r nodelay
if [[ -z "$nodelay" ]]; then
nodelay=true
fi
if [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; then
colorize red "Invalid input. Please enter 'true' or 'false'."
echo
fi
done
fi
echo
local heartbeat=40
if [[ "$transport" != "tcptun" && "$transport" != "faketcptun" ]]; then
while true; do
echo -ne "[-] Heartbeat (in seconds, default 40): "
read -r heartbeat
if [[ -z "$heartbeat" ]]; then
heartbeat=40
fi
if [[ "$heartbeat" =~ ^[0-9]+$ ]] && [ "$heartbeat" -gt 1 ] && [ "$heartbeat" -le 240 ]; then
break
else
colorize red "Please enter a valid heartbeat between 1 and 240."
echo
fi
done
echo
fi
echo -ne "[-] Security Token (press enter to use default value): "
read -r token
token="${token:-your_token}"
if [[ "$transport" =~ ^(tcpmux|wsmux)$ ]]; then
while true; do
echo
echo -ne "[-] Mux concurrency (default 4): "
read -r mux
if [[ -z "$mux" ]]; then
mux=4
fi
if [[ "$mux" =~ ^[0-9]+$ ]] && [ "$mux" -gt 0 ] && [ "$mux" -le 1000 ]; then
break
else
colorize red "Please enter a valid concurrency between 0 and 1000"
echo
fi
done
else
mux=8
fi
if [[ "$transport" =~ ^(tcpmux|wsmux|utcpmux|uwsmux)$ ]]; then
while true; do
echo
echo -ne "[-] Mux Version (1 or 2) (default 2): "
read -r mux_version
if [[ -z "$mux_version" ]]; then
mux_version=2
fi
if [[ "$mux_version" =~ ^[0-9]+$ ]] && [ "$mux_version" -ge 1 ] && [ "$mux_version" -le 2 ]; then
break
else
colorize red "Please enter a valid mux version: 1 or 2."
echo
fi
done
else
mux_version=2
fi
echo
local sniffer=""
while [[ "$sniffer" != "true" && "$sniffer" != "false" ]]; do
echo -ne "[-] Enable Sniffer (true/false)(default false): "
read -r sniffer
if [[ -z "$sniffer" ]]; then
sniffer=false
fi
if [[ "$sniffer" != "true" && "$sniffer" != "false" ]]; then
colorize red "Invalid input. Please enter 'true' or 'false'."
echo
fi
done
echo
local web_port=""
while true; do
echo -ne "[-] Enter Web Port (default 0 to disable): "
read -r web_port
if [[ -z "$web_port" ]]; then
web_port=0
fi
if [[ "$web_port" == "0" ]]; then
break
elif [[ "$web_port" =~ ^[0-9]+$ ]] && ((web_port >= 23 && web_port <= 65535)); then
if check_port "$web_port" "tcp"; then
colorize red "Port $web_port is already in use. Please choose a different port."
echo
else
break
fi
else
colorize red "Invalid port. Please enter a number between 22 and 65535, or 0 to disable."
echo
fi
done
echo
if [[ ! "$transport" =~ ^(ws|udp|tcptun|faketcptun)$ ]]; then
local proxy_protocol=""
while [[ "$proxy_protocol" != "true" && "$proxy_protocol" != "false" ]]; do
echo -ne "[-] Enable Proxy Protocol (true/false)(default false): "
read -r proxy_protocol
if [[ -z "$proxy_protocol" ]]; then
proxy_protocol=false
fi
if [[ "$proxy_protocol" != "true" && "$proxy_protocol" != "false" ]]; then
colorize red "Invalid input. Please enter 'true' or 'false'."
echo
fi
done
else
proxy_protocol="false"
fi
echo
if [[ "$transport" != "tcptun" && "$transport" != "faketcptun" ]]; then
colorize green "[*] Supported Port Formats:" bold
echo "1. 443-600                  - Listen on all ports in the range 443 to 600."
echo "2. 443-600:5201             - Listen on all ports in the range 443 to 600 and forward traffic to 5201."
echo "3. 443-600=1.1.1.1:5201     - Listen on all ports in the range 443 to 600 and forward traffic to 1.1.1.1:5201."
echo "4. 443                      - Listen on local port 443 and forward to remote port 443 (default forwarding)."
echo "5. 4000=5000                - Listen on local port 4000 (bind to all local IPs) and forward to remote port 5000."
echo "6. 127.0.0.2:443=5201       - Bind to specific local IP (127.0.0.2), listen on port 443, and forward to remote port 5201."
echo "7. 443=1.1.1.1:5201         - Listen on local port 443 and forward to a specific remote IP (1.1.1.1) on port 5201."
echo ""
echo -ne "[*] Enter your ports in the specified formats (separated by commas): "
read -r input_ports
input_ports=$(echo "$input_ports" | tr -d ' ')
IFS=',' read -r -a ports <<< "$input_ports"
fi
cat << EOF > "${config_dir}/iran${tunnel_port}.toml"
[server]
bind_addr = ":${tunnel_port}"
transport = "${transport}"
accept_udp = ${accept_udp}
token = "${token}"
keepalive_period = 75
nodelay = ${nodelay}
channel_size = ${channel_size}
heartbeat = ${heartbeat}
mux_con = ${mux}
mux_version = ${mux_version}
mux_framesize = 32768
mux_recievebuffer = 4194304
mux_streambuffer = 2000000
sniffer = ${sniffer}
web_port = ${web_port}
sniffer_log = "/root/log.json"
log_level = "info"
proxy_protocol= ${proxy_protocol}
tun_name = "${tun_name}"
tun_subnet = "${tun_subnet}"
mtu = ${mtu}
ports = [
EOF
for port in "${ports[@]}"; do
if [[ "$port" =~ ^[0-9]+-[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
elif [[ "$port" =~ ^[0-9]+-[0-9]+:[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
elif [[ "$port" =~ ^[0-9]+-[0-9]+=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
elif [[ "$port" =~ ^[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
elif [[ "$port" =~ ^[0-9]+=[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
elif [[ "$port" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):[0-9]+=[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
elif [[ "$port" =~ ^[0-9]+=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
elif [[ "$port" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):[0-9]+=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
echo "    \"$port\"," >> "${config_dir}/iran${tunnel_port}.toml"
else
colorize red "[ERROR] Invalid port mapping: $port. Skipping."
echo
fi
done
echo "]" >> "${config_dir}/iran${tunnel_port}.toml"
echo
colorize green "Configuration generated successfully!"
echo
cat << EOF > "${service_dir}/backhaul-iran${tunnel_port}.service"
[Unit]
Description=Backhaul Iran Port $tunnel_port (Iran)
After=network.target
[Service]
Type=simple
ExecStart=${config_dir}/backhaul_premium -c ${config_dir}/iran${tunnel_port}.toml
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
if systemctl enable --now "${service_dir}/backhaul-iran${tunnel_port}.service" >/dev/null 2>&1; then
colorize green "Iran service with port $tunnel_port enabled to start on boot and started."
else
colorize red "Failed to enable service with port $tunnel_port. Please check your system configuration."
return 1
fi
echo
colorize green "IRAN server configuration completed successfully." bold
}
kharej_server_configuration() {
clear
colorize cyan "Configuring Kharej server" bold
echo
while true; do
echo -ne "[*] IRAN server IP address [IPv4/IPv6]: "
read -r SERVER_ADDR
if [[ -n "$SERVER_ADDR" ]]; then
break
else
colorize red "Server address cannot be empty. Please enter a valid address."
echo
fi
done
echo
while true; do
echo -ne "[*] Tunnel port: "
read -r tunnel_port
if [[ "$tunnel_port" =~ ^[0-9]+$ ]] && [ "$tunnel_port" -gt 22 ] && [ "$tunnel_port" -le 65535 ]; then
break
else
colorize red "Please enter a valid port number between 23 and 65535"
echo
fi
done
echo
local transport=""
while [[ ! "$transport" =~ ^(tcp|tcpmux|utcpmux|ws|wsmux|uwsmux|udp|tcptun|faketcptun)$ ]]; do
echo -ne "[*] Transport type (tcp/tcpmux/utcpmux/ws/wsmux/uwsmux/udp/tcptun/faketcptun): "
read -r transport
if [[ ! "$transport" =~ ^(tcp|tcpmux|utcpmux|ws|wsmux|uwsmux|udp|tcptun|faketcptun)$ ]]; then
colorize red "Invalid transport type. Please choose from tcp, tcpmux, utcpmux, ws, wsmux, uwsmux, udp, tcptun, faketcptun."
echo
fi
done
local tun_name="backhaul"
if [[ "$transport" == "tcptun" || "$transport" == "faketcptun" ]]; then
echo
while true; do
echo -ne "[-] TUN Device Name (default backhaul): "
read -r tun_name
if [[ -z "$tun_name" ]]; then
tun_name="backhaul"
fi
if [[ "$tun_name" =~ ^[a-zA-Z0-9]+$ ]]; then
echo
break
else
colorize red "Please enter a valid TUN device name."
echo
fi
done
fi
local tun_subnet="10.10.10.0/24"
if [[ "$transport" == "tcptun" || "$transport" == "faketcptun" ]]; then
while true; do
echo -ne "[-] TUN Subnet (default 10.10.10.0/24): "
read -r tun_subnet
if [[ -z "$tun_subnet" ]]; then
tun_subnet="10.10.10.0/24"
fi
if [[ "$tun_subnet" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]]; then
IFS='/' read -r ip subnet <<< "$tun_subnet"
if [[ "$subnet" -le 32 && "$subnet" -ge 1 ]]; then
IFS='.' read -r a b c d <<< "$ip"
if [[ "$a" -le 255 && "$b" -le 255 && "$c" -le 255 && "$d" -le 255 ]]; then
echo
break
fi
fi
fi
colorize red "Please enter a valid subnet in CIDR notation (e.g., 10.10.10.0/24)."
echo
done
fi
local mtu="1500"
if [[ "$transport" == "tcptun" || "$transport" == "faketcptun" ]]; then
while true; do
echo -ne "[-] TUN MTU (default 1500): "
read -r mtu
if [[ -z "$mtu" ]]; then
mtu=1500
fi
if [[ "$mtu" =~ ^[0-9]+$ ]] && [ "$mtu" -ge 576 ] && [ "$mtu" -le 9000 ]; then
break
fi
colorize red "Please enter a valid MTU value between 576 and 9000."
echo
done
fi
if [[ "$transport" =~ ^(ws|wsmux|uwsmux)$ ]]; then
while true; do
echo
echo -ne "[-] Edge IP/Domain (optional)(press enter to disable): "
read -r edge_ip
if [[ -z "$edge_ip" ]]; then
edge_ip="#edge_ip = \"188.114.96.0\""
break
fi
edge_ip="edge_ip = \"$edge_ip\""
break
done
else
edge_ip="#edge_ip = \"188.114.96.0\""
fi
echo
echo -ne "[-] Security Token (press enter to use default value): "
read -r token
token="${token:-your_token}"
local nodelay=""
if [[ "$transport" == "udp" ]]; then
nodelay=false
else
echo
while [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; do
echo -ne "[-] Enable TCP_NODELAY (true/false)(default true): "
read -r nodelay
if [[ -z "$nodelay" ]]; then
nodelay=true
fi
if [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; then
colorize red "Invalid input. Please enter 'true' or 'false'."
echo
fi
done
fi
local pool=8
if [[ "$transport" != "tcptun" && "$transport" != "faketcptun" ]]; then
echo
while true; do
echo -ne "[-] Connection Pool (default 8): "
read -r pool
if [[ -z "$pool" ]]; then
pool=8
fi
if [[ "$pool" =~ ^[0-9]+$ ]] && [ "$pool" -gt 1 ] && [ "$pool" -le 1024 ]; then
break
else
colorize red "Please enter a valid connection pool between 1 and 1024."
echo
fi
done
fi
if [[ "$transport" =~ ^(tcpmux|wsmux|utcpmux|uwsmux)$ ]]; then
while true; do
echo
echo -ne "[-] Mux Version (1 or 2) (default 2): "
read -r mux_version
if [[ -z "$mux_version" ]]; then
mux_version=2
fi
if [[ "$mux_version" =~ ^[0-9]+$ ]] && [ "$mux_version" -ge 1 ] && [ "$mux_version" -le 2 ]; then
break
else
colorize red "Please enter a valid mux version: 1 or 2."
echo
fi
done
else
mux_version=2
fi
echo
local sniffer=""
while [[ "$sniffer" != "true" && "$sniffer" != "false" ]]; do
echo -ne "[-] Enable Sniffer (true/false)(default false): "
read -r sniffer
if [[ -z "$sniffer" ]]; then
sniffer=false
fi
if [[ "$sniffer" != "true" && "$sniffer" != "false" ]]; then
colorize red "Invalid input. Please enter 'true' or 'false'."
echo
fi
done
echo
local web_port=""
while true; do
echo -ne "[-] Enter Web Port (default 0 to disable): "
read -r web_port
if [[ -z "$web_port" ]]; then
web_port=0
fi
if [[ "$web_port" == "0" ]]; then
break
elif [[ "$web_port" =~ ^[0-9]+$ ]] && ((web_port >= 23 && web_port <= 65535)); then
if check_port "$web_port" "tcp"; then
colorize red "Port $web_port is already in use. Please choose a different port."
echo
else
break
fi
else
colorize red "Invalid port. Please enter a number between 22 and 65535, or 0 to disable."
echo
fi
done
if [[ ! "$transport" =~ ^(ws|udp|tcptun|faketcptun)$ ]]; then
local ip_limit=""
while [[ "$ip_limit" != "true" && "$ip_limit" != "false" ]]; do
echo
echo -ne "[-] Enable IP Limit for X-UI Panel (true/false)(default false): "
read -r ip_limit
if [[ -z "$ip_limit" ]]; then
ip_limit=false
fi
if [[ "$ip_limit" != "true" && "$ip_limit" != "false" ]]; then
colorize red "Invalid input. Please enter 'true' or 'false'."
echo
fi
done
else
ip_limit="false"
fi
cat << EOF > "${config_dir}/kharej${tunnel_port}.toml"
[client]
remote_addr = "${SERVER_ADDR}:${tunnel_port}"
${edge_ip}
transport = "${transport}"
token = "${token}"
connection_pool = ${pool}
aggressive_pool = false
keepalive_period = 75
nodelay = ${nodelay}
retry_interval = 3
dial_timeout = 10
mux_version = ${mux_version}
mux_framesize = 32768
mux_recievebuffer = 4194304
mux_streambuffer = 2000000
sniffer = ${sniffer}
web_port = ${web_port}
sniffer_log = "/root/log.json"
log_level = "info"
ip_limit= ${ip_limit}
tun_name = "${tun_name}"
tun_subnet = "${tun_subnet}"
mtu = ${mtu}
EOF
echo
cat << EOF > "${service_dir}/backhaul-kharej${tunnel_port}.service"
[Unit]
Description=Backhaul Kharej Port $tunnel_port
After=network.target
[Service]
Type=simple
ExecStart=${config_dir}/backhaul_premium -c ${config_dir}/kharej${tunnel_port}.toml
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
if systemctl enable --now "${service_dir}/backhaul-kharej${tunnel_port}.service" >/dev/null 2>&1; then
colorize green "Kharej service with port $tunnel_port enabled to start on boot and started."
else
colorize red "Failed to enable service with port $tunnel_port. Please check your system configuration."
return 1
fi
echo
colorize green "Kharej server configuration completed successfully." bold
}
remove_core(){
echo
if find "$config_dir" -type f -name "*.toml" | grep -q .; then
colorize red "You should delete all services first and then delete the Backhaul-Core."
sleep 3
return 1
else
colorize cyan "No .toml file found in the directory."
fi
echo
colorize yellow "Do you want to remove Backhaul-Core? (y/n)"
read -r confirm
echo
if [[ $confirm == [yY] ]]; then
if [[ -d "$config_dir" ]]; then
rm -rf "$config_dir" >/dev/null 2>&1
colorize green "Backhaul-Core directory removed." bold
else
colorize red "Backhaul-Core directory not found." bold
fi
else
colorize yellow "Backhaul-Core removal canceled."
fi
echo
press_key
}
check_tunnel_status() {
echo
if ! ls "$config_dir"/*.toml 1> /dev/null 2>&1; then
colorize red "No config files found in the Backhaul directory." bold
echo
press_key
return 1
fi
clear
colorize yellow "Checking all services status..." bold
sleep 1
echo
for config_path in "$config_dir"/iran*.toml; do
if [ -f "$config_path" ]; then
config_name=$(basename "$config_path")
config_name="${config_name%.toml}"
service_name="backhaul-${config_name}.service"
config_port="${config_name#iran}"
if systemctl is-active --quiet "$service_name"; then
colorize green "Iran service with tunnel port $config_port is running"
else
colorize red "Iran service with tunnel port $config_port is not running"
fi
fi
done
for config_path in "$config_dir"/kharej*.toml; do
if [ -f "$config_path" ]; then
config_name=$(basename "$config_path")
config_name="${config_name%.toml}"
service_name="backhaul-${config_name}.service"
config_port="${config_name#kharej}"
if systemctl is-active --quiet "$service_name"; then
colorize green "Kharej service with tunnel port $config_port is running"
else
colorize red "Kharej service with tunnel port $config_port is not running"
fi
fi
done
echo
press_key
}
tunnel_management() {
echo
if ! ls "$config_dir"/*.toml 1> /dev/null 2>&1; then
colorize red "No config files found in the Backhaul directory." bold
echo
press_key
return 1
fi
clear
colorize cyan "List of existing services to manage:" bold
echo
local index=1
declare -a configs
for config_path in "$config_dir"/iran*.toml; do
if [ -f "$config_path" ]; then
config_name=$(basename "$config_path")
config_port="${config_name#iran}"
config_port="${config_port%.toml}"
configs+=("$config_path")
echo -e "${MAGENTA}${index}${NC}) ${GREEN}Iran${NC} service, Tunnel port: ${YELLOW}$config_port${NC}"
((index++))
fi
done
for config_path in "$config_dir"/kharej*.toml; do
if [ -f "$config_path" ]; then
config_name=$(basename "$config_path")
config_port="${config_name#kharej}"
config_port="${config_port%.toml}"
configs+=("$config_path")
echo -e "${MAGENTA}${index}${NC}) ${GREEN}Kharej${NC} service, Tunnel port: ${YELLOW}$config_port${NC}"
((index++))
fi
done
echo
echo -ne "Enter your choice (0 to return): "
read choice
if (( choice == 0 )); then
return
fi
while ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice > ${#configs[@]} )); do
colorize red "Invalid choice. Please enter a number between 1 and ${#configs[@]}." bold
echo
echo -ne "Enter your choice (0 to return): "
read choice
if (( choice == 0 )); then
return
fi
done
selected_config="${configs[$((choice - 1))]}"
config_name=$(basename "${selected_config%.toml}")
service_name="backhaul-${config_name}.service"
clear
colorize cyan "List of available commands for $config_name:" bold
echo
colorize red "1) Remove this tunnel"
colorize yellow "2) Restart this tunnel"
colorize reset "3) View service logs"
colorize reset "4) View service status"
echo
read -p "Enter your choice (0 to return): " choice
case $choice in
1) destroy_tunnel "$selected_config" ;;
2) restart_service "$service_name" ;;
3) view_service_logs "$service_name" ;;
4) view_service_status "$service_name" ;;
0) return 1 ;;
*) echo -e "${RED}Invalid option!${NC}" && sleep 1 && return 1;;
esac
}
destroy_tunnel(){
config_path="$1"
config_name=$(basename "${config_path%.toml}")
service_name="backhaul-${config_name}.service"
service_path="$service_dir/$service_name"
if [ -f "$config_path" ]; then
rm -f "$config_path" >/dev/null 2>&1
fi
if [[ -f "$service_path" ]]; then
if systemctl is-active "$service_name" &>/dev/null; then
systemctl disable --now "$service_name" >/dev/null 2>&1
fi
rm -f "$service_path" >/dev/null 2>&1
fi
echo
if systemctl daemon-reload >/dev/null 2>&1 ; then
echo -e "Systemd daemon reloaded.\n"
else
echo -e "${RED}Failed to reload systemd daemon. Please check your system configuration.${NC}"
fi
colorize green "Tunnel destroyed successfully!" bold
echo
press_key
}
restart_service() {
echo
service_name="$1"
colorize yellow "Restarting $service_name" bold
echo
if systemctl list-units --type=service | grep -q "$service_name"; then
systemctl restart "$service_name"
colorize green "Service restarted successfully" bold
else
colorize red "Cannot restart the service"
fi
echo
press_key
}
view_service_logs (){
clear
journalctl -eu "$1" -f
press_key
}
view_service_status (){
clear
systemctl status "$1"
press_key
}
SYS_PATH="/etc/sysctl.conf"
PROF_PATH="/etc/profile"
ask_reboot() {
echo -ne "${YELLOW}Reboot now? (Recommended) (y/n): ${NC}"
while true; do
read choice
echo
if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
sleep 0.5
reboot
exit 0
fi
if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
break
fi
done
}
sysctl_optimizations() {
cp $SYS_PATH /etc/sysctl.conf.bak
echo
echo -e "${YELLOW}Default sysctl.conf file Saved. Directory: /etc/sysctl.conf.bak${NC}"
echo
sleep 1
echo
echo -e  "${YELLOW}Optimizing the Network...${NC}"
echo
sleep 0.5
sed -i -e '/fs.file-max/d' \
-e '/net.core.default_qdisc/d' \
-e '/net.core.netdev_max_backlog/d' \
-e '/net.core.optmem_max/d' \
-e '/net.core.somaxconn/d' \
-e '/net.core.rmem_max/d' \
-e '/net.core.wmem_max/d' \
-e '/net.core.rmem_default/d' \
-e '/net.core.wmem_default/d' \
-e '/net.ipv4.tcp_rmem/d' \
-e '/net.ipv4.tcp_wmem/d' \
-e '/net.ipv4.tcp_congestion_control/d' \
-e '/net.ipv4.tcp_fastopen/d' \
-e '/net.ipv4.tcp_fin_timeout/d' \
-e '/net.ipv4.tcp_keepalive_time/d' \
-e '/net.ipv4.tcp_keepalive_probes/d' \
-e '/net.ipv4.tcp_keepalive_intvl/d' \
-e '/net.ipv4.tcp_max_orphans/d' \
-e '/net.ipv4.tcp_max_syn_backlog/d' \
-e '/net.ipv4.tcp_max_tw_buckets/d' \
-e '/net.ipv4.tcp_mem/d' \
-e '/net.ipv4.tcp_mtu_probing/d' \
-e '/net.ipv4.tcp_notsent_lowat/d' \
-e '/net.ipv4.tcp_retries2/d' \
-e '/net.ipv4.tcp_sack/d' \
-e '/net.ipv4.tcp_dsack/d' \
-e '/net.ipv4.tcp_slow_start_after_idle/d' \
-e '/net.ipv4.tcp_window_scaling/d' \
-e '/net.ipv4.tcp_adv_win_scale/d' \
-e '/net.ipv4.tcp_ecn/d' \
-e '/net.ipv4.tcp_ecn_fallback/d' \
-e '/net.ipv4.tcp_syncookies/d' \
-e '/net.ipv4.udp_mem/d' \
-e '/net.ipv6.conf.all.disable_ipv6/d' \
-e '/net.ipv6.conf.default.disable_ipv6/d' \
-e '/net.ipv6.conf.lo.disable_ipv6/d' \
-e '/net.unix.max_dgram_qlen/d' \
-e '/vm.min_free_kbytes/d' \
-e '/vm.swappiness/d' \
-e '/vm.vfs_cache_pressure/d' \
-e '/net.ipv4.conf.default.rp_filter/d' \
-e '/net.ipv4.conf.all.rp_filter/d' \
-e '/net.ipv4.conf.all.accept_source_route/d' \
-e '/net.ipv4.conf.default.accept_source_route/d' \
-e '/net.ipv4.neigh.default.gc_thresh1/d' \
-e '/net.ipv4.neigh.default.gc_thresh2/d' \
-e '/net.ipv4.neigh.default.gc_thresh3/d' \
-e '/net.ipv4.neigh.default.gc_stale_time/d' \
-e '/net.ipv4.conf.default.arp_announce/d' \
-e '/net.ipv4.conf.lo.arp_announce/d' \
-e '/net.ipv4.conf.all.arp_announce/d' \
-e '/kernel.panic/d' \
-e '/vm.dirty_ratio/d' \
-e '/^#/d' \
-e '/^$/d' \
"$SYS_PATH"
cat <<EOF >> "$SYS_PATH"
fs.file-max = 67108864
net.core.default_qdisc = fq_codel
net.core.netdev_max_backlog = 32768
net.core.optmem_max = 262144
net.core.somaxconn = 65536
net.core.rmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_max = 33554432
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 16384 1048576 33554432
net.ipv4.tcp_wmem = 16384 1048576 33554432
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fin_timeout = 25
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_orphans = 819200
net.ipv4.tcp_max_syn_backlog = 20480
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mem = 65536 1048576 33554432
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.udp_mem = 65536 1048576 33554432
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.unix.max_dgram_qlen = 256
vm.min_free_kbytes = 65536
vm.swappiness = 10
vm.vfs_cache_pressure = 250
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
kernel.panic = 1
vm.dirty_ratio = 20
EOF
sudo sysctl -p
echo
echo -e "${GREEN}Network is Optimized.${NC}"
echo
sleep 0.5
}
limits_optimizations() {
echo
echo -e "${YELLOW}Optimizing System Limits...${NC}"
echo
sleep 0.5
sed -i '/ulimit -c/d' $PROF_PATH
sed -i '/ulimit -d/d' $PROF_PATH
sed -i '/ulimit -f/d' $PROF_PATH
sed -i '/ulimit -i/d' $PROF_PATH
sed -i '/ulimit -l/d' $PROF_PATH
sed -i '/ulimit -m/d' $PROF_PATH
sed -i '/ulimit -n/d' $PROF_PATH
sed -i '/ulimit -q/d' $PROF_PATH
sed -i '/ulimit -s/d' $PROF_PATH
sed -i '/ulimit -t/d' $PROF_PATH
sed -i '/ulimit -u/d' $PROF_PATH
sed -i '/ulimit -v/d' $PROF_PATH
sed -i '/ulimit -x/d' $PROF_PATH
sed -i '/ulimit -s/d' $PROF_PATH
echo "ulimit -c unlimited" | tee -a $PROF_PATH
echo "ulimit -d unlimited" | tee -a $PROF_PATH
echo "ulimit -f unlimited" | tee -a $PROF_PATH
echo "ulimit -i unlimited" | tee -a $PROF_PATH
echo "ulimit -l unlimited" | tee -a $PROF_PATH
echo "ulimit -m unlimited" | tee -a $PROF_PATH
echo "ulimit -n 1048576" | tee -a $PROF_PATH
echo "ulimit -q unlimited" | tee -a $PROF_PATH
echo "ulimit -s -H 65536" | tee -a $PROF_PATH
echo "ulimit -s 32768" | tee -a $PROF_PATH
echo "ulimit -t unlimited" | tee -a $PROF_PATH
echo "ulimit -u unlimited" | tee -a $PROF_PATH
echo "ulimit -v unlimited" | tee -a $PROF_PATH
echo "ulimit -x unlimited" | tee -a $PROF_PATH
echo
echo -e "${GREEN}System Limits are Optimized.${NC}"
echo
sleep 0.5
}
hawshemi_script(){
clear
echo -e "${MAGENTA}Special thanks to Hawshemi, the author of optimizer script...${NC}"
sleep 2
os_name=$(lsb_release -is)
echo -e
if [ "$os_name" == "Ubuntu" ]; then
echo -e "${GREEN}The operating system is Ubuntu.${NC}"
sleep 1
else
echo -e "${RED} The operating system is not Ubuntu.${NC}"
sleep 2
return
fi
sysctl_optimizations
limits_optimizations
ask_reboot
read -p "Press Enter to continue..."
}
check_core_version() {
local url=$1
local tmp_file=$(mktemp)
curl --max-time 1 -s -o "$tmp_file" "$url"
if [ $? -ne 0 ]; then
colorize red "Failed to check latest core version"
return 1
fi
local file_version=$(head -n 1 "$tmp_file")
local backhaul_version=$($config_dir/backhaul_premium -v)
if [ "$file_version" != "$backhaul_version" ]; then
colorize cyan "New Core version available: $backhaul_version => $file_version" bold
fi
rm "$tmp_file"
}
check_script_version() {
local url=$1
local tmp_file=$(mktemp)
curl --max-time 1 -s -o "$tmp_file" "$url"
if [ $? -ne 0 ]; then
colorize red "Failed to check latest script version"
return 1
fi
local file_version=$(head -n 1 "$tmp_file")
if [ "$file_version" != "$SCRIPT_VERSION" ]; then
colorize cyan "New script version available: $SCRIPT_VERSION => $file_version" bold
fi
rm "$tmp_file"
}
update_script(){
DEST_DIR="/usr/bin/"
BACKHAUL_SCRIPT="backhaul"
SCRIPT_URL="http://79.175.167.114/backhaul.sh"
echo
if [ -f "$DEST_DIR/$BACKHAUL_SCRIPT" ]; then
rm "$DEST_DIR/$BACKHAUL_SCRIPT"
if [ $? -eq 0 ]; then
echo -e "${GREEN}Existing $BACKHAUL_SCRIPT has been successfully removed from $DEST_DIR.${NC}"
else
echo -e "${RED}Failed to remove existing $BACKHAUL_SCRIPT from $DEST_DIR.${NC}"
sleep 1
return 1
fi
else
echo -e "${YELLOW}$BACKHAUL_SCRIPT does not exist in $DEST_DIR. No need to remove.${NC}"
fi
curl -s -L -o "$DEST_DIR/$BACKHAUL_SCRIPT" "$SCRIPT_URL"
echo
if [ $? -eq 0 ]; then
chmod +x "$DEST_DIR/$BACKHAUL_SCRIPT"
colorize yellow "Type 'backhaul' to run the script.\n" bold
colorize yellow "For removing script type: rm -rf /usr/bin/backhaul\n" bold
press_key
exit 0
else
echo -e "${RED}Failed to download $BACKHAUL_SCRIPT from $SCRIPT_URL.${NC}"
sleep 1
return 1
fi
}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'  # No Color
display_menu() {
clear
display_logo
display_server_info
display_backhaul_core_status
echo
colorize green " 1. Configure a new tunnel [IPv4/IPv6]" bold
colorize red " 2. Tunnel management menu" bold
colorize cyan " 3. Check tunnels status" bold
echo -e " 4. Optimize network & system limits"
echo -e " 5. Update & Install Backhaul Core"
echo -e " 6. Update & install script"
echo -e " 7. Remove Backhaul Core"
echo -e " 0. Exit"
echo
echo "-------------------------------"
}
read_option() {
read -p "Enter your choice [0-7]: " choice
case $choice in
1) configure_tunnel ;;
2) tunnel_management ;;
3) check_tunnel_status ;;
4) hawshemi_script ;;
5) download_and_extract_backhaul "menu";;
6) update_script ;;
7) remove_core ;;
0) exit 0 ;;
*) echo -e "${RED} Invalid option!${NC}" && sleep 1 ;;
esac
}
while true
do
display_menu
read_option
done
