#!/bin/bash

DEBUG_PRINT=1
USE_SWAP=1

FAT_SIZE_MB=64
SWAP_SIZE_MB=64

NANOBOOT=nanoboot.bin

[ -f ${NANOBOOT}.xz ] && xz -d ${NANOBOOT}.xz
[ -f ${NANOBOOT} ] || {
    echo "${NANOBOOT} not found"
    exit 1
}

wc -c ${NANOBOOT} | {
   read SIZE NAME
   [ $SIZE -eq 262144 ] || {
      echo "Invalid size of ${NANOBOOT} file"
      exit 2
   }
}

# ----------------------------------------------------------
# Checking device for fusing

if [ -z $1 ]; then
	echo "Usage: $0 DEVICE [sd]"
	exit 0
fi

case $1 in
/dev/sd[a-z] | /dev/loop0 | /dev/mmcblk[0-9])
	if [ ! -e $1 ]; then
		echo "Error: $1 does not exist."
		exit 1
	fi
	DEV_NAME=`basename $1`
	BLOCK_CNT=`cat /sys/block/${DEV_NAME}/size`;;
*)
	echo "Error: Unsupported SD reader"
	exit 0
esac

if [ -z ${BLOCK_CNT} -o ${BLOCK_CNT} -le 0 ]; then
	echo "Error: $1 is inaccessible. Stop fusing now!"
	exit 1
fi

if [ ${BLOCK_CNT} -gt 134217727 ]; then
	echo "Error: $1 size (${BLOCK_CNT}) is too large"
	exit 1
fi

if [ "sd$2" = "sdsd" -o ${BLOCK_CNT} -le 4194303 ]; then
	echo "Card type: SD"
	BL1_OFFSET=0
else
	echo "Card type: SDHC"
	BL1_OFFSET=1024
fi

BL1_SIZE=16
ENV_SIZE=32
BL2_SIZE=512

FAT_POSITION=2048

let FAT_SIZE=${FAT_SIZE_MB}*2048
let SWAP_SIZE=${SWAP_SIZE_MB}*2048

let BL1_POSITION=${BLOCK_CNT}-${BL1_OFFSET}-${BL1_SIZE}-2
let ENV_POSITION=${BL1_POSITION}-${ENV_SIZE}
let BL2_POSITION=${ENV_POSITION}-${BL2_SIZE}

let EXT4_POSITION=${FAT_POSITION}+${FAT_SIZE}
let EXT4_SIZE=${BL2_POSITION}-${FAT_POSITION}-${FAT_SIZE}

if [ ${USE_SWAP} -eq 1 ]; then
	let EXT4_SIZE=${EXT4_SIZE}-${SWAP_SIZE}
	let SWAP_POSITION=${EXT4_POSITION}+${EXT4_SIZE}
fi

if [ ${DEBUG_PRINT} -eq 1 ]; then
	let FAT_END=${FAT_POSITION}+${FAT_SIZE}
	let EXT4_END=${EXT4_POSITION}+${EXT4_SIZE}
	let SWAP_END=${SWAP_POSITION}+${SWAP_SIZE}
	let BL2_END=${BL2_POSITION}+${BL2_SIZE}
	let ENV_END=${ENV_POSITION}+${ENV_SIZE}
	let BL1_END=${BL1_POSITION}+${BL1_SIZE}

	echo
	printf "%8s %9s %9s %8s\n" "" SIZE START END
	echo "--------------------------------------"
	printf "%8s %9d %9d %9d\n" FAT: ${FAT_SIZE} ${FAT_POSITION} ${FAT_END}
	printf "%8s %9d %9d %9d\n" EXT4: ${EXT4_SIZE} ${EXT4_POSITION} ${EXT4_END}
	if [ ${USE_SWAP} ]; then
		printf "%8s %9d %9d %9d\n" SWAP: ${SWAP_SIZE} ${SWAP_POSITION} ${SWAP_END}
	fi
	printf "%8s %9d %9d %9d\n" BL2: ${BL2_SIZE} ${BL2_POSITION} ${BL2_END}
	printf "%8s %9d %9d %9d\n" ENV: ${ENV_SIZE} ${ENV_POSITION} ${ENV_END}
	printf "%8s %9d %9d %9d\n" BL1: ${BL1_SIZE} ${BL1_POSITION} ${BL1_END}
	echo "--------------------------------------"
	printf "%-28s %9d\n" "TOTAL BLOCKS" ${BLOCK_CNT}
	echo "--------------------------------------"
	echo

    # exit
fi

echo "---------------------------------"
echo "Partitioning /dev/${DEV_NAME}"

{
    echo "${FAT_POSITION},${FAT_SIZE},0x0B,*"
    echo "${EXT4_POSITION},${EXT4_SIZE},0x83,-"

    if [ ${USE_SWAP} ]; then
        echo "${SWAP_POSITION},${SWAP_SIZE},0x82,-"
    fi
} | sfdisk -u S -f --Linux -q /dev/${DEV_NAME}

if [ $? -ne 0 ]; then
    echo 'Fail to create partitions'
    exit 1
fi

# ----------------------------------------------------------
# Fusing uboot, kernel to card

echo "---------------------------------"
echo "BL2 fusing"
dd if=${NANOBOOT} of=/dev/${DEV_NAME} bs=512 seek=${BL2_POSITION} count=512 conv=fdatasync status=none

echo "---------------------------------"
echo "BL1 fusing"
dd if=${NANOBOOT} of=/dev/${DEV_NAME} bs=512 seek=${BL1_POSITION} count=16 conv=fdatasync status=none

sync

echo "---------------------------------"
echo "fused successfully."

partprobe /dev/${DEV_NAME} || {
    echo "Re-read the partition table failed."
    exit 1
}

echo "---------------------------------"
echo "Rootfs is fused successfully."


