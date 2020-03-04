#!/bin/sh
# $Header: /usr/local/admin/bin/RCS/storm_hc.sh,v 1.1 2017/01/16 19:35:12 root Exp root $
#
# Health Check Script for Storm Mode
# Author - Rick Walsh
# Ver 1.0 - 12/29/2016
#

# if [ "$(id -u)" != "0" ]; then
#    echo -e "This script must be run as root" 1>&2
#    exit 1
# fi

## VARIABLES ##
HOSTLIST=hosts
TMPFILE=/tmp/hc_server.$$.tmp

## FUNCTIONS ##

# Function to check for filesystems greater than THRESHOLD
_chk_fs() {
echo -e "\t\t- FILESYSTEMS OVER ${THRESHOLD}% FULL -"	
EXCLUDE="/proc|/aha|/home|/boot|Filesystem"
THRESHOLD="85"

	if [ "${OS}" == "AIX" ]; then
		ssh ${HOST} "df -g" |egrep -v "${EXCLUDE}" |awk {'print $4"\t"$7'} > ${TMPFILE}
	elif [ "${OS}" == "Linux" ]; then
		ssh ${HOST} "df -hP" |egrep -v "${EXCLUDE}" |awk {'print $5"\t"$6'} > ${TMPFILE}
	else
		echo -e "Unknown OS"
		continue
	fi
	cat ${TMPFILE} |while read LINE
	do
	 	PERC=`echo -e $LINE |awk {'print $1'} |cut -d"%" -f1`	
		FS=`echo -e $LINE |awk {'print $2'}`	
		if [ $PERC -gt $THRESHOLD ] 2>/dev/null; then 
		echo -e $PERC%"\t"$FS
		fi
	done 
	rm -f ${TMPFILE}
	echo -e ""
}

# Function to check system memory
_chk_mem() 
{
echo -e "\t\t- MEMORY STATUS -"
	if [[ $OS == "Linux" ]]; then
		ssh ${HOST} "free -m" > ${TMPFILE}
		MEM_TOTAL=`cat ${TMPFILE} |head -2 |tail -1 |awk {'print $2'}`
		MEM_CACHE=`cat ${TMPFILE} |head -2 |tail -1 |awk {'print $3'}`
		SWAP_TOTAL=`cat ${TMPFILE} |tail -1 |awk {'print $2'}`
		SWAP_USED=`cat ${TMPFILE} |tail -1 |awk {'print $3'}`
	elif [[ $OS == "AIX" ]]; then
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

echo -e "Physical Memory is ${MEM_USED_PERCENT}% Used"
echo -e "Swap Space is ${SWAP_USED_PERCENT}% Used"
echo -e ""
rm -f ${TMPFILE}
}

# Function to check system CPU
_chk_cpu() {
echo -e "\t\t- SYSTEM CPU LOAD AVERAGE -" 
CPU_LOAD_THRESHOLD=90
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
        LOAD_TOT=`echo -e "scale=0; 100 * ${LOAD_AVG} / ${PROC_NUM}" |bc`

        if [ ${LOAD_TOT} -lt ${CPU_LOAD_THRESHOLD} ]; then
                echo -e "Load average is ${LOAD_TOT}% - OK!"
        else
                echo -e "Load average is ${LOAD_TOT}% - ERR!"
	fi
rm -f ${TMPFILE}
echo -e ""
}

# Function to report recent system error messages
_chk_err() {

NOW_AIX=$(date "+%m%d....%y")
NOW_LINUX=$(date "+%b.%e")
echo -e "\t\t- RECENT SYSTEM ERRORS -"
        if [ "${OS}" == "AIX" ]; then
                ssh ${HOST} "errpt -T"PEND,PERM""|grep "${NOW_AIX}"|head -n5
        elif [ "${OS}" == "Linux" ]; then
                ssh ${HOST} "cat /var/log/messages" |grep -i error|grep "${NOW_LINUX}"|cut -c 1-100 |tail -n5
        else
                echo -e "Unknown OS"
                continue
        fi
echo -e ""
}

# ## MAIN SCRIPT ##

for HOST in `cat ${HOSTLIST}`
do
echo -e ""
echo -e "############"
echo -e "# "${HOST}""
echo -e "############"

	# Test if the server is reachable
	echo -e "\t\t- PING RESULTS -"
	ping -c 1 ${HOST} >/dev/null 2>&1
		if [ $? = 0 ] ; then
		printf "${HOST} is Reachable\n"
		else
		printf "${HOST} is Not Reachable\n"
		continue
		fi
	echo -e ""

	# Check if root user can log into host
	echo -e "\t\t- SSH RESULTS -"
	ssh -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "echo -e ok" >/dev/null 2>&1
		if [ $? != 0 ] ; then
		echo -e "SSH Keys Not Installed"
		continue
		else
		echo -e "SSH Keys Installed Correctly"
		echo -e ""
		fi

	# Collect the OS Level
	OS=`ssh ${HOST} "uname -s"`
	if [ $OS != AIX ] && [ $OS != Linux ]; then
                echo -e "${HOST} is running ${OS}.  I refuse to work with ${OS}.  Please go pound sand."
                continue
        fi

	_chk_fs
	_chk_mem
	_chk_cpu
	_chk_err
done
