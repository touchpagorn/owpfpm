FROM php:8.3-fpm-alpine

ENV TIMEZONE=Asia/Bangkok

# เปิดใช้งาน community repository สำหรับพวกแอปพลิเคชันทั่วไป
RUN sed -i 's/^#\(.*community\)/\1/' /etc/apk/repositories || true \
    && apk update \
    && apk add --no-cache \
    tzdata \
    imagemagick \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && (find /etc/ImageMagick* -name "policy.xml" 2>/dev/null | xargs sed -i 's/<policy domain=.*name=.*rights=.*pattern=.*>//g' || true)

# ใช้สคริปต์ช่วยติดตั้ง Extension จาก Docker Image แทนการดาวน์โหลดจาก GitHub เพื่อหลีกเลี่ยงปัญหาเครือข่าย/Timeout
COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
    gd \
    pdo_mysql \
    opcache \
    mysqli \
    calendar \
    intl \
    exif \
    zip \
    mbstring \
    redis \
    mongodb \
    memcached \
    imagick

WORKDIR /var/www/html
CMD ["php-fpm"]
