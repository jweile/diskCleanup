#!/bin/bash
SLICEFILE="$1"
CHECKSUMFILE=$2
TARGET=$3
SERVERNAME="${4:-rothseq.mshri.on.ca}"
REMOTEUSER="${5:-$USER}"

#pick 100 random files > 1GB and calculate their md5 sums
echo "Starting transfers..."
unalias rsync

#transfer the slice files
while read -r FILEPATH; do
  rsync -aPR "${REMOTEUSER}@${SERVERNAME}:${FILEPATH}" "$TARGET"
done <"$SLICEFILE"

#validate the checksums
#the sums are listed by absolute path w.r.t to the server. So we'll have to turn them in to paths on the target
awk "{print \$1\"  $TARGET\"\$2}" "$CHECKSUMFILE"|md5sum -c

echo "Done!"



