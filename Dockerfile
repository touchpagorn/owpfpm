# Stage 1: Build OpenResty
FROM debian:bookworm-slim AS openresty-builder

ARG OPENRESTY_VERSION=1.21.4.1
ARG USE_THAI_MIRROR=TRUE
ENV OPENRESTY_PREFIX=/opt/openresty


# สร้าง sources.list ใหม่แบบ minimal ด้วย mirror ไทย

RUN echo "deb http://mirror.kku.ac.th/debian bookworm main\n\
deb http://mirror.kku.ac.th/debian bookworm-updates main\n\
deb http://mirror.kku.ac.th/debian-security bookworm-security main" > /etc/apt/sources.list

# ติดตั้งแพ็กเกจที่จำเป็น
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*


# Install build dependencies, download, compile, and clean up in a single RUN command
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential curl wget ca-certificates \
        libpcre3-dev libssl-dev zlib1g-dev libreadline-dev libncurses-dev perl \
    && mkdir -p /root/ngx_openresty \
    && cd /root/ngx_openresty \
    && wget -O ngx_cache_purge.tar.gz https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.tar.gz \
    && wget -O openresty.tar.gz https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz \
    && tar -zxvf ngx_cache_purge.tar.gz \
    && tar -xzvf openresty.tar.gz \
    && cd openresty-${OPENRESTY_VERSION} \
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
    && make -j"$(nproc)" && make install \
    && apt-get purge -y build-essential curl wget perl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /root/ngx_openresty

# Stage 2: PHP-FPM + OpenResty runtime
FROM php:8.2-fpm-bookworm

ENV TIMEZONE=Asia/Bangkok
ENV OPENRESTY_PREFIX=/opt/openresty
ENV NGINX_PREFIX=/opt/openresty/nginx
ENV NGINX_CONF=/opt/openresty/nginx/conf
ENV VAR_PREFIX=/opt/openresty/nginx/var
ENV VAR_LOG_PREFIX=/opt/openresty/nginx/logs

# Install ALL dependencies and extensions in a single RUN layer for efficiency
RUN apt-get update && apt-get install -y --no-install-recommends \
        # OpenResty runtime dependencies (to fix shared library error)
        libpcre3 zlib1g libreadline8 libncurses6 \
        # System utilities
        tzdata bash curl wget unzip git imagemagick ghostscript \
        # PHP extension dependencies
        libjpeg-dev libpng-dev libwebp-dev libzip-dev libicu-dev \
        libmemcached-dev libssl-dev libcurl4-openssl-dev libxml2-dev libonig-dev \
        libfreetype-dev pkg-config libmagickwand-dev libmagickcore-dev \
    # Relax ImageMagick's security policy to allow PECL to build the extension.
    && find /etc/ImageMagick* -name "policy.xml" -exec sed -i 's/<policy domain=.*name=.*rights=.*pattern=.*>//g' {} + \
    # Set timezone
    && ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo "${TIMEZONE}" > /etc/timezone \
    # Configure and install PHP extensions
    && docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
    && docker-php-ext-install -j"$(nproc)" \
        gd pdo_mysql opcache sockets mysqli calendar intl exif zip mbstring \
    # Install PECL extensions
    && pecl install redis mongodb memcached imagick \
    && docker-php-ext-enable redis mongodb memcached imagick \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy OpenResty from builder
COPY --from=openresty-builder /opt/openresty /opt/openresty

# Create symlinks for OpenResty binaries
RUN ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
    && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
    && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
    && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit $OPENRESTY_PREFIX/luajit/bin/lua \
    && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit /usr/local/bin/lua

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create necessary directories and set up default page
RUN mkdir -p /var/www/html $VAR_PREFIX/client_body_temp $VAR_PREFIX/proxy_temp $VAR_PREFIX/fastcgi_temp \
    && echo '<?php if(isset($_REQUEST["printinfo"])) phpinfo(); else echo "<a href=\"/?printinfo\">see phpinfo()</a>"; ?>' > /var/www/html/index.php

# Copy configurations
COPY ./config/nginx.conf $NGINX_CONF/nginx.conf
COPY ./config/php.ini /usr/local/etc/php/php.ini
COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /var/www/html

EXPOSE 80
ENTRYPOINT ["bash", "/start.sh"]