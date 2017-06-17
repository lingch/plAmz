#!/bin/sh

find /var/www/storage/ -samefile $1 | xargs  -I{} rm {}

