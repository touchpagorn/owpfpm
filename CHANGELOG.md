# บันทึกการเปลี่ยนแปลง (Changelog)

การเปลี่ยนแปลงที่สำคัญทั้งหมดในโปรเจกต์นี้จะถูกบันทึกไว้ในไฟล์นี้

## [Web Server / php-fpm / Database] - 2026-11-19

### ⚠️ Breaking Change: เปลี่ยนจาก Build OpenResty เองมาใช้ Official Image
- **เลิก build OpenResty จาก source**: ลบ `openresty/Dockerfile` (เดิม build จาก `debian:bookworm-slim` + compile OpenResty `1.31.8.1` พร้อมโมดูล `ngx_cache_purge`) แล้วเปลี่ยน service `web` ใน `docker-compose.yml` ไปใช้ `openresty/openresty:1.31.8.1-bookworm` จาก Docker Hub แทน
  - ลดเวลา build และไม่ต้องติดตั้ง toolchain (`build-essential`, `perl`, ฯลฯ) อีกต่อไป
  - ได้รับ security patch ของ base image ตามรอบ release ของ OpenResty โดยตรง
- **เปลี่ยน prefix ของ OpenResty** จาก `/opt/openresty` เป็น `/usr/local/openresty` (ค่ามาตรฐานของ official image) ส่งผลกับ:
  - volume mount ทั้งหมดของ service `web` ใน `docker-compose.yml` (SSL cert/key, `nginx.conf`, โฟลเดอร์ `owpfpm`, logs)
  - `ssl_certificate` / `ssl_certificate_key` ใน `openresty/config/owpfpm/ssl_common.conf` และ `ssl_enabled.conf`
  - `include` และ `lua_package_path` ใน `openresty/config/nginx.conf.template` (และไฟล์ `nginx.conf` ที่ generate แล้วในเครื่อง)
- **โมดูล `ngx_cache_purge` ไม่มีใน official image แล้ว**: ถ้ามีการใช้ `fastcgi_cache_purge` / `proxy_cache_purge` หรือปลั๊กอิน WordPress ที่ purge cache ผ่าน nginx (เช่น Nginx Helper แบบ purge URL) จะใช้งานไม่ได้ (คอนฟิกใน repo ปัจจุบันไม่ได้ใช้)
- **`build.sh`** เปลี่ยนจาก `docker compose build --no-cache web` เป็น `docker compose pull web`
- `nginx.conf` ไม่ได้ถูก `COPY` เข้า image แล้ว ต้อง mount ผ่าน volume เท่านั้น (ตั้งไว้แล้วใน `docker-compose.yml`)

### การอัปเดตเวอร์ชัน
- **OpenResty**: `1.25.3.2` → `1.31.8.1` (`ngx_cache_purge` `2.5.1` → `2.5.3` และ `libpcre3-dev` → `libpcre2-dev` ก่อนย้ายไปใช้ official image)
- **PHP-FPM**: `php:8.3-fpm-alpine` → `php:8.3.36-fpm-alpine` (pin เวอร์ชันเพื่อแก้ช่องโหว่ PHP2Shell)
- **MariaDB**: `11.8.2` → `11.8.9`

### ความปลอดภัย
- **`php.ini`**: เพิ่ม `session.upload_progress.enabled = 0` เพื่อลดความเสี่ยงจาก CVE-2026-115560 / PHP2Shell
- **`nginx.conf.template`**: comment บรรทัด `location = /wp-admin/install.php { deny all; }` ไว้ เพื่อให้รันตัวติดตั้ง WordPress ได้ — **หลังติดตั้งเสร็จต้องเอา comment ออก** เพื่อป้องกันการติดตั้งซ้ำ

### ขั้นตอน Migration (Build เอง → Official OpenResty Image)

> **คำเตือน:** ห้ามใช้ `build.sh` กับเครื่องที่มีข้อมูลจริง เพราะสคริปต์รัน `docker compose down --volumes` และ `docker system prune --all --volumes` ซึ่งจะ **ลบ volume `mariadb_data` และ `redis_data` ทิ้งทั้งหมด** ให้ใช้ขั้นตอนด้านล่างแทน ซึ่งจะ restart เฉพาะ service `web`

