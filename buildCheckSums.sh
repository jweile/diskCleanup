BASEDIR=$1
SIZECUTOFF=1G
NFILES=100

#pick 100 random files > 1GB and calculate their md5 sums
md5sum $(find "$BASEDIR" -type f -size "+${SIZECUTOFF}"|shuf -n "$NFILES") > "subsample${BASEDIR//\//-}_${NFILES}.md5"

