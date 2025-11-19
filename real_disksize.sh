#!/bin/bash

PS4='${LINENO}: '


logfile=/tmp/${script}.log

script=$(basename "${BASH_SOURCE[0]}")

usage() {
    echo "Usage: $script /dev/sdX -c <size>"
    echo "  -c <size>    Chunk size (64/128/512/1024)"
    exit 1
}

# Allowed sizes for quick validation
VALID_SIZES="64 128 512 1024"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -c)
            [[ -z "$2" ]] && echo "Error: -c requires a size argument" && usage
            case " $VALID_SIZES " in
                *" $2 "*) CHUNK_SIZE="$2" ;;
                *) echo "Error: Invalid chunk size '$2'"; usage ;;
            esac
            shift 2
            ;;
        *)
            # Positional arg -> must be block device
            if [[ -b "$1" ]]; then
                DEV="$1"
            else
                echo "Error: '$1' is not a valid block device"
                usage
            fi
            shift
            ;;
    esac
done

# Optional: sanity check required args
[[ -z "$DEV" ]] && echo "Error: Missing device" && usage
[[ -z "$CHUNK_SIZE" ]] && echo "Error: Missing required -c <size>" && usage

echo "Device: $DEV"
echo "Chunk size: $CHUNK_SIZE"


# ----------------------------
#   Start Timer
# ----------------------------
START_TIME=$(date +%s)

# ----------------------------
#   Basic Values
# ----------------------------

SECTOR_SIZE=512
CHUNK_SIZE=512
CHUNK_SECTORS=$(( $CHUNK_SIZE * 1024 * 1024 / 512 ))   # $CHUNK_SIZE MiB per scan step
TOTAL_SECTORS=$(blockdev --getsz "$DEV")
TOTAL_BYTES=$(blockdev --getsize64 "$DEV")

TOTAL_GIB=$(echo "scale=2; $TOTAL_BYTES/1024/1024/1024" | bc -l)

echo "===================================================="
echo " Device          : $DEV"
echo " Logical Sector  : $SECTOR_SIZE bytes"
echo " Total Sectors   : $TOTAL_SECTORS"
echo " Disk Size GiB   : $TOTAL_GIB GiB"
echo " Scan Chunk Size : $CHUNK_SIZE MiB ($CHUNK_SECTORS sectors)"
echo "===================================================="
echo

# ----------------------------
#   Probe Functions
# ----------------------------

probe_range() {
    local start=$1
    local sectors=$2
    dd if="$DEV" of=/dev/null bs=$SECTOR_SIZE skip=$start count=$sectors 2>&1 \
        | grep -q '^'"$sectors"'+0 records in'
}

probe_single() {
    local lba=$1
    dd if="$DEV" of=/dev/null bs=$SECTOR_SIZE skip=$lba count=1 2>&1 \
        | grep -q '^1+0 records in'
}

# ----------------------------
#   Phase 1: Coarse Scan
# ----------------------------

echo "Phase 1: Coarse scan ($CHUNK_SIZE MiB steps)..."
pos=0
while (( pos + CHUNK_SECTORS <= TOTAL_SECTORS )); do
    if probe_range $pos $CHUNK_SECTORS; then
        pos=$(( pos + CHUNK_SECTORS ))
    else
        break
    fi
done

echo " - Coarse readable area ends near LBA: $pos"

BAD_START=$pos
BAD_END=$(( pos + CHUNK_SECTORS ))
(( BAD_END > TOTAL_SECTORS )) && BAD_END=$TOTAL_SECTORS

echo
echo "Phase 2: Binary search for exact last good LBA..."

lo=$(( BAD_START > 0 ? BAD_START - 1 : 0 ))
hi=$BAD_START

while (( lo + 1 < hi )); do
    mid=$(( (lo + hi) / 2 ))
    if probe_single $mid; then
        lo=$mid
    else
        hi=$mid
    fi
done

LAST_GOOD_LBA=$lo
LAST_GOOD_BYTE=$(( lo * SECTOR_SIZE ))
LAST_GOOD_GIB=$(echo "scale=4; $LAST_GOOD_BYTE/1024/1024/1024" | bc -l)

# ----------------------------
#   Finish Timer
# ----------------------------
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))

# convert to HH:MM:SS
printf -v ELAPSED_HMS "%02d:%02d:%02d" $((ELAPSED/3600)) $(( (ELAPSED%3600)/60 )) $((ELAPSED%60))

echo
echo "===================== RESULT ======================="
echo "Last Readable LBA    : $LAST_GOOD_LBA"
echo "Last Readable Byte   : $LAST_GOOD_BYTE"
echo "Readable GiB         : $LAST_GOOD_GIB GiB"
echo "----------------------------------------------------"
echo "Actual Disk Size     : $TOTAL_GIB GiB"
echo "Time Elapsed         : $ELAPSED_HMS (HH:MM:SS)"
echo "===================================================="