1. **สำรองไฟล์คอนฟิกที่ไม่ได้อยู่ใน git** (ไฟล์เหล่านี้ถูก `.gitignore` ไว้ และ `git pull` จะไม่แก้ให้)
   ```sh
   mkdir -p backup/openresty
   cp openresty/config/nginx.conf backup/openresty/
   cp openresty/config/owpfpm/security_headers.local.conf backup/openresty/ 2>/dev/null
   cp -r config/ssl backup/
   ```

2. **ดึงโค้ดเวอร์ชันใหม่**
   ```sh
   git pull
   ```

3. **อัปเดต path ใน `nginx.conf` ที่ generate ไว้แล้ว** (สร้างจาก template ตอนรัน `install.sh` จึงยังเป็น path เดิม)
   ```sh
   sed -i 's#/opt/openresty#/usr/local/openresty#g' \
       openresty/config/nginx.conf \
       openresty/config/owpfpm/security_headers.local.conf
   ```
   หรือจะ generate ใหม่จาก `nginx.conf.template` ก็ได้ แต่ต้องใส่ค่า domain และ customization เดิมกลับเข้าไปเอง

4. **ตรวจว่าไม่เหลือ path เก่า** — คำสั่งนี้ต้องไม่แสดงผลลัพธ์ใด ๆ
   ```sh
   grep -rn "/opt/openresty" openresty/config docker-compose.yml
   ```
   ถ้ามีคอนฟิกที่ใช้ `fastcgi_cache_purge` / `proxy_cache_purge` ให้นำออก เพราะ official image ไม่มีโมดูลนี้

5. **หยุดและลบ container/image ตัวเก่าที่ build เอง**
   ```sh
   docker compose stop web
   docker compose rm -f web
   docker image ls | grep -- -web      # หา image ที่ build เอง (ชื่อปกติคือ <ชื่อโปรเจกต์>-web เช่น owpfpm-web)
   docker image rm owpfpm-web          # เปลี่ยนชื่อให้ตรงกับผลลัพธ์ด้านบน
   ```

6. **ดึง official image และเริ่ม service `web` ใหม่** (ไม่กระทบ `php-fpm`, `db`, `redis`)
   ```sh
   docker compose pull web
   docker compose up -d --no-deps web
   ```

7. **ตรวจสอบหลัง migrate**
   ```sh
   docker compose exec web openresty -t      # ตรวจ syntax คอนฟิก
   docker compose exec web openresty -V      # ดูเวอร์ชันและโมดูลที่ build มา
   docker compose logs --tail=50 web         # ต้องไม่มี error เรื่อง open() failed / No such file
   curl -I https://<your-domain>/            # ต้องได้ 200/301/302 และมี security headers
   ```
   และทดสอบเข้าหน้า `/wp-admin/` ล็อกอินได้ตามปกติ

8. **ล้างข้อมูลที่ไม่ใช้แล้ว** (ทำหลังยืนยันว่าทุกอย่างทำงานปกติ)
   ```sh
   docker image prune -f                     # ลบเฉพาะ dangling image ไม่แตะ volume
   ```

#### Rollback (กรณีมีปัญหา)
```sh
git checkout 621d85b -- docker-compose.yml openresty/ build.sh   # คืนค่า Dockerfile และ path /opt/openresty
cp backup/openresty/nginx.conf openresty/config/nginx.conf
docker compose up -d --no-deps --build web
```
เมื่อแก้ปัญหาเสร็จแล้วให้คืนไฟล์กลับเป็นเวอร์ชันล่าสุดด้วย `git checkout HEAD -- docker-compose.yml openresty/ build.sh`

## [ทั่วไป / Web Server / php-fpm] - 2026-07-01

### การแก้ไขและปรับปรุง Extension ของ PHP
- **แก้ไขปัญหาการโหลด PHP Extensions (GD, Redis, MongoDB, Imagick, etc.)**:
  - เปลี่ยนโครงสร้าง Dockerfile ของ `php-fpm` จาก Multi-stage build ที่เกิดปัญหาสิทธิ์และไดนามิกไลบรารีไม่ครบถ้วน เป็นการติดตั้งผ่าน `install-php-extensions` โดยตรงในคอนเทนเนอร์หลัก
  - นำเข้าเครื่องมือติดตั้ง `install-php-extensions` จากอิมเมจ `mlocati/php-extension-installer:latest` แทนการดาวน์โหลดผ่านเครือข่าย เพื่อป้องกันปัญหา Timeout และเพิ่มความเร็วในการบิลด์
  - ทำให้ Extension ต่าง ๆ โดยเฉพาะ GD (และไลบรารีเสริมอื่น ๆ) สามารถทำงานได้อย่างถูกต้องและไม่มี Warning ตอนเริ่มทำงานของ PHP-FPM

