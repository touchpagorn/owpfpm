FROM debian:bookworm-slim

ARG OPENRESTY_VERSION=1.21.4.1
ENV OPENRESTY_PREFIX=/opt/openresty

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

# Symlink for convenience
RUN ln -sf $OPENRESTY_PREFIX/nginx/sbin/nginx /usr/local/bin/openresty

COPY ./config/nginx.conf $OPENRESTY_PREFIX/nginx/conf/nginx.conf

EXPOSE 80
CMD ["openresty", "-g", "daemon off;"]
