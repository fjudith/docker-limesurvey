[![](https://images.microbadger.com/badges/image/fjudith/limesurvey.svg)](https://microbadger.com/images/fjudith/limesurvey "Get your own image badge on microbadger.com")

# Supported tags and respective Dockerfile links

[`2.67.3`, `latest`](https://github.com/fjudith/docker-limesurvey/tree/2.67.3)
[`2.67.3-fpm`](https://github.com/fjudith/docker-limesurvey/tree/2.67.3/fpm)
[`2.67.1`](https://github.com/fjudith/docker-limesurvey/tree/2.67.1)

# Introduction

Limesurvey (formerly PHPSurveyor) is the most free & open source survey tool available on the web.

It supports more that various language, many different questiontypes, (e.g multiple choice, boolean, tables, commented, file upload, etc.) and enables an online HTML-editing to manage the content via a Web Browser.

Limesurvey can leverage LDAP protocol to manage users and survey invitation via email. 

 # Description
The Dockerfile buils from "php:5-apache (see https://hub.docker.com/_/php/)

**This image does not leverage embedded database**

## Roadmap

* [x] SMTP environment variables for email notifications
* [x] External url for email email notifications
* [x] Memcached via container link
* [x] MySQL or PostgreSQL autoconf via container link

## Quick Start

Run a supported database container with persistent storage (i.e. MySQL, MariaDB, PostgreSQL).

```bash
docker volume create "limesurvey-db"

docker run --name='limesurvey-md' -d \
--restart=always \
-e MYSQL_DATABASE=limesurvey \
-e MYSQL_ROOT_PASSWORD=V3rY1ns3cur3P4ssw0rd \
-e MYSQL_USER=limesurvey \
-e MYSQL_PASSWORD=V3rY1ns3cur3P4ssw0rd \
-v limesurvey-db:/var/lib/mysql \
-v limesurvey-dblog:/var/log/mysql \
-v limesurvey-etc:/etc/mysql \
mariadb
```

Run the Limesurvey container exposing internal port 80 with persistent storage for the _upload_ folder (i.e for. themes).

```bash
docker volume create "limesurvey-upload"

docker run --name='limesurvey' -d \
--restart=always \
-p 32701:80 \
-v limesurvey-upload:/var/www/html/upload \
--link limesurvey-md:mysql \
fjudith/limesruvey
```

## Environment variables

### Database

- **DB_TYPE**: postgresql or mysql; default = `mysql`
- **DB_HOST**: host of the database server; default = `mysql`
- **DB_PORT**: host of the database server; default = `3306`
- **DB_USERNAME**: username to use when connecting to the database; default = `root`
- **DB_PASSWORD**: password to use when connecting to the database; default = _empty_
- **DB_NAME**: name of the database to connect to; default = `limesurvey`
- **DB_TABLE_PREFIX**: prefix name of database table; default = `lime_`

### Public URL

- **PUBLIC_URL**: root URL to be written in email noficiations; default = _empty_

### SMTP

- **SMTP_HOST**: hostname/fqdn of the SMTP server; default = `localhost`
- **SMTP_PORT**: tcp listen port of the SMTP server; default = `25`
- **SMTP_PROTOCOL**: smtp or lsmtp protocol; default = `smtp`
- **SMTP_AUTH**: enable smtp authentification; default = `off`
    - **SMTP_USERNAME**: user to connect the SMTP server; default = _empty_
    - **SMTP_PASSWORD**: password to connect the SMTP server; default = _empty_
- **SMTP_TIMEOUT**: email notification timeout (milliseconds); default = `30000`
- **SMTP_TLS**: enable smtp over ssl; default = `off`
    - **SMTP_TLS_CHECK**: enable server side certificate validation; default = `off`
    - **SMTP_STARTTLS**: enable STARTTLS method; default = `off`
    - **SMTP_TLS_TRUST_FILE**: path to trusted certificate file; default = _empty_
- **MAIL_FROM_DEFAULT**: sender emal address; default = `limesurvey@example.com`
- **MAIL_DOMAIN**; _(optional)_, sets the argument of the SMTP EHLO (or LMTP LHLO) command. The default is ‘localhost’, which is stupid but usually works. Try to change the default if mails get rejected due to anti-SPAM measures. Possible choices are the domain part of your mail address (provider.example for joe@provider.example) or the fully qualified domain name of your host (if available); default = _empty_

### Memcached

- **MEMCACHE_HOST**: hostname/fqdn of the Memcached server; default = _empty_
- **MEMCACHE_PORT**: tcp listen port of the Memcaced server; default = _empty_

## Initial configuration

1. Start a web browser session to http://ip:port
2. Click Next until you reach the _Database configuration screen_
3. Then full-fill the following fields:
* **Database type**: MySQL
* **Database location**: mariadb _(i.e the link alias name)_
* **Database user**: limesurvey
* **Database password**: V3rY1ns3cur3P4ssw0rd 
* **Database name**: limesurvey
* **Table prefix**: lime_

# Docker-Compose
You can use docker compose to automate the above command if you create a file called docker-compose.yml and put in there the following:

#### Small deployment

Runs inside apache.

```yaml
limesurvey-md:
  image: mariadb
  restart: always
  ports:
    - "32805:3306"
  environment:
    MYSQL_DATABASE: limesurvey
    MYSQL_ROOT_PASSWORD: V3rY1ns3cur3P4ssw0rd
    MYSQL_USER: limesurvey
    MYSQL_PASSWORD: V3rY1ns3cur3P4ssw0rd
  volumes:
  - limesurvey-db:/var/lib/mysql
  - limesurvey-dblog:/var/log/mysql
  - limeservey-dbetc:/etc/mysql

limesurvey:
  image: fjudith/limesurvey
  restart: always
  ports:
    - "32705:80"
  volumes:
    - limesurvey-upload:/var/www/html/upload
  links:
    - limesurvey-md:mysql
```

#### Large deployement

Runs inside `php-fpm` linked to `memchaced` and `nginx` external containers.

```yaml
limesurvey-md:
  image: mariadb
  restart: always
  ports:
    - "32805:3306"
  environment:
    MYSQL_DATABASE: limesurvey
    MYSQL_ROOT_PASSWORD: V3rY1ns3cur3P4ssw0rd
    MYSQL_USER: limesurvey
    MYSQL_PASSWORD: V3rY1ns3cur3P4ssw0rd
  volumes:
  - limesurvey-db:/var/lib/mysql
  - limesurvey-dblog:/var/log/mysql
  - limeservey-dbetc:/etc/mysql

limesurvey-mc:
  image: memcached

limesurvey:
  image: fjudith/limesurvey:fpm
  restart: always
  ports:
    - "32705:80"
  environement:
    MEMCACHED_HOST: memcached
    PUBLIC_URL: http://survey.example.loc
    SMTP_HOST: smtp.example.com
    SMTP_TLS: on
    SMTP_PORT: 465
    SMTP_AUTH: off
    MAIL_FROM_DEFAULT: no-reply@example.com
    MAIL_DOMAIN: mail.example.com
  volumes:
    - limesurvey-upload:/var/www/html/upload
  links:
    - limesurvey-md:mysql
    - limesruvey-pc:memcached

limesurvey-nginx:
  image: nginx
  ports:
  - 32716:443/tcp
  - 32715:80/tcp
  links:
  - limesurvey-mc:memcached
  - limesurvey:limesurvey
  volumes:
  - limesurvey-data:/var/www/html:ro
  - limesurvey-nginx-config:/etc/nginx
  - limesurvey-nginx-log:/var/log/nginx
```

And run:

```bash
docker-compose up -d
```

# References

* https://www.limesurvey.org/
* http://msmtp.sourceforge.net/doc/msmtp.html