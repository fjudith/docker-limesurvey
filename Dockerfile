
FROM php:5-apache

MAINTAINER Florian JUDITH <florian.judith.b@gmail.com>


ENV LIMESURVEY_URL=http://download.limesurvey.org/latest-stable-release/limesurvey2.62.2+170203.tar.gz

RUN apt-get update && \
    apt-get install -y curl wget bzip2 pwgen

# Install needed php extensions: imagick, ldap, imap, zlib, gd
RUN apt-get install -y php5-ldap libldap2-dev && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
    docker-php-ext-install ldap

RUN apt-get install -y php5-imap libssl-dev libc-client2007e-dev libkrb5-dev && \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
    docker-php-ext-install imap

RUN apt-get install -y libfreetype6-dev libpng12-dev libjpeg62-turbo-dev libzip-dev && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ --with-zlib-dir=/usr/include/ --with-zlib && \
    docker-php-ext-install gd

RUN apt-get -y install zlib1g-dev && \
    docker-php-ext-install zip && \
    apt-get purge --auto-remove -y zlib1g-dev

RUN docker-php-ext-install mysqli

RUN docker-php-ext-install pdo_mysql

RUN apt-get -y install re2c libmcrypt-dev && \
    docker-php-ext-install mcrypt

RUN apt-get install --fix-missing -y libmagickwand-dev && \
    pecl install imagick && \
    docker-php-ext-enable imagick

# Clean up
RUN rm -r /var/lib/apt/lists/*

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

VOLUME /var/www/html/upload

EXPOSE 80
CMD ["apache2-foreground"]