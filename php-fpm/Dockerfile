# Stage 1: Build extensions
FROM php:8.2-fpm-alpine AS builder

ENV TIMEZONE=Asia/Bangkok

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
        autoconf gcc g++ make pkgconfig \
        libjpeg-turbo-dev libpng-dev libwebp-dev freetype-dev \
        icu-dev libzip-dev libxml2-dev curl-dev oniguruma-dev \
        imagemagick-dev libmemcached-dev openssl-dev \
    && apk add --no-cache tzdata imagemagick \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && docker-php-ext-configure gd \
        --with-jpeg \
        --with-webp \
        --with-freetype \
    && docker-php-ext-install -j$(nproc) \
        gd pdo_mysql opcache sockets mysqli calendar intl exif zip mbstring \
    && pecl install redis mongodb memcached imagick \
    && docker-php-ext-enable redis mongodb memcached imagick

# Stage 2: Final image
FROM php:8.2-fpm-alpine

ENV TIMEZONE=Asia/Bangkok

# Runtime dependencies only
RUN apk add --no-cache \
        tzdata imagemagick \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && find /etc/ImageMagick* -name "policy.xml" -exec sed -i 's/<policy domain=.*name=.*rights=.*pattern=.*>//g' {} +

# Copy compiled extensions from builder
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Optional: Copy custom config
COPY ./config/php.ini /usr/local/etc/php/php.ini
COPY ./config/www.conf /usr/local/etc/php-fpm.d/www.conf

WORKDIR /var/www/html
CMD ["php-fpm"]