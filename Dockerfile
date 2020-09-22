FROM php:7.2-fpm-alpine
LABEL maintainer="jaosn <jason@gymoo.com>"
ENV SWOOLE_VERSION 4.3.2
ENV EASYSWOOLE_VERSION 3.x-dev

# timezone
ENV TIMEZONE Asia/Shanghai
RUN apk add --no-cache tzdata \
    && ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && echo $TIMEZONE > /etc/timezone

COPY ./php-fpm/php.ini /usr/local/etc/php/php.ini

# mbstring opcache pdo mysql
RUN docker-php-ext-install mbstring opcache pdo pdo_mysql mysqli

# Swoole extension
RUN wget https://github.com/swoole/swoole-src/archive/v${SWOOLE_VERSION}.tar.gz -O swoole.tar.gz \
    && mkdir -p swoole \
    && tar -xf swoole.tar.gz -C swoole --strip-components=1 \
    && rm swoole.tar.gz \
    && ( \
        cd swoole \
        && phpize \
        && ./configure --enable-async-redis --enable-mysqlnd --enable-openssl --enable-http2 \
        && make -j$(nproc) \
        && make install \
    ) \
    && rm -r swoole \
    && docker-php-ext-enable swoole

# gd zip
RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev \
    && NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
    && docker-php-ext-configure gd \
        --with-gd \
        --with-freetype-dir \
        --with-png-dir \
        --with-jpeg-dir \
        --with-zlib-dir \
    && docker-php-ext-install -j${NPROC} gd zip \
    && docker-php-ext-install -j${NPROC} bcmath \
    && apk del freetype-dev libpng-dev libjpeg-turbo-dev
    
# xlswriter
ENV XLSWRITER_VERSION 1.3.4.1
RUN apk update \
    && apk add --no-cache php7-pear php7-dev zlib-dev re2c gcc g++ make curl \
    && curl -fsSL "https://pecl.php.net/get/xlswriter-${XLSWRITER_VERSION}.tgz" -o xlswriter.tgz \
    && mkdir -p /tmp/xlswriter \
    && tar -xf xlswriter.tgz -C /tmp/xlswriter --strip-components=1 \
    && rm xlswriter.tgz \
    && cd /tmp/xlswriter \
    && phpize && ./configure --enable-reader && make && make install

# redis
ENV PHPREDIS_VERSION 4.0.0RC1
RUN apk add --no-cache curl \
    && curl -L -o /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/$PHPREDIS_VERSION.tar.gz \
    && tar xfz /tmp/redis.tar.gz \
    && rm -r /tmp/redis.tar.gz \
    && mkdir -p /usr/src/php/ext \
    && mv phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis \
    && docker-php-ext-install redis \
    && rm -rf /usr/src/php \
    && apk del curl

# mongo
RUN apk update && apk add autoconf openssl-dev g++ make && \
	pecl channel-update pecl.php.net && \
    pecl install mongodb && \
    docker-php-ext-enable mongodb && \
    pecl install xlswriter && \
    docker-php-ext-enable xlswriter && \
    apk del --purge autoconf openssl-dev g++ make
    
COPY ./php-fpm/docker-php-entrypoint /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-php-entrypoint

# nginx
RUN apk add nginx && mkdir /run/nginx/

COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/nginx.vh.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

WORKDIR /app

ENTRYPOINT ["docker-php-entrypoint"]

CMD ["php-fpm"]