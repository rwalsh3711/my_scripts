#!/bin/sh
#
# Check time zone settings
# Author - Rick Walsh
# Ver 1.0 - 12/29/2016
#

## Notification to run as root ##

	if [ "$(id -u)" != "0" ]; then
	   echo "This script must be run as root" 1>&2
	   exit 1
	fi

## Collect host information ##

	echo "What is the name of the server or host file?"

	read ANSWER

	echo "Is \""${ANSWER}"\" a (s)erver or a (f)ile?"
	printf "Enter (s) or (f): "
	read ANS
	if [ ${ANS} == "s" ]; then
		HOSTLIST=${ANSWER}
	elif [ ${ANS} == "f" ]; then
		HOSTLIST=`cat ${ANSWER}`
	else
		echo "Invalid answer"
		exit 0
	fi


## MAIN SCRIPT ##

	clear
	printf "\n\n"
	printf "%-20s %-10s %-10s %-10s %-10s\n" "HOST" "TZONE" "CTIME" "STIME" "STATUS" ---- ---- --- ----- -----

	for HOST in ${HOSTLIST}
	do
		# Gather server time zone
		  
		# Gather the server time 
		SINFO=`ssh -q -o BatchMode=yes -o ConnectTimeout=5 ${HOST} 'date +%H:%m" "%Z'`
		STIME=$( echo "$SINFO" |awk {'print $1'} )
		TZONE=$( echo "$SINFO" |awk {'print $2'} )
		# Check current modified time to server time
		CTIME=`date +%H:%m`

		if [ $CTIME == $STIME ]; then
			STATUS="OK!"
		else
			STATUS="ERR!"
		fi

		# Print results
		printf "%-20s %-10s %-10s %-10s %-10s\n" ${HOST} ${TZONE} ${CTIME} ${STIME} ${STATUS}

	done
