#!/bin/bash

if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    echo "You must set MYSQL_ROOT_PASSWORD"
    exit 1
fi

docker run \
    --name otel-shopping-cart-mysql \
    --env MYSQL_ROOT_PASSWORD \
    --rm \
    -p 3307:3306 \
    -d mysql:8-debian

until mysqlsh \
    --user root \
    --password $MYSQL_PASSWORD \
    localhost:3307 \
    -f ./database/setup.sql
do
    echo Waiting for MySQL to come up...
    sleep 5
done
