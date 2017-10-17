
FROM php:5.6-fpm

MAINTAINER Florian JUDITH <florian.judith.b@gmail.com>

ENV LIMESURVEY_URL=http://download.limesurvey.org/latest-stable-release/limesurvey2.72.2+171017.tar.gz

RUN apt-get update && \
    apt-get install -yqq --no-install-recommends \
    dnsutils \
    netcat \
    crudini \
    postgresql-client \
    mysql-client \
    git \
    wget \
    bzip2 \
    pwgen \
    zip \
    unzip \
    msmtp \
    php-net-smtp

RUN mkdir -p /usr/src/php/ext

# Install needed php extensions: zip
RUN apt-get install --no-install-recommends -qqy libz-dev && \
    curl -o zip.tgz -SL http://pecl.php.net/get/zip-1.13.5.tgz && \
    tar -xf zip.tgz -C /usr/src/php/ext/ && \
    rm zip.tgz && \
    mv /usr/src/php/ext/zip-1.13.5 /usr/src/php/ext/zip && \
    docker-php-ext-install zip

# Install needed php extensions: memcached
RUN apt-get install --no-install-recommends -yqq libmemcached-dev && \
    curl -o memcached.tgz -SL http://pecl.php.net/get/memcached-2.2.0.tgz && \
    tar -xf memcached.tgz -C /usr/src/php/ext/ && \
    echo extension=memcached.so >> /usr/local/etc/php/conf.d/memcached.ini && \
    rm memcached.tgz && \
    mv /usr/src/php/ext/memcached-2.2.0 /usr/src/php/ext/memcached && \
    docker-php-ext-install memcached

# Install needed php extensions: memcache
RUN curl -o memcache.tgz -SL http://pecl.php.net/get/memcache-3.0.8.tgz && \
    tar -xf memcache.tgz -C /usr/src/php/ext/ && \
    rm memcache.tgz && \
    mv /usr/src/php/ext/memcache-3.0.8 /usr/src/php/ext/memcache && \
    docker-php-ext-install memcache

# Install needed php extensions: ldap
RUN apt-get install --no-install-recommends -yqq php5-ldap libldap2-dev && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
    docker-php-ext-install ldap

# Install needed php extensions: imap
RUN apt-get install --no-install-recommends -yqq php5-imap libssl-dev libc-client2007e-dev libkrb5-dev && \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
    docker-php-ext-install imap

# Install needed php extensions: bz2 
RUN apt-get install --no-install-recommends -yqq libbz2-dev && \
    docker-php-ext-install bz2

# Install needed php extensions: gd
RUN apt-get install --no-install-recommends --fix-missing -yqq libfreetype6-dev libpng12-dev libjpeg62-turbo-dev libzip-dev && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/  && \
    docker-php-ext-install gd

# Install needed php extensions: mysql
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pdo_mysql

# Install needed php extensions: mcrypt
RUN apt-get --no-install-recommends -yqq install re2c libmcrypt-dev && \
    docker-php-ext-install mcrypt

# Install needed php extensions: imagick
RUN apt-get install --no-install-recommends --fix-missing -yqq libmagickwand-dev && \
    pecl install imagick && \
    docker-php-ext-enable imagick

# Setup sendmail for php
RUN touch /etc/msmtprc && \
    mkdir -p /var/log/msmtp && \
    chown -R www-data:adm /var/log/msmtp && \
    touch /etc/logrotate.d/msmtp && \
    rm /etc/logrotate.d/msmtp && \
    echo "/var/log/msmtp/*.log {\n rotate 12\n monthly\n compress\n missingok\n notifempty\n }" > /etc/logrotate.d/msmtp && \
    crudini --set /etc/php5/cli/php.ini "mail function" "sendmail_path" "'/usr/bin/msmtp -t'" && \
    touch /usr/local/etc/php/php.ini && \
    crudini --set /usr/local/etc/php/php.ini "mail function" "sendmail_path" "'/usr/bin/msmtp -t'"

# Clean up
RUN apt-get clean && \
    rm -r /var/lib/apt/lists/*

# Download and install Limesurvey
RUN cd /var/www/html \
    && curl $LIMESURVEY_URL | tar xvz

# Change owner for security reasons
RUN chown -R www-data:www-data /var/www/html/limesurvey

# Move content to Apache root folder
RUN cp -rp /var/www/html/limesurvey/* /var/www/html && \
    chown -R www-data:www-data /var/www/html/limesurvey && \
    rm -rf /var/www/html/limesurvey

RUN chown www-data:www-data /var/lib/php5

# Copy docker-entrypoint
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

VOLUME /var/www/html/upload

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["php-fpm"]