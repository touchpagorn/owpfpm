# Stage 1: Build extensions
FROM php:8.3-fpm-alpine AS builder

ENV TIMEZONE=Asia/Bangkok

# ใช้สคริปต์ช่วยติดตั้ง Extension เพื่อความแม่นยำและลดข้อผิดพลาดเรื่อง dependencies
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions \
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

# Stage 2: Final image
FROM php:8.3-fpm-alpine

ENV TIMEZONE=Asia/Bangkok

# เปิดใช้งาน community repository สำหรับพวกแอปพลิเคชันทั่วไป
RUN sed -i 's/^#\(.*community\)/\1/' /etc/apk/repositories || true \
    && apk update \
    && apk add --no-cache \
        tzdata \
        imagemagick \
        # ติดตั้ง runtime libraries ที่จำเป็น (ปรับปรุงให้เข้ากับ Alpine ยุคใหม่)
        libpng \
        libjpeg-turbo \
        libwebp \
        freetype \
        icu-libs \
        libzip \
        libmemcached \
        libstdc++ \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && (find /etc/ImageMagick* -name "policy.xml" 2>/dev/null | xargs sed -i 's/<policy domain=.*name=.*rights=.*pattern=.*>//g' || true)

# Copy compiled extensions and configs จาก Stage 1
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

WORKDIR /var/www/html
CMD ["php-fpm"]