#!/bin/sh
#
# Run a ping check against a
# list of servers.
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
        ping -c 1 ${HOST} >/dev/null 2>&1
        if [ $? = 0 ] ; then
        	ILMT_CNT=`ssh ${HOST} "ps -ef" |grep tlmagent |grep -v grep |wc -l`
		if [ $ILMT_CNT -gt 0 ]; then 
			printf "ILMT Agent Running\n"
		else
			printf "ILMT Agent NOT Running\n"
		fi	
        else
        	printf "Not reachable\n"
        fi
	done
