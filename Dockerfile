FROM amd64/php:7.2-apache

LABEL maintainer="Florian JUDITH <florian.judith.b@gmail.com>"

ENV LIMESURVEY_URL=https://github.com/LimeSurvey/LimeSurvey/archive/2.73.0+171219.tar.gz

RUN mkdir /usr/share/man/man1 && \
    mkdir /usr/share/man/man7

RUN apt-get update && \
    apt-get install -yqqf --no-install-recommends \
    postgresql-client \
    mysql-client \
    dnsutils \
    netcat \
    crudini \
    zlib1g \
    git \
    wget \
    bzip2 \
    pwgen \
    zip \
    unzip \
    msmtp

RUN mkdir -p /usr/src/php/ext

# Install needed php extensions: smtp
#
RUN pear install Net_SMTP

# Install needed php extensions: memcached
#
RUN apt-get install -y libpq-dev libmemcached-dev && \
    curl -o memcached.tgz -SL http://pecl.php.net/get/memcached-3.0.3.tgz && \
        tar -xf memcached.tgz -C /usr/src/php/ext/ && \
        echo extension=memcached.so >> /usr/local/etc/php/conf.d/memcached.ini && \
        rm memcached.tgz && \
        mv /usr/src/php/ext/memcached-3.0.3 /usr/src/php/ext/memcached

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Install needed php extensions: zip
#
RUN apt-get install -y libz-dev && \
    curl -o zip.tgz -SL http://pecl.php.net/get/zip-1.15.1.tgz && \
        tar -xf zip.tgz -C /usr/src/php/ext/ && \
        rm zip.tgz && \
        mv /usr/src/php/ext/zip-1.15.1 /usr/src/php/ext/zip

# Install needed php extensions: memcache
#
RUN apt-get install --no-install-recommends -y unzip libssl-dev libpcre3 libpcre3-dev && \
    cd /usr/src/php/ext/ && \
    curl -sSL -o php7.zip https://github.com/websupport-sk/pecl-memcache/archive/NON_BLOCKING_IO_php7.zip && \
    unzip php7.zip && \
    mv pecl-memcache-NON_BLOCKING_IO_php7 memcache && \
    docker-php-ext-configure memcache --with-php-config=/usr/local/bin/php-config && \
    docker-php-ext-install memcache && \
    echo "extension=memcache.so" > /usr/local/etc/php/conf.d/ext-memcache.ini && \
    rm -rf /tmp/pecl-memcache-php7 php7.zip

RUN docker-php-ext-install memcached
RUN docker-php-ext-install memcache
RUN docker-php-ext-install zip

# Install needed php extensions: ldap
#
RUN apt-get install libldap2-dev -y && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
docker-php-ext-install ldap

# Install needed php extensions: imap
RUN apt-get install --no-install-recommends -yqq libssl-dev libc-client2007e-dev libkrb5-dev && \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
    docker-php-ext-install imap

# Install needed php extensions: bz2 
RUN apt-get install --no-install-recommends -yqq libbz2-dev && \
    docker-php-ext-install bz2

# Install needed php extensions: gd
RUN apt-get install --no-install-recommends --fix-missing -yqq libfreetype6-dev libpng-dev libjpeg-dev libjpeg62-turbo-dev libzip-dev && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/  && \
    docker-php-ext-install gd

# Install needed php extensions: mysql
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pdo_mysql

# Install needed php extensions: posgresql
RUN docker-php-ext-install pgsql
RUN docker-php-ext-install pdo_pgsql

# Install needed php extensions: mcrypt
RUN apt-get install -y libmcrypt-dev && \
    curl -o mcrypt.tgz -SL http://pecl.php.net/get/mcrypt-1.0.1.tgz && \
        tar -xf mcrypt.tgz -C /usr/src/php/ext/ && \
        rm mcrypt.tgz && \
        mv /usr/src/php/ext/mcrypt-1.0.1 /usr/src/php/ext/mcrypt && \
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
    crudini --set /usr/local/etc/php/conf.d/msmtp.ini "mail function" "sendmail_path" "'/usr/bin/msmtp -t'" && \
    touch /usr/local/etc/php/php.ini && \
    crudini --set /usr/local/etc/php/php.ini "mail function" "sendmail_path" "'/usr/bin/msmtp -t'"

# Clean up
RUN apt-get clean && \
    rm -r /var/lib/apt/lists/*

# Download and install Limesurvey
RUN cd /var/www/html \
    && curl -L $LIMESURVEY_URL | tar xvz --strip-components=1

# Change owner for security reasons
RUN chown -R www-data:www-data /var/www/html/*

# Copy docker-entrypoint
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

VOLUME /var/www/html/upload

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2-foreground"]