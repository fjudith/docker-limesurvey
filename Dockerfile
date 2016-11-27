
FROM php:5-apache

ENV LIMESURVEY_URL=http://download.limesurvey.org/latest-stable-release/limesurvey2.56.1+161118.tar.gz

RUN apt-get update && \
    apt-get install -y curl wget bzip2 pwgen

# Install needed php extensions: ldap, imap, zlib, gd
RUN apt-get install -y php5-ldap libldap2-dev && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
    docker-php-ext-install ldap

RUN apt-get install -y php5-imap libssl-dev libc-client2007e-dev libkrb5-dev && \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
    docker-php-ext-install imap

RUN apt-get install -y libpng12-dev libjpeg-dev && \
    docker-php-ext-configure gd --with-jpeg-dir=/usr/lib && \
    docker-php-ext-install gd

RUN apt-get -y install zlib1g-dev && \
    docker-php-ext-install zip && \
    apt-get purge --auto-remove -y zlib1g-dev

RUN docker-php-ext-install mysqli

RUN docker-php-ext-install pdo_mysql

RUN apt-get -y install re2c libmcrypt-dev && \
    docker-php-ext-install mcrypt

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