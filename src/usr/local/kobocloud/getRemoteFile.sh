#!/bin/sh

retry="TRUE"

if [ "$1" = "NORETRY" ]
then
    retry="FALSE"
    shift 1
fi

linkLine="$1"
localFile="$2"
user="$3"
outputFileTmp="/tmp/kobo-remote-file-tmp.log"

# add the epub extension to kepub files
if echo "$localFile" | grep -Eq '\.kepub$'
then
    localFile="$localFile.epub"
fi

realfile=$localFile
localFile="$localFile.tmp"
tmpfile=$localFile

#load config
. $(dirname $0)/config.sh

curlCommand="$CURL"
if [ ! -z "$user" ] && [ "$user" != "-" ]; then
    echo "User: $user"
    curlCommand="$curlCommand -u $user: "
fi

if [ -f "$realfile" ]; then
    localSize=`stat -c%s "$realfile"`
    echo "File exists: $localSize bytes"
    exit 0
fi

echo "Download: "$curlCommand -k --silent -C - -L --create-dirs -o "$localFile" "$linkLine" -v

$curlCommand -k --silent -C - -L --create-dirs -o "$localFile" "$linkLine" -v 2>$outputFileTmp
status=$?
echo "Status: $status"
echo "Output: "
cat $outputFileTmp

statusCode=`grep 'HTTP/' "$outputFileTmp" | tail -n 1 | cut -d' ' -f3`
grep -q "Cannot resume" "$outputFileTmp"
errorResume=$?
rm $outputFileTmp

echo "Remote file information:"
echo "  Status code: $statusCode"

if echo "$statusCode" | grep -q "403"; then
    echo "Error: Forbidden"
    rm "$tmpfile"
    exit 2
fi
if echo "$statusCode" | grep -q "50.*"; then
    echo "Error: Server error"
    if [ $errorResume ] && [ "$retry" = "TRUE" ]
    then
        echo "Can't resume. Checking size"
        contentLength=`$curlCommand -k -sLI "$linkLine" | grep -i 'Content-Length' | sed 's/.*:\s*\([0-9]*\).*/\1/'`
        existingLength=`stat --printf="%s" "$localFile"`
        echo "Remote length: $contentLength"
        echo "Local length: $existingLength"
        if [ $contentLength = 0 ] || [ $existingLength = $contentLength ]
        then
            echo "Not redownloading - Size not available or file already downloaded"
        else
            echo "Retrying download"
            rm "$localFile"
            $0 NORETRY "$@"
        fi
    else
        rm "$tmpfile"
        exit 3
    fi
fi

if grep -q "^REMOVE_DELETED" $UserConfig; then
	echo "$localFile" >> "$Lib/filesList.log"
	echo "Appended $localFile to filesList"
fi

if echo "$statusCode" | grep -q "200"; then
    mv $tmpfile $realfile
fi

echo "getRemoteFile ended"

