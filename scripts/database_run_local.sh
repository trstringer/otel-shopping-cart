#!/bin/bash

docker run \
	--name otel-shopping-cart-postgres \
	--rm \
	-e POSTGRES_PASSWORD=password123 \
	-d \
	-p 5432:5432 \
	postgres:16

until PGPASSWORD=password123 psql \
    -h 127.0.0.1 \
    -U postgres \
    -d postgres \
    -c "DROP DATABASE IF EXISTS otel_shopping_cart;"
do
    echo Waiting for postgres to come up...
    sleep 5
done

PGPASSWORD=password123 psql \
    -h 127.0.0.1 \
    -U postgres \
    -d postgres \
    -c "CREATE DATABASE otel_shopping_cart;"

PGPASSWORD=password123 psql \
    -h 127.0.0.1 \
    -U postgres \
    -d otel_shopping_cart \
    -f ./database/setup.sql
