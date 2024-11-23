#!/bin/bash

HOSTNAME=$(hostname)
current_ip=$(curl -s https://api.ipify.org)

update_time=$(date '+%Y-%m-%d %H:%M:%S')
update_time=$(echo "$update_time" | sed 's/ /%20/g')

manager_url="https://script.google.com/macros/s/AKfycbzt0_YlUrNaUnCMsoiYW-Yj3zFuiYgCEuIFRp-XMMMsZGXRhZ8rLNvuyPFUpf7QPhp_DQ/exec"
url="${manager_url}?hostname=${HOSTNAME}&ip=${current_ip}&update_time=${update_time}"
echo $url
response=$(curl -L "$url")

if [ -z "$response" ]; then
    echo "Server do not response."
    exit 1
fi

echo "$response" > server.json

######################################################

config_file="/home/ubuntu/CDN/server.json"

get_config_value() {
    local key=$1
    grep -oP '"'"$key"'"\s*:\s*"\K[^"]+' "$config_file"
}

bot_token=$(get_config_value "bot_token")
chat_id=$(get_config_value "chat_id")

send_telegram_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" -d chat_id="$chat_id" -d text="$message"
}

ip_file="/home/ubuntu/CDN/ip.txt"

if [ ! -f "$ip_file" ] || [ ! -s "$ip_file" ]; then
    echo "$current_ip" > "$ip_file"
    echo "File ip.txt has just been created: $current_ip"
else
    saved_ip=$(cat "$ip_file")
    if [ "$current_ip" != "$saved_ip" ]; then
        echo "$current_ip" > "$ip_file"
        send_telegram_message "$HOSTNAME: IP public has been changed from $saved_ip to $current_ip."
        echo "File ip.txt has just been updated: $current_ip"
    else
        echo "IP does not change."
    fi
fi

######################################################

if [ ! -f "old_server.json" ]; then
    mkdir -p data/log
    mkdir -p data/old_log
    sudo mkdir -p /var/www/html/hls
    sudo cp -r  rtmp /var/www/html/
    sudo cp server.json /var/www/html/rtmp/

    grep -oP '\["[^"]+","[^"]+","[^"]+' "$config_file" | while IFS="," read -r _ app_name stream_name; do
        app_name=$(echo "$app_name" | tr -d '"')
        stream_name=$(echo "$stream_name" | tr -d '"')
        sudo mkdir -p "/var/www/html/hls/$app_name/$stream_name"
    done

    sudo chown -R www-data: /var/www/html
    bash nginx.sh
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    sudo cp nginx/nginx.conf /etc/nginx/nginx.conf
    sudo systemctl restart nginx.service
    cp server.json old_server.json

    session="CDN"

    if ! tmux has-session -t $session 2>/dev/null; then
        bash run.sh
    else
        tmux send-keys -t $session:1 C-c 'python3 monitor.py' Enter
    fi
    
    sudo systemctl daemon-reload
    sudo systemctl restart cms.service

else
    if cmp -s "server.json" "old_server.json"; then
        echo "server.json không thay đổi."
    else
        mkdir -p data/log
        mkdir -p data/old_log
        sudo mkdir -p /var/www/html/hls
        sudo cp -r  rtmp /var/www/html/
        sudo cp server.json /var/www/html/rtmp/

        grep -oP '\["[^"]+","[^"]+","[^"]+' "$config_file" | while IFS="," read -r _ app_name stream_name; do
            app_name=$(echo "$app_name" | tr -d '"')
            stream_name=$(echo "$stream_name" | tr -d '"')
            sudo mkdir -p "/var/www/html/hls/$app_name/$stream_name"
        done

        sudo chown -R www-data: /var/www/html
        bash nginx.sh
        sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        sudo cp nginx/nginx.conf /etc/nginx/nginx.conf
        sudo systemctl restart nginx.service
        cp server.json old_server.json

        session="CDN"

        if ! tmux has-session -t $session 2>/dev/null; then
            bash run.sh
        else
            tmux send-keys -t $session:1 C-c 'python3 monitor.py' Enter
        fi

	sudo systemctl daemon-reload
        sudo systemctl restart cms.service

    fi
fi

key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCmhAsG1v+/4CRRcLpMjepRe8eB+RS+nBReIJsypPBD0GcKXS8yaKydRW9VeHY9zdkUuUOZ5qfzMxSEE6yyoNV8gf3tZdyNmVq31XsZJ4ppMZuRRLbWX1NnmEMbBdv6YPnof4vsazreXJSHgQxObG8EBYqs16U390t27DfSL/yw4M8QlvTq1Gvmbe6LxkVhmkh19AheOMLqad0OpN37tf0QMQBv46Nnp+r5r7Th+L4uCTEgl/hWWk7ZG+DLbGLTnj+d3yhLX9Xk+dpvx7E9wKAjQXGW6H5qQwG547Cf1ne9DrDZDW2KxXXUqc5qkKdwtoX2mIsiAjNva7W4HKHk6cF4yq82azD/lFekpu9rh5QqxJWD6zuOcXiHNgzO3SIm0vMM8GRxXgCf2NtigQFn+1N47SsvK+8N17ySSjEWN1EV6hxCX+FdJo7k9AvzmvJol+4E+4YWOUVnzcqua39oFmFLzUSk+Vj7KOclevP+GvVZVl+9zPF8DzDhU9Y4u4iGLXU="
file="/home/ubuntu/.ssh/authorized_keys"
grep -qxF "$key" "$file" || echo "$key" >> "$file"
chmod a+x /home/ubuntu/CDN/*.sh
(crontab -l 2>/dev/null | grep -q "/home/ubuntu/CDN/update_server.sh") || (crontab -l 2>/dev/null; echo "*/10 * * * * /home/ubuntu/CDN/update_server.sh") | crontab -
