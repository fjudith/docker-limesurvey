#!/bin/bash
set -e 

SMTP_HOST=${SMTP_HOST:-'localhost'}
SMTP_PORT=${SMTP_PORT:-'25'}
SMTP_PROTOCOL=${MAIL_PROTOCOL:-'smtp'}
SMTP_AUTH=${SMTP_AUTH:-'off'}
SMTP_USERNAME=${SMTP_USERNAME:-}
SMTP_PASSWORD=${SMTP_PASSWORD:-}

SMTP_TLS=${SMTP_TLS:-'off'}
SMTP_STARTTLS=${SMPTP_STARTTLS_ENABLE:-'off'}
SMTP_TLS_CHECK=${SMTP_TLS_CHECK:-'off'}
SMTP_TLS_TRUST_FILE=${SMTP_TLS_TRUST_FILE:-}

MAIL_FROM_DEFAULT=${MAIL_FROM_DEFAULT:-'limesurvey@example.com'}
MAIL_TRUST_DOMAIN=${MAIL_TRUST_DOMAIN:-}
MAIL_DOMAIN=${MAIL_DOMAIN:-}
SMTP_TIMEOUT=${SMTP_TIMEOUT:-'30000'}

PUBLIC_URL=${PUBLIC_URL:-}

DB_KIND=${DB_KIND:-'mysql'}
DB_HOST=${DB_HOST:-'mysql'}
DB_PORT=${DB_PORT:-'3306'}
DB_NAME=${DB_NAME:-'limesurvey'}
DB_CHARSET=${DB_CHARSET:-'utf8mb4'}
DB_TABLE_PREFIX=${DB_TABLE_PREFIX:-'lime_'}
DB_USERNAME=${DB_USERNAME:-}
DB_PASSWORD=${DB_PASSWORD:-}

MEMCACHED_HOST=${MEMCACHED_HOST:-}
MEMCACHED_PORT=${MEMCACHED_PORT:-'11211'}
MEMCACHED_WEIGHT=${MEMCACHED_PORT:-'100'}

URL_FORMAT=${URL_FORMAT:-'path'}

# Write MSMTP configuration
cat > /etc/msmtprc << EOL
account default
host ${SMTP_HOST}
port ${SMTP_PORT}
protocol ${SMTP_PROTOCOL}
auth ${SMTP_AUTH}
user ${SMTP_USERNAME}
password ${SMTP_PASSWORD}
tls ${SMTP_TLS}
tls_starttls ${SMTP_STARTTLS}
tls_certcheck ${SMTP_TLS_CHECK}
tls_trust_file
from ${MAIL_FROM_DEFAULT}
maildomain ${MAIL_TRUST_DOMAIN}
domain ${MAIL_DOMAIN}
timeout ${SMTP_TIMEOUT}
EOL

# Write Database config
sed -i "s#\('connectionString' => \).*,\$#\\1'${DB_KIND}:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME};',#g" application/config/config.php
sed -i "s#\('username' => \).*,\$#\\1'${DB_USERNAME}',#g" application/config/config.php
sed -i "s#\('password' => \).*,\$#\\1'${DB_PASSWORD}',#g" application/config/config.php
sed -i "s#\('charset' => \).*,\$#\\1'${DB_CHARSET}',#g" application/config/config.php
sed -i "s#\('tablePrefix' => \).*,\$#\\1'${DB_TABLE_PREFIX}',#g" application/config/config.php

# Write UrlManager config
sed -i "s#\('urlFormat' => \).*,\$#\\1'${URL_FORMAT}',#g" application/config/config.php

# Write Public URL
if [ "$PUBLIC_URL" ]; then
    sed -i "s#\('debug'=>0,\)\$#'publicurl'=>'${PUBLIC_URL}',\n\t\t\\1 #g" application/config/config.php
fi

# Write Memcached config
if [ "$MEMCACHED_HOST"]; then
    sed -i "s#\('db' => array(\)#'cache'=>array(\n\t\t\t'class'=>'CMemCache',\n\t\t\t'servers'=>array(\n\t\t\t\tarray(\n\t\t\t\t\t'host'=>'${MEMCACHED_HOST}',\n\t\t\t\t\t'port'=>'${MEMCACHED_PORT}',\n\t\t\t\t\t'weight'=>'${MEMCACHED_WEIGHT}',\n\t\t\t\t),\n\t\t\t),\n\t\t),\n\t\t\\1 #g" application/config/config.php
fi

# Start Aphache
exec "$@"