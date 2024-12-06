config_file="/etc/mysql/mysql.conf.d/mysqld.cnf"

check_and_update() {
    local config_key="$1"
    local expected_value="$2"
    local config_line="$config_key = $expected_value"

    if grep -q -E "^\s*$config_key\s*=" "$config_file"; then
        if ! grep -q -E "^\s*$config_key\s*=\s*$expected_value" "$config_file"; then
            sudo sed -i "s|^\(\s*$config_key\s*=\s*\).*|\1$expected_value|" "$config_file"
            echo "Updated configuration: '$config_line'."
        else
            echo "The configuration '$config_line' already exists with the correct value."
        fi
    else
        if grep -q "#\s*$config_key\s*=" "$config_file"; then
            sudo sed -i "s|#\s*$config_key\s*=.*|$config_line|" "$config_file"
            echo "Uncommented and set configuration: '$config_line'."
        else
            echo "$config_line" | sudo tee -a "$config_file" > /dev/null
            echo "Added configuration: '$config_line'."
        fi
    fi
}

check_and_update "performance_schema" "off"
check_and_update "bind-address" "0.0.0.0"
check_and_update "mysqlx-bind-address" "0.0.0.0"
sudo systemctl restart mysql.service

MYSQL_USER="root"         

sudo mysql -u "$MYSQL_USER" <<EOF
CREATE DATABASE IF NOT EXISTS stream_data;

USE stream_data;

CREATE TABLE IF NOT EXISTS data (
  id INT AUTO_INCREMENT PRIMARY KEY,
  time DATETIME NOT NULL,
  server VARCHAR(50) NOT NULL,
  app VARCHAR(50) NOT NULL,
  stream VARCHAR(50) NOT NULL,
  requests INT NOT NULL,
  unique_users INT NOT NULL,
  data_sent BIGINT NOT NULL,
  UNIQUE (time, server, app, stream)
);

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  hashed_password VARCHAR(255) NOT NULL
);

CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'stream';
GRANT ALL PRIVILEGES ON stream_data.* TO 'admin'@'localhost';

ALTER USER 'admin'@'localhost' IDENTIFIED WITH mysql_native_password BY 'stream';

FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "Database and table have been created successfully, user 'admin' has been granted permission."
else
    echo "An error occurred while creating the database or granting permissions."
fi
