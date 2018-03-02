#!/usr/bin/env bash -e

set -ex

export MYSQL_HOST=${MYSQL_HOST:="mysql"}
export MYSQL_PASSWORD=${MYSQL_PASSWORD:="apples"}

mysql --host=$MYSQL_HOST --password=$MYSQL_PASSWORD < employees.sql