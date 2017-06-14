#!/bin/sh

mkdir data
find taobao-data/ -name "*.tbi" | xargs -I '{}' ln '{}' "data/"
cat template-header.csv > data.csv
find taobao-data/ -name "*.csv" | xargs -I '{}' cat '{}' >> data.csv

