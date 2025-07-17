FROM php:7.4-fpm-alpine
LABEL maintainer="jaosn <jason@gymoo.com>"


# timezone
ENV TIMEZONE Asia/Shanghai
RUN apk add --no-cache tzdata \
    && ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && echo $TIMEZONE > /etc/timezone

COPY ./php-fpm/php.ini /usr/local/etc/php/php.ini
RUN echo 'nameserver 114.114.114.114' > /etc/resolv.conf \
    # 修改源
    && sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk add --no-cache \
        freetds-dev \
        freetype \
        libzip \
        libmcrypt \
        libpng \
        libwebp \
        libjpeg-turbo \
    && apk add --no-cache --virtual build-apks \
        autoconf make gcc \
        libc-dev \
        zlib-dev \
        bzip2-dev \
        libzip-dev \
        libmcrypt-dev \
        libxml2-dev \
        libpng-dev \
        libwebp-dev \
        libjpeg-turbo-dev \
        freetype-dev \
    && cd /usr/local/etc/php \
    && cp php.ini-production php.ini \
    # 安装扩展
    && docker-php-ext-configure gd --with-webp --with-jpeg --with-freetype \
    && docker-php-ext-install -j$(nproc) mysqli pdo_mysql pdo_dblib gd sockets soap

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
