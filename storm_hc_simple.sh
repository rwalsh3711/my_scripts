#!/bin/sh
#
# New Storm Health Check Script
# Author - Rick Walsh
# Ver 1.0 - 12/29/2016
#

## Notification to run as root ##

	if [ "$(id -u)" != "0" ]; then
	   echo "This script must be run as root" 1>&2
	   exit 1
	fi

## VARIABLES ##

	FS_FULL_THRESHOLD=85
	MEM_USED_THRESHOLD=95
	SWAP_USED_THRESHOLD=80
	CPU_LOAD_THRESHOLD=90
	TMPFILE=/tmp/hc_file.$$.tmp
	ERRTMP=/tmp/err_tmp.$$.tmp
	ERRFILE=/tmp/hc_err_file.tmp
	HOSTLIST=/usr/local/admin/lists/storm_servers


## FUNCTIONS ##

# Function to check for filesystems greater than THRESHOLD
_chk_fs() {
	EXCLUDE="/proc|/aha|/home|/boot|:|Filesystem"

        if [ "${OS}" == "AIX" ]; then
                ssh ${HOST} "df -g" |egrep -v "${EXCLUDE}" |awk {'print $4"\t"$7'} > ${TMPFILE}
        elif [ "${OS}" == "Linux" ]; then
                ssh ${HOST} "df -hP" |egrep -v "${EXCLUDE}" |awk {'print $5"\t"$6'} > ${TMPFILE}
        else
                continue
        fi

        FS_FULL=0
        cat ${TMPFILE} |while read LINE
        do
                PERC=`echo ${LINE} |awk {'print $1'} |cut -d"%" -f1`
                FS=`echo ${LINE} |awk {'print $2'}`
                if [ ${PERC} -gt ${FS_FULL_THRESHOLD} ] 2>/dev/null; then
			echo ${PERC}%"\t"${FS} >> ${ERRTMP}
                	FS_FULL=$(( ${FS_FULL} + 1 ))
                fi
        done    

        if [ ${FS_FULL} -lt 1 ]; then
                FS_STAT=`printf "OK!"`
        else    
                FS_STAT=`printf "ERR!"`
        fi

        rm -f ${TMPFILE}
}


# Function to check system memory
_chk_mem() {
        if [[ ${OS} == "Linux" ]]; then
                ssh ${HOST} "free -m" > ${TMPFILE}
                MEM_TOTAL=`cat ${TMPFILE} |head -2 |tail -1 |awk {'print $2'}`
                MEM_CACHE=`cat ${TMPFILE} |head -3 |tail -1 |awk {'print $3'}`
                SWAP_TOTAL=`cat ${TMPFILE} |tail -1 |awk {'print $2'}`
                SWAP_USED=`cat ${TMPFILE} |tail -1 |awk {'print $3'}`
        elif [[ ${OS} == "AIX" ]]; then
                ssh ${HOST} "svmon -G -O unit=MB" > ${TMPFILE}
                MEM_TOTAL=`cat ${TMPFILE} |head -4 |tail -1 |awk {'print $2'}`
                MEM_CACHE=`cat ${TMPFILE} | head -4|tail -1| awk {'print $6'}`
                SWAP_TOTAL=`cat ${TMPFILE} | head -5|tail -1| awk {'print $3'}`
                SWAP_USED=`cat ${TMPFILE} | head -5|tail -1| awk {'print $4'}`
        else
                continue
        fi

	MEM_USED_PERCENT=$(awk "BEGIN { pc=100*${MEM_CACHE}/${MEM_TOTAL}; i=int(pc); print (pc-i<0.5)?i:i+1 }")
	SWAP_USED_PERCENT=$(awk "BEGIN { pc=100*${SWAP_USED}/${SWAP_TOTAL}; i=int(pc); print (pc-i<0.5)?i:i+1 }")

	if [ ${MEM_USED_PERCENT} -lt ${MEM_USED_THRESHOLD} ]; then
                MEM_STAT=`printf "OK!"`
        else
                MEM_STAT=`printf "ERR!"`
		echo "" >> ${ERRTMP}
		echo "Physical Memory is ${MEM_USED_PERCENT}% Used" >> ${ERRTMP}
		echo "" >> ${ERRTMP}
        fi
	if [ ${SWAP_USED_PERCENT} -lt ${SWAP_USED_THRESHOLD} ]; then
		SWAP_STAT=`printf "OK!"`
	else
		SWAP_STAT=`printf "ERR!"`
		echo "Swap Space is ${SWAP_USED_PERCENT}% Used" >> ${ERRTMP}
		echo "" >> ${ERRTMP}
	fi
	rm -f ${TMPFILE}
}

