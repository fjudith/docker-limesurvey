[![](https://images.microbadger.com/badges/image/fjudith/limesurvey.svg)](https://microbadger.com/images/fjudith/limesurvey "Get your own image badge on microbadger.com")

# Supported tags and respective Dockerfile links

[`2.67.3`, `latest`](https://github.com/fjudith/docker-limesurvey/tree/2.67.3)
[`2.67.1`](https://github.com/fjudith/docker-limesurvey/tree/2.67.1)

# Introduction

Limesurvey (formerly PHPSurveyor) is the most free & open source survey tool available on the web.

It supports more that various language, many different questiontypes, (e.g multiple choice, boolean, tables, commented, file upload, etc.) and enables an online HTML-editing to manage the content via a Web Browser.

Limesurvey can leverage LDAP protocol to manage users and survey invitation via email. 

 # Description
The Dockerfile buils from "php:5-apache (see https://hub.docker.com/_/php/)

**This image does not leverage embedded database**

## Roadmap

* [x] Support SMTP environment variables for email notifications
* [ ] Implement external url environment variable to fix email template URL.  

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
--links limesurvey-md:mariadb \
fjudith/limesruvey
```

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
    - limesurvey-md:mariadb
```

And run:

```bash
docker-compose up -d
```

# References

* https://www.limesurvey.org/
* http://msmtp.sourceforge.net/doc/msmtp.html