# Stage 1: Build OpenResty
FROM debian:bookworm-slim AS openresty-builder

ARG OPENRESTY_VERSION=1.21.4.1
ENV OPENRESTY_PREFIX=/opt/openresty

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl wget ca-certificates \
    libpcre3-dev libssl-dev zlib1g-dev libreadline-dev libncurses-dev perl \
 && mkdir -p /root/ngx_openresty \
 && cd /root/ngx_openresty \
 && curl -sSL http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz | tar -zxv \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && cd openresty-* \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --add-module=/root/ngx_openresty/ngx_cache_purge-2.3 \
    --with-luajit \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_stub_status_module \
    --with-http_ssl_module \
    --with-http_flv_module \
    --with-http_v2_module \
    --with-http_mp4_module \
    --with-http_sub_module \
    --without-http_ssi_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
 && make -j"$(nproc)" && make install

# Stage 2: PHP-FPM + OpenResty runtime
FROM php:8.2-fpm-bookworm

ENV TIMEZONE=Asia/Bangkok
ENV OPENRESTY_PREFIX=/opt/openresty
ENV NGINX_PREFIX=/opt/openresty/nginx
ENV NGINX_CONF=/opt/openresty/nginx/conf
ENV VAR_PREFIX=/opt/openresty/nginx/var
ENV VAR_LOG_PREFIX=/opt/openresty/nginx/logs

# Install system packages

 RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata bash curl wget unzip git \
    libjpeg-dev libpng-dev libwebp-dev libzip-dev libicu-dev \
    libmemcached-dev libssl-dev imagemagick ghostscript \
    libcurl4-openssl-dev libxml2-dev libonig-dev \
    libfreetype-dev pkg-config   libmagickwand-dev \
 && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
 && echo "${TIMEZONE}" > /etc/timezone



# Install PHP extensions
RUN docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
 && docker-php-ext-install gd pdo_mysql opcache sockets mysqli calendar intl exif zip

# Install PECL extensions
RUN pecl install redis mongodb memcached imagick \
 && docker-php-ext-enable redis mongodb memcached imagick

# Copy OpenResty from builder
COPY --from=openresty-builder /opt/openresty /opt/openresty
RUN ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
 && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit $OPENRESTY_PREFIX/luajit/bin/lua \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit /usr/local/bin/lua

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configs
WORKDIR $NGINX_CONF
COPY ./config/nginx.conf ./nginx.conf
COPY ./config/php.ini /usr/local/etc/php/php.ini
COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./start.sh /start.sh
RUN chmod +x /start.sh

# Default index
RUN mkdir -p /var/www/html \
 && echo '<?php if(isset($_REQUEST["printinfo"])) phpinfo(); ?>' > /var/www/html/index.php \
 && echo '<a href="/?printinfo">see phpinfo()</a>' >> /var/www/html/index.php

EXPOSE 80
ENTRYPOINT ["bash", "/start.sh"]