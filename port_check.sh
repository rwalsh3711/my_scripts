#!/bin/bash

## VARIABLE ASSIGNMENTS ## 
ip_addr=$1
sport=$2
eport=$3

## DEFINING FUNCTIONS ##
nc_check () {
nc_stat=`rpm -qf \`which nc 2>/dev/null\` >/dev/null 2>&1; echo $?`
if [ $nc_stat != 0 ]; then
	echo "Ncat not installed.  Please install the \"nmap-ncat\" package and try again"
	echo ""
	exit 1
fi
}

single_port_scan () {
RC=`nc -zv ${ip_addr} ${sport} >/dev/null 2>&1; echo $?`
if [ $RC == 0 ]; then
	STATUS="OPEN"
else
	STATUS="CLOSED"
fi

printf "%-20s %-15s %-15s\n" ${ip_addr} ${sport} ${STATUS}
} 

multiple_port_scan () {
cport=${sport}
while [ ${cport} -le ${eport} ]
do
	RC=`nc -zv ${ip_addr} ${cport} >/dev/null 2>&1; echo $?`
	if [ $RC == 0 ]; then
		STATUS="OPEN"
	else
		STATUS="CLOSED"
	fi

	printf "%-20s %-15s %-15s\n" ${ip_addr} ${cport} ${STATUS}

	cport=$((cport+1))
done
} 

pcheck () {
ping -c1 -w3 ${ip_addr} >/dev/null 2>&1; if [ $? = 0 ]
	then printf "${ip_addr} reachable...beginning port scan\n\n"
	else printf "${ip_addr} not reachable...exiting\n\n"; exit 1
	fi
printf "%-20s %-15s %-15s\n" "HOST IP" "PORT" "STATUS"
}

## MAIN SCRIPT ##

echo ""
# Check that ncat is installed
nc_check

# Run the scan against the ports
if [ $# == 2 ]; then
	pcheck
	single_port_scan
elif [ $# == 3 ]; then 
	pcheck
	multiple_port_scan
else
	echo "Usage: $0 [ip_address] [single:starting port] [ending port]"
fi

echo ""
