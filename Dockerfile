FROM ubuntu:18.04 AS builder
LABEL maintainer="HLXEasy <hlxeasy@gmail.com>"

WORKDIR /opt

RUN apt-get update \
 && apt-get install -y \
    libpcre3 \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    zlib1g \
    golang-go \
    build-essential \
    git \
    curl \
    cmake

# Nginx version must match the version from used ymuski/nginx-quic image!
ENV NGINX_VERSION=1.16.1 \
    CUSTOM_COUNTER_MODULE_VERSION=4.2 \
    ECHO_MODULE_VERSION=0.62 \
    NGINX_CONFIGURE_PARAMS="--prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module"

# Get source archives and build additional modules
RUN curl -O https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz \
 && tar xvzf nginx-$NGINX_VERSION.tar.gz \
 && curl -L -O https://github.com/lyokha/nginx-custom-counters-module/archive/${CUSTOM_COUNTER_MODULE_VERSION}.tar.gz \
 && tar xvzf ${CUSTOM_COUNTER_MODULE_VERSION}.tar.gz \
 && curl -L -O https://github.com/openresty/echo-nginx-module/archive/v${ECHO_MODULE_VERSION}.tar.gz \
 && tar xvzf v${ECHO_MODULE_VERSION}.tar.gz \
 && git clone https://github.com/zserge/jsmn.git \
 && cp jsmn/jsmn.h /usr/include/ \
 && cd nginx-${NGINX_VERSION} \
 && NGX_HTTP_CUSTOM_COUNTERS_PERSISTENCY=yes \
    ./configure \
        --with-compat \
        --add-dynamic-module=../echo-nginx-module-${ECHO_MODULE_VERSION} \
        --add-dynamic-module=../nginx-custom-counters-module-${CUSTOM_COUNTER_MODULE_VERSION} \
        ${NGINX_CONFIGURE_PARAMS} \
 && make modules

# Copy *.so files right onto /opt, so they can get copied onto the target
# image without defining NGINX_VERSION there again
RUN find /opt -name "*.so" -exec cp {} /opt/ \;

# Get image from ymuski and put own modules into it
FROM ymuski/nginx-quic:latest

COPY --from=builder /opt/ngx_http_custom_counters_module.so /usr/lib/nginx/modules/
COPY --from=builder /opt/ngx_http_echo_module.so            /usr/lib/nginx/modules/
#COPY example.nginx.conf                                     /etc/nginx/nginx.conf
