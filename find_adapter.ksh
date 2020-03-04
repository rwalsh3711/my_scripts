#!/bin/ksh
#
# Script to find which host owns
# a particular adapter off a pSeries
# frame.
#
#########################
# Check variables exist #
#########################

if [[ $# != 1 ]]; then
        echo "ERROR - Script usage:\find_adapter.ksh <host or hostlist file>\n"
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

#
# Determine the hmc the frame is attached to
#

for FRAME in $I
do
echo "============================="
echo "Currently working on $FRAME"
echo "============================="

HMC=`seeisso $FRAME |grep console_access|awk -F": " {'print $2'}`
LPARS=`ssh -l hscroot $HMC "lssyscfg -r lpar -m $FRAME -F name"`
	for HOST in $LPARS
	do
	ADAPTERS=`ssh -q -o ConnectTimeout=10 $HOST "lsdev -Cc adapter |grep fcs" |awk {'print $1'}`
	echo $HOST:
		for FC in $ADAPTERS
		do
		echo $FC: `ssh -q $HOST "lscfg -vl $FC |grep Network"`
		done
	echo ""
	done
done
