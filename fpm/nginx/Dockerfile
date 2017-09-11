FROM nginx:stable

# Use it only with "fjudith/limesurvey:fpm" linked as "limesurvey"
# and "memcached" linked as "memcached"
# enables 10M max file uploads

MAINTAINER Florian JUDITH <florian.judith.b@gmail.com>

COPY nginx.conf /etc/nginx/


RUN touch /var/run/nginx.pid  && \
    mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www && \
    chown -R www-data:www-data /var/run/nginx.pid && \
    chown -R www-data:www-data /var/cache/nginx

USER www-data

EXPOSE 8080 8443