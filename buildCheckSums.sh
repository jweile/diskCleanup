#!/bin/bash
SLICEFILE=$1
SIZECUTOFF=${2:-1G}
NFILES=${3-100}

if [[ "$SIZECUTOFF" == *G ]]; then
  NUM="${SIZECUTOFF%G}"
  SIZECUTOFFBYTES=$((NUM * 2**30))
elif [[ "$SIZECUTOFF" == *M ]]; then
  NUM="${SIZECUTOFF%M}"
  SIZECUTOFFBYTES=$((NUM * 2**20))
elif [[ "$SIZECUTOFF" == *K ]]; then
  NUM="${SIZECUTOFF%K}"
  SIZECUTOFFBYTES=$((NUM * 2**10))
else 
  echo "Unable to parse size cutoff!" >&2
  exit 1
fi

#find all files bigger than size cut off in listed directories
findBigFiles() {
  SLICEFILE="$1"
  while read -r FILEPATH; do
    #if the path is already a file, we check its size directory
    if [[ -f "$FILEPATH" ]]; then
      FSIZE=$(stat --printf="%s" "$FILEPATH")
      if (( FSIZE > SIZECUTOFFBYTES )); then
        echo "$FILEPATH"
      fi
    elif [[ -d "$FILEPATH" ]]; then
      find "$FILEPATH" -type f -size "+${SIZECUTOFF}"
    fi
  done <"$SLICEFILE"
}


#pick 100 random files > 1GB and calculate their md5 sums
echo "Building checksums..."
md5sum $(findBigFiles "$SLICEFILE"|shuf -n "$NFILES") |tee "${SLICEFILE%.txt}_${NFILES}_checksums.md5"
# md5sum $(find "$BASEDIR" -type f -size "+${SIZECUTOFF}"|shuf -n "$NFILES") > "sample_checksums_${BASEDIR//\//-}_${NFILES}.md5"

echo "Done!"



