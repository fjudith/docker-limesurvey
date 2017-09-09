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

DB_TYPE=${DB_TYPE:-'mysql'}
DB_HOST=${DB_HOST:-'mysql'}
DB_PORT=${DB_PORT:-'3306'}
DB_NAME=${DB_NAME:-'limesurvey'}
DB_TABLE_PREFIX=${DB_TABLE_PREFIX:-'lime_'}
DB_USERNAME=${DB_USERNAME:-}
DB_PASSWORD=${DB_PASSWORD:-}

MEMCACHE_HOST=${MEMCACHE_HOST:-}
MEMCACHE_PORT=${MEMCACHE_PORT:-'11211'}
MEMCACHE_WEIGHT=${MEMCACHE_PORT:-'100'}

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
# if we're linked to MySQL and thus have credentials already, let's use them
if [[ -v MYSQL_ENV_GOSU_VERSION ]]; then
    : ${DB_TYPE='mysql'}
    : ${DB_USERNAME:=${MYSQL_ENV_MYSQL_USER:-root}}
    if [ "$DB_USERNAME" = 'root' ]; then
        : ${DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
    fi
    : ${DB_PASSWORD:=$MYSQL_ENV_MYSQL_PASSWORD}
    : ${DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-limesurvey}}
    : ${DB_CHARSET=${DB_CHARSET:-'utf8mb4'}}
    
    echo 'Using MySQL'
    if ! mysql -h mysql -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "SELECT 1 FROM information_schema.tables WHERE table_schema = '${DB_NAME}' AND table_name = '${DB_TABLE_PREFIX}_templates';" | grep 1 ; then
        echo 'Initializing MySQL database'
        mysql -h mysql -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME < installer/sql/create-mysql.sql
    else
        echo 'Database already initialized'
    fi

    if [ -z "$DB_PASSWORD" ]; then
        echo >&2 'error: missing required DB_PASSWORD environment variable'
        echo >&2 '  Did you forget to -e DB_PASSWORD=... ?'
        echo >&2
        echo >&2 '  (Also of interest might be DB_USERNAME and DB_NAME.)'
        exit 1
    fi

    cp application/config/config-sample-mysql.php application/config/config.php
fi

# if we're linked to PostgreSQL and thus have credentials already, let's use them
if [[ -v POSTGRES_ENV_GOSU_VERSION ]]; then
    : ${DB_TYPE='postgresql'}
    : ${DB_USERNAME:=${POSTGRES_ENV_POSTGRES_USER:-root}}
    if [ "$DB_USERNAME" = 'postgres' ]; then
        : ${DB_PASSWORD:='postgres' }
    fi
    : ${DB_PASSWORD:=$POSTGRES_ENV_POSTGRES_PASSWORD}
    : ${DB_NAME:=${POSTGRES_ENV_POSTGRES_DB:-limesurvey}}
    : ${DB_CHARSET=${DB_CHARSET:-'utf8'}}

    echo 'Using PostgreSQL'
    if ! psql postgresql://$DB_USERNAME:$DB_PASSWORD@postgres/$DB_NAME -c "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${DB_TABLE_PREFIX}_templates';" | grep 1 ; then
        echo 'Initializing PostgreSQL database'
        psql postgresql://$DB_USERNAME:$DB_PASSWORD@postgres/$DB_NAME -f installer/sql/create-pgsql.sql
    else
        echo 'Database already initialized'
    fi

    if [ -z "$DB_PASSWORD" ]; then
        echo >&2 'error: missing required DB_PASSWORD environment variable'
        echo >&2 '  Did you forget to -e DB_PASSWORD=... ?'
        echo >&2
        echo >&2 '  (Also of interest might be DB_USERNAME and DB_NAME.)'
        exit 1
    fi

    cp application/config/config-sample-pgsql.php application/config/config.php
fi

sed -i "s#\('connectionString' => \).*,\$#\\1'${DB_TYPE}:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME};',#g" application/config/config.php
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
if [ "$MEMCACHE_HOST" ]; then
    sed -i "s#\('db' => array(\)#'cache'=>array(\n\t\t\t'class'=>'CMemCache',\n\t\t\t'servers'=>array(\n\t\t\t\tarray(\n\t\t\t\t\t'host'=>'${MEMCACHE_HOST}',\n\t\t\t\t\t'port'=>'${MEMCACHE_PORT}',\n\t\t\t\t\t'weight'=>'${MEMCACHE_WEIGHT}',\n\t\t\t\t),\n\t\t\t),\n\t\t),\n\t\t\\1 #g" application/config/config.php
fi

# Start Aphache
exec "$@"