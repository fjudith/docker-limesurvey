
FROM php:5-apache

ENV LIMESURVEY_URL=http://download.limesurvey.org/latest-stable-release/limesurvey2.55+161021.tar.gz

RUN apt-get update && \
    apt-get install -y \
	   curl \
       libldap2-dev \
       php5-gd \
       php5-ldap \
       php5-imap

RUN	apt-get clean \
    php5enmod \
    imap

# Install needed php extensions: ldap
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
    docker-php-ext-install ldap

# Download and install Limesurvey
RUN cd /var/www/html \
    && curl $LIMESURVEY_URL | tar xvz

# Change owner for security reasons
RUN chown -R www-data:www-data /var/www/html/limesurvey

# Move content to Apache root folder
RUN cp -r /var/www/html/limuesurvey/* /var/www/html && \
    chown -R www-data:www-data /var/www/html/limesurvey && \
    rm -rf /var/www/html/limesurvey

RUN chown www-data:www-data /var/lib/php5

VOLUME /var/www/html/upload

EXPOSE 80
CMD ["apache2-foreground"]