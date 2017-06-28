#!/bin/sh
CODE=$1;

rm -rf "$CODE-all"
rm -f "$CODE-all.csv" 
mkdir "$CODE-all"
find "$CODE/" -name "*.tbi" | xargs -I '{}' ln '{}' "$CODE-all/"
cat template/template-header.csv > "$CODE-all.csv"
find "$CODE/" -name "*.csv" | xargs -I '{}' cat '{}' >> "$CODE-all.csv"

