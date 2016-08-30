#!/bin/bash

BASE_URL="https://www.raspberrypi.org/downloads/raspbian/"
URL="https://downloads.raspberrypi.org/raspbian_lite_latest"
CHUNK_COUNT=10

echo "Pi-On - Make your Pi ready"
echo "=========================="

if [[ $# -ne 1 ]]
then
    echo "Please specify disk id, e.g. disk2."
    echo "Here is the list of your devices."
    diskutil list
    exit 1
fi

DISKID=$1

echo "Verifying disk ID"
DISK="$(diskutil list | grep /dev/${DISKID})"
if [ "${DISK}" == "" ]
then
    echo "==> /dev/${DISKID} is not accessible. Please ensure that ${DISKID} is mounted to your computer."
    exit 1
fi

echo "Downloading archived image from ${URL}"
FILE_SIZE="$(curl --head --silent -L $URL | grep -i content-length | awk '{print $2}' | tr -d '\r')"
CHUNK_SIZE="$(expr ${FILE_SIZE} / ${CHUNK_COUNT})"
CHUNK_MAX_INDEX="$(expr ${CHUNK_COUNT} - 1)"
pids=""
echo "==> Spawning concurrent downloads. This may take a few minutes. Be patient. :)"
for i in `seq 0 ${CHUNK_MAX_INDEX}`;
do
    FROM_BYTES="$(expr ${i} \* ${CHUNK_SIZE})"
    TO_BYTES="$(expr ${FROM_BYTES} + ${CHUNK_SIZE} - 1)"
    if [ $i -eq $CHUNK_MAX_INDEX ];
    then
        curl --silent --range ${FROM_BYTES}- -o temp.part${i} -L ${URL} &
    else
        curl --silent --range ${FROM_BYTES}-${TO_BYTES} -o temp.part${i} -L ${URL} &
    fi
    pids="$pids $!"
done
wait $pids
cat temp.part? > temp.zip

echo "Verifying archive"
RESOURCE="$(curl --silent ${BASE_URL})"
SHA1="$(openssl sha1 temp.zip | awk '{print $2}')"
if [[ $RESOURCE != *"${SHA1}"* ]]
then
    echo "==> Incorrect archive checksum. Operation aborted."
    exit -1
fi

echo "Unpacking archive"
unzip -o temp.zip
IMG_NAME="$(ls *.img)"

echo "Cleaning up"
rm temp.part?
rm temp.zip

echo "Preparing disk"
diskutil eraseDisk FAT32 RASPBIAN MBRFormat /dev/${DISKID}
diskutil unmountDisk ${DISKID}

echo "Moving image to disk"
echo "==> Writing image to disk may take some time. You may move your body for a good health."
dd bs=1m if=./${IMG_NAME} of=/dev/r${DISKID}

echo "Done. Thank you."
