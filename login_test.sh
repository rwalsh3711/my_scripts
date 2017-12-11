#!/bin/sh
#
# Run a check for root user to access
# a list of servers.
#
trap "exit" INT

if [ $# != 1 ] ; then
	echo "USAGE: ${0} <host_list_file>"
	exit 0
fi

HOSTLIST=`cat $1`

for HOST in ${HOSTLIST}
        do
        printf "${HOST}: "
        ssh -oBatchMode=yes -oConnectTimeout=5 ${HOST} "date" >/dev/null 2>/dev/null
        if [ $? = 0 ] ; then
        	printf "Accessible\n"
        else
        	printf "Not accessible\n"
        fi
	done
