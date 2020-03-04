#!/bin/ksh
#
# Script to determine if dyntrk is enabled
# and fc_err_recov is set to fast_fail on 
# fiber adapters
#
#########################
# Check variables exist #
#########################

if [[ $# != 1 ]]; then
        echo "ERROR - Script usage:\dyntrk_chk.ksh <host or hostlist file>\n"
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
	ADAPTERS=`ssh -q -o ConnectTimeout=10 $HOST "lsdev -C |grep fscsi" |awk {'print $1'}`
	echo $HOST
	echo ""
		for FC in $ADAPTERS
		do
		echo $FC: 
		ssh -q $HOST "lsattr -El $FC |grep dyntrk" |awk {'print $1 " = " $2'}
		ssh -q $HOST "lsattr -El $FC |grep fc_err_recov" |awk {'print $1 " = " $2'}
		echo ""
		done
	echo -----------------------------
done
