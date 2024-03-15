#!/bin/bash

# HOMELOC="/home/rothlab"
CURRHOME=$1
COMMON="/home/rothlab/common"
SIZECUTOFF=1G

#Find files with the same size, indicating that they might be copies
#Input: arguments are a list of file sizes. 
#Output: Each line lists a set of row indices that are candidates
findCandidates() {
  python3 -c '
import sys
xs = sys.argv[1:]
for i in range(1,len(xs)):
  matches = [j for j in range(i) if xs[j]==xs[i]]
  if len(matches) > 0:
    print(str(i)+" "+" ".join([str(x) for x in matches]))
' $*
}

#Verify candidate index lists
#Input: Size table file and candidate table file
#Output: Prints when files candidates are indeed identical
findMatches() {
  SIZETABLE=$1
  CANDITABLE=$2
  mapfile -t FILEARR < <(awk '{print $2}' "$SIZETABLE")
  while read -r LINE; do
    read -r -a ITEMS <<< "$LINE"
    n=${#ITEMS[@]}
    for (( i=1; i<n; i++ )); do
      II="${ITEMS[$i]}"
      for (( j=0; j<i; j++ )); do
        IJ="${ITEMS[$j]}"
        #confusingly, diff returns 1 if files differ, but 0 if not
        if diff -q "${FILEARR[$II]}" "${FILEARR[$IJ]}">/dev/null; then
          echo "Identical files: ${FILEARR[$II]}  ${FILEARR[$IJ]}"
        fi
      done
    done
  done <"$CANDITABLE"
}


#Same as above, but across home directories instead of within
#Input: arguments are a list of file sizes. 
#Output: Each line lists a set of row indices that are candidates
findCrossCandidates() {
  SIZES="$1"
  COMMONSIZES="$2"
  i=0
  while read -r SIZE1; do
    # echo "$i :"
    HITS=$(grep -n "$SIZE1" "$SIZES"|cut -f1 -d:)
    if [[ -n "$HITS" ]]; then
      #grep's line numbers are 1-based, so we have to subtract 1
      printf '%s' "$i"
      for HIT in $HITS; do
        printf ' %s' "$((HIT-1))"
      done
      printf '\n'
    fi
    ((i++))
  done <"$COMMONSIZES"
}

findCrossMatches() {
  COMMONSIZETABLE=$1
  SIZETABLE=$2
  CANDITABLE=$3
  mapfile -t FILEARR < <(awk '{print $2}' "$SIZETABLE")
  mapfile -t COMMONFILEARR < <(awk '{print $2}' "$COMMONSIZETABLE")
  while read -r LINE; do
    read -r -a ITEMS <<< "$LINE"
    n=${#ITEMS[@]}
    II="${ITEMS[0]}"
    CFILE="${COMMONFILEARR[$II]}"
    for (( j=1; j<n; j++ )); do
      IJ="${ITEMS[$j]}"
      UFILE="${FILEARR[$IJ]}"
      #confusingly, diff returns 1 if files differ, but 0 if not
      if diff -q "$CFILE" "$UFILE">/dev/null; then
        echo "Identical files: $CFILE  $UFILE"
      fi
    done
  done <"$CANDITABLE"
}

#find all files with size >= cutoff (1GB) and save in table with columns "size" and "path"
tabulateLargeFiles() {
  BASEDIR=$1
  find "$BASEDIR" -type f -size +${SIZECUTOFF} -printf '%s\t%p\n'
}

#go to filesystem root, so all 'find' results are full paths
cd /

#create temporary files to store intermediate results
COMMONSIZETABLE=$(mktemp)
SIZETABLE=$(mktemp)
CANDITABLE=$(mktemp)

#find all files with size >= cutoff (1GB) in common folder and save in table with columns "size" and "path"
tabulateLargeFiles "$COMMON" >"$COMMONSIZETABLE" 2>/dev/null

printf '\n######\n%s\n#######\n' "$CURRHOME"
printf '\nInternal duplications:\n####\n' 

#find all files >1GB in user home and save in table (as above)
tabulateLargeFiles "$CURRHOME" >"$SIZETABLE"
#find candidates of internal duplication via equal file sizes
findCandidates $(awk '{print $1}' $SIZETABLE) >"$CANDITABLE"
#verify candidates by checking whether files are identical
findMatches "$SIZETABLE" "$CANDITABLE"

if [[ "$CURRHOME" != "$COMMON" ]]; then
  printf '\n####\nDuplication with commons:\n####\n' "$CURRHOME"
  findCrossCandidates <(awk '{print $1}' "$SIZETABLE") <(awk '{print $1}' "$COMMONSIZETABLE")>"$CANDITABLE"
  findCrossMatches "$COMMONSIZETABLE" "$SIZETABLE" "$CANDITABLE"
fi

#find large uncompressed files
printf '\n\n####\nLarge uncompressed files:\n####\n' 
file $(awk '{print $2}' "$SIZETABLE")|grep -vP 'gzip|Zip|archive'

#find directories with BCL files
printf '\n\n####\nRaw BCL file locations:\n####\n' 
find "$CURRHOME" -type f -name "*.bcl" -printf '%h\n' 2>/dev/null|sort|uniq

rm "$SIZETABLE" "$CANDITABLE" "$COMMONSIZETABLE"