### การปรับปรุงความปลอดภัยและนโยบาย Content Security Policy (CSP)
- **เพิ่ม Content-Security-Policy (CSP) Header ใน Web Server**:
  - กำหนดนโยบาย CSP ใน [security_headers.conf]
  - เพิ่มความยินยอมให้ใช้ `'unsafe-inline'` และ `'unsafe-eval'` ใน `script-src` ของนโยบาย เพื่อรักษาความสามารถในการทำงานของสคริปต์หลักในระบบ WordPress (เช่น Gutenberg Editor, AJAX, jQuery และฟีเจอร์อื่นๆ) ให้ไม่ถูกเว็บบราว์เซอร์บล็อกการประมวลผลคำสั่งที่เป็น string หรือ inline scripts

### การแก้ไขข้อผิดพลาด FastCGI & PHP Configuration
- **แก้ไขข้อผิดพลาด Passing INI directive through FastCGI (unable to set 'mysql.connect_timeout')**:
  - แนะนำการแก้ไขการกำหนดค่าใน [nginx.conf] โดยเปลี่ยนการเรียกใช้ค่าคอนฟิก `mysql.connect_timeout` (ซึ่งไม่มีอยู่แล้วใน PHP 8.x) ให้เป็น `mysqli.connect_timeout` หรือนำออก เนื่องจากใน PHP 8.3 โครงสร้างส่วนเชื่อมต่อฐานข้อมูลได้ตัดโมดูล `mysql` ตัวเก่าออกไปแล้ว คงเหลือเพียง `mysqli` และ `pdo_mysql` เท่านั้น

## [ทั่วไป] - 2026-06-21

### การยกระดับความปลอดภัย (ผ่านเกณฑ์มาตรฐาน CIS Benchmark)

#### ส่วนของ Docker & Orchestration (`docker-compose.yml`)
- **การจำกัดทรัพยากร (Resource Limits)**: กำหนดขีดจำกัดการใช้งาน CPU และ Memory สำหรับทุกบริการ (`web`, `php-fpm`, `db`, `redis`) เพื่อป้องกันการโจมตีประเภท DoS
- **นโยบายการเริ่มทำงานใหม่ (Restart Policy)**: เปลี่ยนนโยบายการทำงานของ Container ใหม่จาก `always` เป็น `"on-failure:5"` เพื่อป้องกันไม่ให้เกิดลูปการบูตเครื่องซ้ำจนทรัพยากรระบบหมดเมื่อเกิดความเสียหาย
- **ความปลอดภัยของฐานข้อมูล MariaDB**: เพิ่มพารามิเตอร์เริ่มต้นการทำงาน `--local-infile=0`, `--skip-symbolic-links` และ `--secure-file-priv=/var/lib/mysql-files` เพื่อปิดการใช้งานฟังก์ชันการโหลดไฟล์และสกัดสิทธิ์ที่มีความเสี่ยงสูง
- **การป้องกันการแก้ไขไฟล์คอนฟิก (Configuration Protection)**: เชื่อมต่อ (Mount) ไฟล์ SSL key, certificate และไฟล์ตั้งค่าต่าง ๆ ของ OpenResty แบบให้อ่านได้อย่างเดียว (`:ro`) เพื่อป้องกันการดัดแปลงแก้ไขหากระบบถูกเจาะผ่าน Worker Process

