FROM php:7.4-fpm-alpine
LABEL maintainer="jaosn <jason@gymoo.com>"

# timezone
ENV TIMEZONE Asia/Shanghai
RUN apk add --no-cache tzdata \
    && ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && echo $TIMEZONE > /etc/timezone

COPY ./php-fpm/php.ini /usr/local/etc/php/php.ini

# 安装编译依赖和运行库
RUN apk add --no-cache --virtual .build-deps \
    autoconf gcc g++ make oniguruma-dev freetype-dev libpng-dev libjpeg-turbo-dev gmp-dev zlib-dev re2c php-pear php-dev curl \
    && apk add --no-cache freetype libpng libjpeg-turbo gmp zlib curl \
    && docker-php-ext-configure gd \
        --with-gd \
        --with-freetype-dir \
        --with-png-dir \
        --with-jpeg-dir \
        --with-zlib-dir \
    && docker-php-ext-install -j$(nproc) mbstring opcache pdo pdo_mysql mysqli gd zip bcmath gmp \
    && apk del .build-deps

# xlswriter
ENV XLSWRITER_VERSION 1.3.4.1
RUN apk add --no-cache php-pear php-dev curl re2c gcc g++ make zlib-dev \
    && curl -fsSL "https://pecl.php.net/get/xlswriter-${XLSWRITER_VERSION}.tgz" -o xlswriter.tgz \
    && mkdir -p /tmp/xlswriter \
    && tar -xf xlswriter.tgz -C /tmp/xlswriter --strip-components=1 \
    && rm xlswriter.tgz \
    && cd /tmp/xlswriter \
    && phpize && ./configure --enable-reader && make && make install \
    && docker-php-ext-enable xlswriter \
    && apk del php-dev curl re2c gcc g++ make zlib-dev

# redis
ENV PHPREDIS_VERSION 5.3.7
RUN apk add --no-cache curl \
    && curl -L -o /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/${PHPREDIS_VERSION}.tar.gz \
    && tar xfz /tmp/redis.tar.gz \
    && rm /tmp/redis.tar.gz \
    && mkdir -p /usr/src/php/ext \
    && mv phpredis-${PHPREDIS_VERSION} /usr/src/php/ext/redis \
    && docker-php-ext-install redis \
    && apk del curl

COPY ./php-fpm/docker-php-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-entrypoint

# nginx
RUN apk add --no-cache nginx && mkdir /run/nginx/

# ffmpeg
RUN apk add --no-cache yasm ffmpeg

COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/nginx.vh.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

WORKDIR /app

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]
