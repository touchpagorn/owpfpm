# Stage 1: Build OpenResty
FROM alpine:3.22 AS openresty-builder

ARG OPENRESTY_VERSION=1.21.4.1
ENV OPENRESTY_PREFIX=/opt/openresty

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
