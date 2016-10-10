#!/bin/bash

# Reads EXIF creation date from all .JPG files in the
# current directory and moves them carefully under
#
#   $BASEDIR/YYYY/YYYY-MM-DD/
#
# ...where 'carefully' means that it does not overwrite
# differing files if they already exist and will not delete
# the original file if copying fails for some reason.
#
# It DOES overwrite identical files in the destination directory
# with the ones in current, however.
#
# Defaults
TOOLS=(exiftool jq) # Also change settings below if changing this, the output should be in the format YYYY:MM:DD
DEFAULTDIR='/Users/jonas/Pictures/DSLR/'
# activate debugging from here
#set -o xtrace
#set -o verbose

# Improve error handling
set -o errexit
set -o pipefail

# Check whether needed programs are installed
for TOOL in ${TOOLS[*]}
do
    hash $TOOL 2>/dev/null || { echo >&2 "I require $TOOL but it's not installed.  Aborting."; exit 1; }
done

# Use BASEDIR from commandline, or default if none given
BASEDIR=${1:-$DEFAULTDIR}
COUNT=0
COUNT_COPIED=0
FIND_FILES="find $(pwd -P) -maxdepth 1 -not -wholename '*._*' -iname '*.JPG' -or -iname '*.JPEG' -or -iname '*.CRW' -or -iname '*.THM' -or -iname '*.RW2' -or -iname '*.ARW' -or -iname '*AVI' -or -iname '*MOV' -or -iname '*MP4'  -or -iname '*MTS' -or -iname '*PNG'"
FILES_COUNT=$(eval $FIND_FILES | wc -l)
for FILE in $(eval $FIND_FILES)
do
  COUNT=$((COUNT+1))
  printf "\r⏳  $COUNT of $FILES_COUNT"
	INPUT=${FILE}
	DATE=$(exiftool -quiet -tab -dateformat "%Y:%m:%d" -json -DateTimeOriginal "${INPUT}" | jq --raw-output '.[].DateTimeOriginal')
	if [ "$DATE" == "null" ]  # If exif extraction with DateTimeOriginal failed
	then
		DATE=$(exiftool -quiet -tab -dateformat "%Y:%m:%d" -json -MediaCreateDate "${INPUT}" | jq --raw-output '.[].MediaCreateDate')
	fi
	if [ -z "$DATE" ] || [ "$DATE" == "null" ] # If exif extraction failed
	then
		DATE=$(stat -f "%Sm" -t %F "${INPUT}" | awk '{print $1}'| sed 's/-/:/g')
	fi
	if [ ! -z "$DATE" ]; # Doublecheck
	then
		YEAR=$(echo $DATE | sed -E "s/([0-9]*):([0-9]*):([0-9]*)/\\1/")
		MONTH=$(echo $DATE | sed -E "s/([0-9]*):([0-9]*):([0-9]*)/\\2/")
		DAY=$(echo $DATE | sed -E "s/([0-9]*):([0-9]*):([0-9]*)/\\3/")
		if [ "$YEAR" -gt 0 ] & [ "$MONTH" -gt 0 ] & [ "$DAY" -gt 0 ]
		then
			OUTPUT_DIRECTORY=${BASEDIR}/${YEAR}/${YEAR}-${MONTH}-${DAY}
			mkdir -pv ${OUTPUT_DIRECTORY}
			OUTPUT=${OUTPUT_DIRECTORY}/$(basename ${INPUT})
			if ! [ -e "$OUTPUT" ]
			then
        COUNT_COPIED=$((COUNT_COPIED+1))
				rsync -ahq "$INPUT"  "$OUTPUT"
				if ! cmp -s "$INPUT" "$OUTPUT"
				then
					echo "WARNING: copying failed somehow, will not delete original '$INPUT'"
				fi
			fi
		else
		  echo "WARNING: '$INPUT' doesn't contain date."
		fi
	else
		echo "WARNING: '$INPUT' doesn't contain date."
	fi
done
echo "\nCopied $COUNT_COPIED files 👍"
