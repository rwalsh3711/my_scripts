#!/bin/ksh

# Script for ensuring there is so much
# free space {$1} in filesystem {$2} on host {$3}
#
# Created: 1/11/2008
# By: Rick Walsh - richard_walsh@uhc.com
#
# Check that all variables exist

if [[ $# -lt 3 ]]; then
	echo "Usage:
	file_resize.ksh (Desired Free MBs) (filesystem) (hostname)
Example:
	file_resize.ksh 100 /usr zuhl"
	exit
fi

# Set variables

OS=`ssh -q $3 uname -a |awk {'print $1'}`
VER=`ssh -q $3 uname -a |awk {'print $3'}`

# Verify system is an AIX box running 5.2 minimum

if [ $OS != "AIX" ]; then
	echo "System is not an AIX host...exiting"
	exit
else
	if [ $VER -lt 2 ]; then
		echo "System is not running AIX 5.2 or above...exiting"
		exit
	fi
fi
# Gather the amount of current free space in MB
# from system and assign to "$MB_FREE"

MB_FREE_RAW=`ssh -q $3 df -m $2 |grep $2 |awk {'print $3'}`
MB_FREE=${MB_FREE_RAW%.*}

# Check MB_FREE against value in $1 and make
# changes if necessary

if [ $MB_FREE -gt $1 ]; then
	echo "Host $3 has $MB_FREE MB free in $2.  Your requirements are met."
	exit
else
	if [ $MB_FREE -lt $1 ]; then
		MB_DIFF=$(($1 - $MB_FREE))
		echo "Host $3 has $MB_FREE MB free in $2.  The system needs $MB_DIFF MB to meet your requirements."
		echo "Would you like to add $MB_DIFF MB to the $2 filesystem on $3 now? y|n"
		read YES_NO
		case $YES_NO in
		y|Y) 
			echo "I'll really do it...I'm serious.  I'm a firecracker with a short fuse if you're just pulling my chain. You sure? y|n"
			read YOU_SURE
			case $YOU_SURE in
			y|Y)
				echo "You got it, sparky!  Adding $MB_DIFF MB to $2 on $3!"
				ssh -q $3 chfs -a size=+"$MB_DIFF"M $2
				echo "Change is complete."
				exit
				;;
			n|N)
				echo "Geez...what a tease...exiting."
				exit
				;;
			*)
				echo "Nice fat-finger, tosspot...I'm outa here."
				exit
				;;
			esac
			;;
		n|N)
			echo "Okie-dokie, artichokie...Exiting"
			exit
			;;
		*)
			echo "Nice fat-finger, tosspot...I'm outa here..."
			exit
			;;
		esac
	fi
fi					
