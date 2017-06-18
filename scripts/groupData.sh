#!/bin/sh

rm -r data
rm data.csv -f
mkdir data
find taobao-data/ -name "*.tbi" | xargs -I '{}' ln '{}' "data/"
cat template/template-header.csv > data.csv
find taobao-data/ -name "*.csv" | xargs -I '{}' cat '{}' >> data.csv

