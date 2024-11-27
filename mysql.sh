config_file="/etc/mysql/mysql.conf.d/mysqld.cnf"
config_line="performance_schema = off"

if grep -q -E "^[^#]*\s*performance_schema\s*=" "$config_file"; then
    if grep -q -E "^[^#]*\s*performance_schema\s*=\s*on" "$config_file"; then
        sudo sed -i 's/^\([^#]*performance_schema\s*=\s*\)on/\1off/' "$config_file"
        echo "Updated configuration: 'performance_schema = off'."
    else
        echo "The configuration line already exists in the file with the correct value."
    fi
else
    if grep -q "#\s*performance_schema\s*=" "$config_file"; then
        sudo sed -i 's/#\s*performance_schema\s*=.*/performance_schema = off/' "$config_file"
        echo "Uncommented and set configuration: 'performance_schema = off'."
    else
        echo "$config_line" | sudo tee -a "$config_file" > /dev/null
        echo "Added configuration: 'performance_schema = off'."
    fi
fi

MYSQL_USER="root"         

sudo mysql -u "$MYSQL_USER" <<EOF
CREATE DATABASE IF NOT EXISTS stream_data;

USE stream_data;

CREATE TABLE IF NOT EXISTS data (
  id INT AUTO_INCREMENT PRIMARY KEY,
  time DATETIME NOT NULL,
  app VARCHAR(50) NOT NULL,
  stream VARCHAR(50) NOT NULL,
  requests INT NOT NULL,
  unique_users INT NOT NULL,
  data_sent BIGINT NOT NULL
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