#### ส่วนของ Web Server (`openresty/config/nginx.conf`)
- **การแยกสิทธิ์โปรเซส (Worker Process Isolation)**: กำหนดให้โปรเซสทำงานภายใต้ User `www-data` ซึ่งไม่มีสิทธิ์พิเศษในระบบ แทนการรันด้วยสิทธิ์ root
- **การบันทึกประวัติการใช้งาน (Access Logging)**: เปิดใช้งานการเก็บบันทึกประวัติการเข้าใช้งานระบบ (`access_log logs/access.log main;`) เพื่อใช้ในการตรวจสอบทางความมั่นคงปลอดภัย (Audit Trail)
- **การป้องกันการโจมตีแบบ Slowloris**: ลดเวลาการรอหมดอายุการเชื่อมต่อจากเดิม `360 วินาที` ลงเหลือค่าที่เหมาะสมเพื่อความปลอดภัย (`client_header_timeout 15`, `client_body_timeout 15`, `keepalive_timeout 60`)
- **การป้องกันการโจมตีประเภท DoS**: จำกัดขนาดการอัปโหลดไฟล์สูงสุดไว้ที่ `512M` (จากเดิมตั้งค่าแบบไม่จำกัด `0`) และจำกัดพื้นที่บัฟเฟอร์ของ Header
- **การจำกัดการเรียกใช้งาน HTTP Methods**: อนุญาตเฉพาะ HTTP Methods ที่จำเป็นต่อแอปพลิเคชันหลักเท่านั้น (`GET`, `POST`, `HEAD`, `OPTIONS`, `PUT`, `DELETE`) และบล็อกคำสั่งที่มีความเสี่ยงอื่น ๆ
- **การจำกัดความถี่การเข้าใช้งาน (Rate Limiting)**: ตั้งค่าการจำกัดความถี่การส่งคำร้องขอเข้าสู่หน้าอ่อนไหว `/wp-login.php` และ `/xmlrpc.php` (สูงสุด 2 คำสั่งต่อวินาที, คิวสะสมสูงสุด 5 คำสั่ง) เพื่อป้องกันการโจมตีแบบ Brute-Force

#### ส่วนของการตั้งค่า PHP-FPM (`php-fpm/config/php.ini`)
- **การซ่อนข้อมูลเวอร์ชัน (Version Masking)**: ปิดการเปิดเผยเวอร์ชันการรันระบบของ PHP ใน HTTP Header ด้วย `expose_php = Off`
- **การปิดฟังก์ชันระบบที่เป็นอันตราย (Dangerous Functions)**: ยกเลิกการเรียกใช้งานฟังก์ชันระบบที่สามารถใช้รันคำสั่ง OS-level ได้ เช่น `exec`, `shell_exec`, `passthru`, `system`, `proc_open`, `popen`, `show_source`, `symlink`
- **การป้องกันการเข้าถึงไฟล์ระบบ (Directory Traversal)**: จำกัดพื้นที่ทำงานของระบบด้วย `open_basedir = /var/www/html:/tmp`
- **การควบคุมการเรียกใช้งานไฟล์ภายนอก (Remote File Inclusion)**: ปิดการทำงานรีโมทโค้ดข้ามเซิร์ฟเวอร์ด้วย `allow_url_include = Off`
- **การยกระดับความปลอดภัยของ Session Cookie**: เปิดแฟล็กความปลอดภัยของคุกกี้ระบบ (`session.cookie_httponly = 1`, `session.cookie_secure = 1`, `session.cookie_samesite = Lax`, `session.use_strict_mode = 1`) เพื่อป้องกันการถูกดักข้อมูลหรือปลอมแปลงเซสชัน

### การพัฒนาสคริปต์ช่วยติดตั้ง (`install.sh`)
- **การสร้างคอนฟิกอัตโนมัติ**: เพิ่มความสามารถในการสร้างไฟล์ `wp-config.php` จากไฟล์ต้นแบบ `wp-config-sample.php` โดยอัตโนมัติในตอนเริ่มติดตั้ง
- **การตั้งค่าเชื่อมต่อฐานข้อมูลอัตโนมัติ**: นำข้อมูลที่ผู้ใช้ป้อนเข้ามาตอนเริ่มรันสคริปต์ (ชื่อฐานข้อมูล, ชื่อผู้ใช้, รหัสผ่าน และ host ที่เป็น `db`) ไปเขียนตั้งค่าในไฟล์ `wp-config.php` ให้อัตโนมัติ
- **การกำหนด Table Prefix เริ่มต้น**: ปรับเปลี่ยนการตั้งค่าชื่อย่อฐานข้อมูลของ WordPress จากค่าเริ่มต้น `wp_` ให้กลายเป็น `wpx_`
- **การตรวจสอบความซ้ำซ้อนการแทรกคอนฟิก Redis**: เพิ่มเงื่อนไขเพื่อเช็คความปลอดภัยก่อนที่จะเขียนคำสั่งตั้งค่า Redis เพื่อไม่ให้เกิดการบันทึกทับซ้อนกรณีที่รันสคริปต์ติดตั้งซ้ำ
