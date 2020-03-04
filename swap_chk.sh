#!/bin/bash

TMPFILE=/tmp/swap_chk.tmp

free -m > ${TMPFILE}

SWAP_TOTAL=`cat ${TMPFILE} |tail -1 |awk {'print $2'}`
SWAP_USED=`cat ${TMPFILE} |tail -1 |awk {'print $3'}`

SWAP_USED_PERCENT=$(awk "BEGIN { pc=100*${SWAP_USED}/${SWAP_TOTAL}; i=int(pc); print (pc-i<0.5)?i:i+1 }")

if [ ${SWAP_USED_PERCENT} -gt 50 ]; then
	(
	echo "From: root@${HOSTNAME}"
	echo "To: hsid_mysql_alert_DL@ds.uhc.com; hsid-ops@uhg.flowdock.com"
	echo "MIME-Version: 1.0"
	echo "Subject: Server $HOSTNAME swap is ${SWAP_USED_PERCENT}% utilized"
	echo "Content-Type: text/html"
	echo "<FONT FACE='COURIER NEW' SIZE='4'><PRE>"
	cat ${TMPFILE}
	echo "</PRE></FONT>" ) | /usr/sbin/sendmail -t
else
	exit
fi

rm -f ${TMPFILE}
