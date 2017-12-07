#!/bin/sh
#
# Script to check server type and model
#
if [ $# != 1 ] ; then
	echo "USAGE: ${0} <host_list_file>"
	exit 0
fi

echo "Enter user name:"
read USER

HOST_LIST=`cat $1`

for HOST in ${HOST_LIST}
	do
	# Check if the server is reachable first
		ping -c 1 $HOST &>/dev/null
		if [ $? != 0 ] ; then
			echo "${HOST}: Unreachable"		
			continue
		fi

	OS_TYPE=`ssh -q -l ${USER} ${HOST} "uname -s"`

	if [ $OS_TYPE = "AIX" ] ; then
		PLATFORM=`ssh -q -l ${USER} ${HOST} prtconf` |grep "System Model" |awk -F": " {'print $2'}
	#elif [ $OS_TYPE = "Linux" ] ; then
	#	PLATFORM=`ssh -q -l ${USER} ${HOST} "dmidecode -s system-product-name"`
	else
	       	PLATFORM="UNKNOWN"
	fi

	echo "${HOST}: OS - ${OS_TYPE} | PLATFORM - ${PLATFORM}"
	done


