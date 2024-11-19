sudo timedatectl set-timezone Asia/Ho_Chi_Minh

interface=$(ip -4 -o addr show up primary scope global | awk '{print $2}' | head -n 1)
if [ -z "$interface" ]; then
    echo "Can not detect Internet interface."
    exit 1
fi

mac_address=$(ip link show "$interface" | awk '/ether/ {print $2}' | sed 's/://g')

if [ -z "$mac_address" ]; then
    echo "Can not get MAC address at $interface."
    exit 1
fi

current_hostname=$(hostname)

if [ "$current_hostname" == "$mac_address" ]; then
    echo "Hostname has changed before."
else
    sudo hostnamectl set-hostname "$mac_address"
    sudo sed -i "s/127.0.1.1.*/127.0.1.1 $mac_address/" /etc/hosts
    echo "Hostname is changed to $mac_address (at: $interface)"
fi

sudo apt update -y
sudo apt install jq bmon net-tools libnginx-mod-rtmp php-fpm php  mysql-server python3 python3-watchdog python3-mysql.connector libssl-dev python3-flask-sqlalchemy python3-flask-bcrypt python3-pandas python3-python-flask-jwt-extended -y
sudo apt remove apache2 -y
bash mysql.sh
bash
