#!/bin/sh
## check if docker-compose exist?

# ตรวจสอบว่ามีการส่งพารามิเตอร์เข้ามาหรือไม่
if [ $# -ne 1 ]; then
  echo "Usage: $0 <your_mariadb_root_password>"
  false
  exit 0
fi
# กำหนดรหัสผ่านจากพารามิเตอร์
mypassword="$1"

# เขียนค่ารหัสผ่าน ไปใน secret file
printf "%s\n" "$mypassword" > ./config/secrets/db_root_password.txt
printf "%s\n" "$mypassword" > ./config/secrets/db_user_password.txt
chmod 400 ./config/secrets/db_root_password.txt
chmod 400 ./config/secrets/db_user_password.txt

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
