#!/bin/ksh
#
# Script to run through Solaris PLM Checklist
#
# Created 1/30/2012
# Author: Rick Walsh
#
#########################
# Check variables exist #
#########################

if [[ $# != 1 ]]; then
        echo "ERROR - Script usage:\.solaris_plm_checklist.ksh <host or hostlist file>\n"
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
	echo "Running PLM Checklist on $HOST"
	echo "."
	ssh -q $HOST "uname -a" > $HOST.plm_info
	ssh -q $HOST "df -k /" >> $HOST.plm_info
	echo "" >> $HOST.plm_info
	echo ".."
	ssh -q $HOST "vxprint -g rootdg -htv" >> $HOST.plm_info
	echo "" >> $HOST.plm_info
        echo "..."
	ssh -q $HOST "pkginfo -l VRTSvxvm" >> $HOST.plm_info
	echo "" >> $HOST.plm_info
	ssh -q $HOST "pkginfo -l VRTSvcs" >> $HOST.plm_info
	echo "" >> $HOST.plm_info
	ssh -q $HOST "pkginfo -l |grep -i dlm" >> $HOST.plm_info
	echo "" >> $HOST.plm_info
	ssh -q $HOST "pkginfo -l |grep -i emc" >> $HOST.plm_info
	echo "" >> $HOST.plm_info
	echo "...."
	ssh -q $HOST "luxadm fcode_download -p" >> $HOST.plm_info
	echo "" >> $HOST.plm_info
	ssh -q $HOST "prtdiag -v |grep -i obp" >> $HOST.plm_info
	echo "PLM Scan complete"
done
