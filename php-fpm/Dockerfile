FROM php:8.2-fpm-bookworm

ENV TIMEZONE=Asia/Bangkok

RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata libjpeg-dev libpng-dev libwebp-dev libzip-dev libicu-dev \
        libmemcached-dev libssl-dev libcurl4-openssl-dev libxml2-dev libonig-dev \
        libfreetype-dev pkg-config libmagickwand-dev libmagickcore-dev imagemagick \
    && find /etc/ImageMagick* -name "policy.xml" -exec sed -i 's/<policy domain=.*name=.*rights=.*pattern=.*>//g' {} + \
    && ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo "${TIMEZONE}" > /etc/timezone \
    && docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
    && docker-php-ext-install -j"$(nproc)" \
        gd pdo_mysql opcache sockets mysqli calendar intl exif zip mbstring \
    && pecl install redis mongodb memcached imagick \
    && docker-php-ext-enable redis mongodb memcached imagick \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./config/php.ini /usr/local/etc/php/php.ini
COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf

WORKDIR /var/www/html
CMD ["php-fpm"]