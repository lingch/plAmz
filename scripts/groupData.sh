#!/bin/sh

if [ $# -lt 1 ] ; then
	echo "please input code";
	exit 1;
fi

CODE=$1;

rm -rf "$CODE-all"
rm -f "$CODE-all.csv" 
mkdir "$CODE-all"

TMPFILE="/tmp/tbi"

find "$CODE/" -name "*.tbi" > $TMPFILE

while read line; do
	NAME=`echo $line | rev | cut -d/ -f1| rev`
	if [ ! -e "$CODE-all/$NAME" ]; then
		ln $line "$CODE-all/"
	fi
done <$TMPFILE;

cat template/template-header.csv > "$CODE-all.csv"
find "$CODE/" -name "*.csv" | xargs -I '{}' cat '{}' >> "$CODE-all.csv"


ls -1 $CODE-all/*.tbi | cut -d/ -f2 | cut -d. -f1> $TMPFILE
i=1;
while read line; do
	mv "$CODE-all/$line.tbi" "$CODE-all/$i.tbi"
	sed -i "s/$line/$i/g" "$CODE-all.csv"
	i=`expr $i + 1`
done <$TMPFILE

#rm $TMPFILE
