
FROM php:5.6-apache

MAINTAINER Florian JUDITH <florian.judith.b@gmail.com>


ENV LIMESURVEY_URL=http://download.limesurvey.org/latest-stable-release/limesurvey2.67.1+170626.tar.gz

RUN apt-get update && \
    apt-get install -y \
    git \
    curl \
    wget \
    bzip2 \
    pwgen \
    zip \
    unzip \
    sendmail \
    sendmail-bin \
    mailutils

# Install needed php extensions: imagick, ldap, imap, zlib, gd
RUN apt-get install -y php5-ldap libldap2-dev && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
    docker-php-ext-install ldap

RUN apt-get install -y php5-imap libssl-dev libc-client2007e-dev libkrb5-dev && \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
    docker-php-ext-install imap

RUN apt-get -y install zlib1g-dev && \
    docker-php-ext-install zip

# Install bz2 
RUN apt-get install -y libbz2-dev && \
    docker-php-ext-install bz2

RUN apt-get install --fix-missing -y libfreetype6-dev libpng12-dev libjpeg62-turbo-dev libzip-dev && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/  && \
    docker-php-ext-install gd

RUN docker-php-ext-install mysqli

RUN docker-php-ext-install pdo_mysql

RUN apt-get -y install re2c libmcrypt-dev && \
    docker-php-ext-install mcrypt

RUN apt-get install --fix-missing -y libmagickwand-dev && \
    pecl install imagick && \
    docker-php-ext-enable imagick

# Clean up
RUN apt-get clean &&
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

VOLUME /var/www/html/upload

EXPOSE 80
CMD ["apache2-foreground"]