# Function to check system load
_chk_cpu() {
	if [[ ${OS} == "Linux" ]]; then
		ssh ${HOST} "getconf _NPROCESSORS_ONLN" > ${TMPFILE}
		PROC_NUM=`cat ${TMPFILE}`
        elif [[ ${OS} == "AIX" ]]; then
		ssh ${HOST} "lparstat -i" > ${TMPFILE}
		PROC_NUM=`cat ${TMPFILE} |grep ^Active\ Phys |awk -F": " {'print $2'}`
        else
                continue
        fi
	
	ssh ${HOST} "uptime" > ${TMPFILE}
	LOAD_AVG=`cat ${TMPFILE} |awk '{print $(NF-1) }'|awk -F, {'print $1'}`
	LOAD_TOT=`echo "scale=0; 100 * ${LOAD_AVG} / ${PROC_NUM}" |bc`
	
        if [ ${LOAD_TOT} -lt ${CPU_LOAD_THRESHOLD} ]; then
                CPU_STAT=`printf "OK!"`
        else
                CPU_STAT=`printf "ERR!"`
		echo "System Load Threshold is ${CPU_LOAD_THRESHOLD}%" >> ${ERRTMP}
		echo "" >> ${ERRTMP}
        fi
	rm -f ${TMPFILE}
}

## MAIN SCRIPT ##

	printf "\n\n"
	printf "%-20s %-10s %-10s %-10s %-10s %-10s %-10s\n" "HOST" "PING" "SSH" "FS" "MEM" "SWAP" "CPU" ---- ---- --- -- --- ---- ---

	for HOST in `cat ${HOSTLIST}`
	do
		# Test if the server is in DNS and reachable
		host ${HOST} >/dev/null 2>&1
			if [ $? != 0 ]; then
				printf "%-20s %-10s\n" ${HOST} "Server Not Found"
				continue
			fi

		ping -c 1 ${HOST} >/dev/null 2>&1
			if [ $? = 0 ] ; then    
				PING_STAT=`printf "OK!"`
			else
				printf "%-20s %-10s\n" ${HOST} "Server Not Pingable"
				continue
			fi

		# Check if root user can log into host
		ssh -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "echo ok" >/dev/null 2>&1
			if [ $? = 0 ] ; then
				SSH_STAT=`printf "OK!"`
			else   
				printf "%-20s %-10s %-10s\n" ${HOST} "OK!" "SSH Keys Not Installed"
				continue
			fi

		# Collect the OS Level
		OS=`ssh ${HOST} "uname -s"`
			if [ ${OS} != AIX ] && [ ${OS} != Linux ]; then
				continue
			fi

		# Run functions
		_chk_fs
		_chk_mem
		_chk_cpu

		# Create error report for host if necessary
		if [ -f ${ERRTMP} ]; then
			echo "### ${HOST} ###" >> ${ERRFILE}
			cat ${ERRTMP} >> ${ERRFILE}
			echo "" >> ${ERRFILE}
			rm -f ${ERRTMP}
		fi

		# Print results
		printf "%-20s %-10s %-10s %-10s %-10s %-10s %-10s\n" ${HOST} ${PING_STAT} ${SSH_STAT} ${FS_STAT} ${MEM_STAT} ${SWAP_STAT} ${CPU_STAT}

	done
