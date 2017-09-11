FROM nginx:stable

# Use it only with "fjudith/limesurvey:fpm" linked as "limesurvey"
# and "memcached" linked as "memcached"
# enables 10M max file uploads

MAINTAINER Florian JUDITH <florian.judith.b@gmail.com>

USER www-data

COPY nginx.conf /etc/nginx/