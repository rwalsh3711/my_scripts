#!/usr/bin/ksh
# fixpage.ksh
# this script will adjust the paging space after a memory configuration change
# works on 5.3 and above
OSLEVEL=`oslevel -r`
if [[ $OSLEVEL < "5300-00" ]]; then
    echo "You must be at oslevel 5300-00 or higher to run this script!!"
    exit 1
fi
# What is our machine type
MACHTYPE=`lsattr -El sys0|grep modelname|awk '{print $2}'|awk -F, '{print $2}'`
# how much memory is on the box
REALMEM=`lsattr -El sys0 | grep realmem | awk '{print $2}'`
#
# what is the PP SIZE in rootvg
PPSIZE=$(( `lsvg rootvg | grep "PP SIZE" | awk '{print $6}'`))
#
# convert Real Memory in K to Bytes
PSPACENEEDED=$(( 1024 * REALMEM ))
#PSPACENEEDED=$(( 1000 * (REALMEM / 1024))) 
#
#####################################
# Paging Space Maximum Change 8/2005
#####################################
# Due to some people glomming 64GB of memory onto a single box
# We have decide to implement a cap on the paging space size to
# avoid filling up rootvg disks with huge paging spaces
#####################################
# Current Cap on paging space size is : 16 GB
#####################################
#
# Implement cap of 16GB on large memory systems
#
if (( $PSPACENEEDED > 16777216000 )); then
   PSPACENEEDED=16777216000
   PSPACENEEDED=$(( PSPACENEEDED / 1000 ))
   PSPACENEEDED=$(( PSPACENEEDED / 1000 ))
else
   PSPACENEEDED=$(( REALMEM / 1000 ))
fi
#
#
# Create a secondary paging space if this is not a 510

if [[ $MACHTYPE != '9110-51A' && $MACHTYPE != '9110-510' ]]; then
	if (( `lsvg -l rootvg | grep "paging" | wc -l` == 1 )); then
		echo "This is a $MACHTYPE so creating secondary paging space"
		if (( `lsvg -p rootvg|egrep -v "rootvg:|PV_NAME"|wc -l` >= 2 )); then
			CURRENTPSDISK=`lsps -a |grep hdisk|grep rootvg|awk '{print $2}'`
			NEWPSDISK=`lsvg -p rootvg |grep -Ev "$CURRENTPSDISK|PV_NAME|:"|head -1|awk '{print $1}'`
			mkps -s'1' -n'' -a'' rootvg $NEWPSDISK
		else
			echo "rootvg does not have 2 disks you cannot use this script to correct paging space"
			exit 1
		fi
	fi
	# how many PP's are needed
	PSPACENEEDEDPPS=$((PSPACENEEDED/PPSIZE))
	#
	PAGING1=`lsps -a | grep -v Physical |grep rootvg| head -1 | awk '{print $1}'`
	PAGING2=`lsps -a | grep -v Physical |grep rootvg| grep -v $PAGING1 | head -1 | awk '{print $1}'`
	# how many PP's are in paging space now
	PAGING1NOW=`lsvg -l rootvg | grep $PAGING1 | awk '{print $4}'`
	PAGING2NOW=`lsvg -l rootvg | grep $PAGING2 | awk '{print $4}'`
	#
	# how many more PP's need to be added to paging space number 1
	ADDPPS1=$(((PSPACENEEDEDPPS/2)-PAGING1NOW))
	#
	# how many more PP's need to be added to paging space number 1
	ADDPPS2=$(((PSPACENEEDEDPPS/2)-PAGING2NOW))
	#
	# Calculate a max of 8192KB based on PP size
	MAXLVPP=$(( 8384 / PPSIZE ))
	# okay lets display the calculations
	echo "Total Box Memory: $REALMEM"
	echo "Root VG PP Size:  $PPSIZE"
	echo "PS Space Needed:  $PSPACENEEDED"
	echo "PS PP's Needed:   $PSPACENEEDEDPPS"
	echo "Maximum LV PP'S:  $MAXLVPP"
	echo "Size of $PAGING1: $PAGING1NOW"
	echo "Size of $PAGING2:      $PAGING2NOW"
	echo "Adjustment to $PAGING1: $ADDPPS1"
	echo "Adjustment to $PAGING2:      $ADDPPS2"
	# We don't need more than 8GB per paging space set the max PP's for the LV
	chlv -x $MAXLVPP $PAGING1
	chlv -x $MAXLVPP $PAGING2
	#
	# increase or decrease paging space for ADDPPS1
	if (( $ADDPPS1 > 0 )); then
	   chps -s $ADDPPS1 $PAGING1
	elif (( $ADDPPS1 < 0 )); then
	   chps -d $(( ADDPPS1 * -1 )) $PAGING1
	fi
	#
	# increase paging space only if ADDPPS2 is positive.
	if (( $ADDPPS2 > 0 )); then
	   chps -s $ADDPPS2 $PAGING2
	elif (( $ADDPPS2 < 0 )); then
	   chps -d $(( ADDPPS2 * -1 )) $PAGING2
	fi
	#
	echo "paging space setup"
	lsps -a
else
	# how many PP's are needed
	PSPACENEEDEDPPS=$((PSPACENEEDED/PPSIZE))
	#
	PAGING1=`lsps -a | grep -v Physical | head -1 | awk '{print $1}'`
	# how many PP's are in paging space now
	PAGING1NOW=`lsvg -l rootvg | grep $PAGING1 | awk '{print $4}'`
	#
	# how many more PP's need to be added to paging space number 1
	ADDPPS1=$((PSPACENEEDEDPPS - PAGING1NOW))
	#
	# Calculate a max of 16000 KB based on PP size
	MAXLVPP=$(( 16000 / PPSIZE ))
	# okay lets display the calculations
	echo "Total Box Memory: $REALMEM"
	echo "Root VG PP Size:  $PPSIZE"
	echo "PS Space Needed:  $PSPACENEEDED"
	echo "PS PP's Needed:   $PSPACENEEDEDPPS"
	echo "Maximum LV PP'S:  $MAXLVPP"
	echo "Size of $PAGING1:      $PAGING1NOW"
	echo "Adjustment to $PAGING1:      $ADDPPS1"
	# We don't need more than 16GB per paging space set the max PP's for the LV
	chlv -x $MAXLVPP $PAGING1
	#
	# increase or decrease paging space for ADDPPS1
	if (( $ADDPPS1 > 0 )); then
	   chps -s $ADDPPS1 $PAGING1
	elif (( $ADDPPS1 < 0 )); then
	   chps -d $(( ADDPPS1 * -1 )) $PAGING1
	fi
	echo "paging space setup"
	lsps -a
fi
