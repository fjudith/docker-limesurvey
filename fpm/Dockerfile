
FROM amd64/php:7.4-fpm

LABEL maintainer="Florian JUDITH <florian.judith.b@gmail.com>"

ARG LIMESURVEY_URL=https://download.limesurvey.org/lts-releases/limesurvey3.24.1+201014.zip

RUN mkdir /usr/share/man/man1 && \
    mkdir /usr/share/man/man7

RUN apt-get update -yqq && \
    apt-get install -yqqf --no-install-recommends \
    postgresql-client \
    default-mysql-client \
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
RUN apt-get install -y --no-install-recommends \
    libpq-dev \
    libmemcached-dev \
    zlib1g-dev && \
    curl -o memcached.tgz -SL http://pecl.php.net/get/memcached-3.1.5.tgz && \
    tar -xf memcached.tgz -C /usr/src/php/ext/ && \
    echo extension=memcached.so >> /usr/local/etc/php/conf.d/memcached.ini && \
    rm memcached.tgz && \
    mv /usr/src/php/ext/memcached-3.1.5 /usr/src/php/ext/memcached && \
    docker-php-ext-install memcached

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
RUN apt-get install -yqq --no-install-recommends \
    libz-dev \
    libzip-dev && \
    curl -o zip.tgz -SL http://pecl.php.net/get/zip-1.19.1.tgz && \
    tar -xf zip.tgz -C /usr/src/php/ext/ && \
    rm zip.tgz && \
    mv /usr/src/php/ext/zip-1.19.1 /usr/src/php/ext/zip && \
    docker-php-ext-install zip

# Install needed php extensions: memcache
#
RUN apt-get install -yqq --no-install-recommends \
    unzip \
    libssl-dev \
    libpcre3 \
    libpcre3-dev && \
    curl -o memcache.tgz -SL http://pecl.php.net/get/memcache-4.0.5.2.tgz && \
    tar -xf memcache.tgz -C /usr/src/php/ext/ && \
    rm memcache.tgz && \
    mv /usr/src/php/ext/memcache-4.0.5.2 /usr/src/php/ext/memcache && \
    docker-php-ext-install memcache && \
    echo "extension=memcache.so" > /usr/local/etc/php/conf.d/ext-memcache.ini

# Install needed php extensions: ldap
#
RUN apt-get install -yqq --no-install-recommends \
    libldap2-dev && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
    docker-php-ext-install ldap

# Install needed php extensions: imap
RUN apt-get install -yqq --no-install-recommends \
    libssl-dev \
    libc-client2007e-dev \
    libkrb5-dev && \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
    docker-php-ext-install imap

# Install needed php extensions: bz2 
RUN apt-get install -yqq --no-install-recommends \
    libbz2-dev && \
    docker-php-ext-install bz2

# Install needed php extensions: gd
RUN apt-get install -yqq --no-install-recommends --fix-missing \
    libfreetype6-dev \
    libpng-dev \
    libjpeg-dev \
    libjpeg62-turbo-dev \
    libzip-dev && \
    docker-php-ext-configure gd && \
    docker-php-ext-install gd

# Install needed php extensions: mysql
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pdo_mysql

# Install needed php extensions: posgresql
RUN docker-php-ext-install pgsql
RUN docker-php-ext-install pdo_pgsql

# Install needed php extensions: mcrypt
RUN apt-get install -y libmcrypt-dev && \
    curl -o mcrypt.tgz -SL http://pecl.php.net/get/mcrypt-1.0.3.tgz && \
    tar -xf mcrypt.tgz -C /usr/src/php/ext/ && \
    rm mcrypt.tgz && \
    mv /usr/src/php/ext/mcrypt-1.0.3 /usr/src/php/ext/mcrypt && \
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
RUN apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/*

# Download and install Limesurvey
RUN curl -L -o limesurvey.zip $LIMESURVEY_URL && \
    unzip limesurvey.zip -d /var/www/html && \
    mv /var/www/html/limesurvey/* /var/www/html/ && \
    rm -rf limesurvey limesurvey.zip

# Change owner for security reasons
RUN chown -R www-data:www-data /var/www/html/*

# Copy docker-entrypoint
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

VOLUME /var/www/html/upload

EXPOSE 9000

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["php-fpm"]