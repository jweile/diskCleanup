#!/bin/bash

HOMELOC="/home/rothlab"

#find all home directories
HOMES=$(ls -d "${HOMELOC}/"*/)

#iterate over user homes
for CURRHOME in $HOMES; do
  if [[ ! -r $CURRHOME ]]; then
    echo "Unable to read ${CURRHOME}. Skipped."
    continue
  fi
  CURRUSER="$(basename "$CURRHOME")"
  LOG="${CURRUSER}_cleanup.log"
  submitjob.sh -c 2 -m 2G -t 7-00:00:00 -l "$LOG" -e "$LOG" -- findDuplicates.sh "$CURRHOME"
done

# waitForJobs -v
