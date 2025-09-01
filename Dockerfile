# Stage 1: Build OpenResty
FROM alpine:3.22 AS openresty-builder

ARG OPENRESTY_VERSION=1.21.4.1
ENV OPENRESTY_PREFIX=/opt/openresty
RUN sed -i 's/dl-cdn.alpinelinux.org/dl-2.alpinelinux.org/g' /etc/apk/repositories
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories

RUN apk add --no-cache --virtual .build-deps \
    make gcc musl-dev pcre-dev openssl-dev zlib-dev ncurses-dev readline-dev curl perl wget \
 && mkdir -p /root/openresty \
 && cd /root/openresty \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && curl -sSL http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz | tar -zxv \
 && cd openresty-* \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --add-module=/root/openresty/ngx_cache_purge-2.3 \
    --with-luajit \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-http_v2_module \
 && make -j$(nproc) && make install

# Stage 2: PHP-FPM + OpenResty runtime
FROM php:8.3-fpm-alpine3.22

# Timezone
ENV TIMEZONE=Asia/Bangkok
RUN apk add --no-cache tzdata \
 && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
 && echo "${TIMEZONE}" > /etc/timezone

# PHP extensions
RUN apk add --no-cache --virtual .ext-deps \
    libjpeg-turbo-dev libwebp-dev libpng-dev freetype-dev \
    libzip-dev imagemagick-dev icu-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install gd pdo_mysql opcache sockets mysqli calendar intl exif \
 && pecl install redis mongodb memcached imagick zip \
 && docker-php-ext-enable redis mongodb memcached imagick zip intl \
 && apk del .ext-deps

# Copy OpenResty from builder
COPY --from=openresty-builder /opt/openresty /opt/openresty
RUN ln -sf /opt/openresty/nginx/sbin/nginx /usr/local/bin/nginx \
 && ln -sf /opt/openresty/nginx/sbin/nginx /usr/local/bin/openresty \
 && ln -sf /opt/openresty/bin/resty /usr/local/bin/resty \
 && ln -sf /opt/openresty/luajit/bin/luajit /usr/local/bin/lua

# Composer
RUN apk add --no-cache composer bash curl imagemagick ghostscript

# Configs
WORKDIR /opt/openresty/nginx/conf
COPY ./config/nginx.conf ./nginx.conf
COPY ./config/php.ini /usr/local/etc/php/php.ini
COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./start.sh /start.sh
RUN chmod +x /start.sh

# Default index
RUN echo '<?php if(isset($_REQUEST["printinfo"])) phpinfo(); ?>' > /var/www/html/index.php \
 && echo '<a href="/?printinfo">see phpinfo()</a>' >> /var/www/html/index.php

EXPOSE 80 443
ENTRYPOINT ["bash", "/start.sh"]