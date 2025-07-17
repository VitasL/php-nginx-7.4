FROM php:7.4-fpm-alpine

LABEL maintainer="jaosn <jason@gymoo.com>"


# timezone
ENV TIMEZONE Asia/Shanghai
RUN apk add --no-cache tzdata \
    && ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && echo $TIMEZONE > /etc/timezone

COPY ./php-fpm/php.ini /usr/local/etc/php/php.ini

# mbstring opcache pdo mysql
RUN docker-php-ext-install mbstring opcache pdo pdo_mysql mysqli

# gd zip
RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev gmp gmp-dev libjpeg-turbo-dev \
    && NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
    && docker-php-ext-configure gd \
        --with-gd \
        --with-freetype-dir \
        --with-png-dir \
        --with-jpeg-dir \
        --with-zlib-dir \
    && docker-php-ext-install -j${NPROC} gd zip \
    && docker-php-ext-install -j${NPROC} bcmath \
    && docker-php-ext-install -j${NPROC} gmp \
    && apk del freetype-dev libpng-dev libjpeg-turbo-dev

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

# ffmpeg
RUN apk add yasm && apk add ffmpeg

COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/nginx.vh.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

WORKDIR /app

ENTRYPOINT ["docker-php-entrypoint"]

CMD ["php-fpm"]
