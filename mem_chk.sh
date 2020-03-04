#!/bin/bash

TMPFILE=/tmp/hc_server.$$.tmp

free -m > ${TMPFILE}

MEM_TOTAL=`cat ${TMPFILE} |head -2 |tail -1 |awk {'print $2'}`
MEM_CACHE=`cat ${TMPFILE} |head -3 |tail -1 |awk {'print $3'}`
SWAP_TOTAL=`cat ${TMPFILE} |tail -1 |awk {'print $2'}`
SWAP_USED=`cat ${TMPFILE} |tail -1 |awk {'print $3'}`

MEM_USED_PERCENT=$(awk "BEGIN { pc=100*${MEM_CACHE}/${MEM_TOTAL}; i=int(pc); print (pc-i<0.5)?i:i+1 }")
SWAP_USED_PERCENT=$(awk "BEGIN { pc=100*${SWAP_USED}/${SWAP_TOTAL}; i=int(pc); print (pc-i<0.5)?i:i+1 }")

echo "Memory is ${MEM_USED_PERCENT}\% used"
echo "Swap is ${SWAP_USED_PERCENT}\% used"

rm -f ${TMPFILE}
