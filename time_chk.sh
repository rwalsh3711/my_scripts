#!/bin/sh
#
# New Health Check Script
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
	printf "%-20s %-10s %-10s %-10s %-10s %-10s\n" "HOST" "PING" "SSH" "TZONE" "CDATE" "SDATE" ---- ---- --- ----- ----- -----

	for HOST in ${HOSTLIST}
	do
		# Test if the server is reachable
		ping -c 1 ${HOST} >/dev/null 2>&1
			if [ $? = 0 ] ; then    
				PING_STAT=`printf "OK!"`
			else
				PING_STAT=`printf "ERR!"`
				continue
			fi

		# Check if root user can log into host
		ssh -q -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "echo ok" >/dev/null 2>&1
			if [ $? = 0 ] ; then
				SSH_STAT=`printf "OK!"`
			else   
				SSH_STAT=`printf "ERR!"`
				continue
			fi

		# Gather server information
		CDATE=`date +%H:%m`
		SDATE=`ssh -q -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "date +%H:%m"`
		TZONE=`ssh -q -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "date +%Z"

		# Print results
		printf "%-20s %-10s %-10s %-10s %-10s %-10s\n" ${HOST} ${PING_STAT} ${SSH_STAT} ${TZONE} ${CDATE} ${SDATE}

	done
