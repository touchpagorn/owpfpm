#!/bin/sh

read -s -p "Please enter Database root Password: " root_password
echo ""
read -s -p "Please enter Database user Password: " user_password
echo ""
read -p "Please enter Database name: " db_name

# Create secrets folder if not exists
mkdir -p ./config/secrets

mkdir -p ./config/ssl
openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout ./config/ssl/private.key \
    -out ./config/ssl/sertificate.crt \
    -subj "/C=TH/ST=Chonburi/L=Na Kluea/O=Touchpagorn/OU=Dev/CN=localhost"

    
# เขียนค่าลงไฟล์
printf "%s\n" "$root_password" > ./config/secrets/db_root_password.txt
printf "%s\n" "$user_password" > ./config/secrets/db_user_password.txt
printf "%s\n" "$db_name"       > ./config/secrets/db_name.txt

## check if docker-compose exist?
chmod 400 ./config/secrets/db_root_password.txt
chmod 400 ./config/secrets/db_user_password.txt
chmod 400 ./config/secrets/db_name.txt

#sed -i "s/MARIADB_ROOT_PASSWORD=.*/MARIADB_ROOT_PASSWORD=$mypassword/" docker-compose.yml
#sed -i "s/MARIADB_PASSWORD=.*/MARIADB_PASSWORD=$mypassword/" docker-compose.yml

compose=$(which docker compose)
if [ -z "$compose" ]; then
  echo "docker compose not installed,"
  echo "follow this https://docs.docker.com/compose/install/ to install it first."
  exit 1
else
  if [ ! -x "$compose" ]; then
     echo "$compose is not executable,"
     echo "follow this https://docs.docker.com/compose/install/ to complete an installation"
     exit 1
  fi
fi
echo "Download latest WordPress..."
wget -O - https://wordpress.org/latest.tar.gz | tar zxv
mv wordpress html
cp config/source/index.html html/index.html

echo "Create a WordPress service."
docker compose up -d
#mypassword=$(grep MYSQL_ROOT_PASSWORD docker-compose.yml|awk -F\= '{print $2}')


docker exec web sh -c "chown -R www-data:www-data /var/www/html"


echo "done..."

echo "====================="
echo "WordPress site: $(hostname -I|awk '{print "http://"$1":8888"}')"
echo "[Database info]"
echo "db:   wordpress"
echo "host: db"
echo "user: root"
echo "pass: $mypassword"
echo "====================="

echo "Remove install.sh script."
#rm -f ./install.sh
