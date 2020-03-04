#!/bin/ksh
#
# Script to check if server uses EMC Powerpath
#
#########################
# Check variables exist #
#########################

if [[ $# != 1 ]]; then
        echo "ERROR - Script usage:\EMC_chk.ksh <host or hostlist file>\n"
        exit
fi

#
# Determine if input is host or file
#
echo "Are you specifying a host(H) or a file(F)? H|F"
read TYPE

case $TYPE in
        H|h)
                echo "Running command on $1 as host"
                I=$1
                ;;
        F|f)
                echo "Running command on $1 as file"
                I=`cat $1`
                ;;
        *) echo "Invalid option. Exiting."
                exit 1
                ;;
esac

for HOST in $I
	do
	echo $HOST
	`ssh -q $HOST "powermt /help" ; if [ $? = 0 ]
                then echo $HOST >> EMC_server_list
                fi`
	done
