#!/bin/ksh
#
# Script to automate the pre-work
# process for an AIX upgrade
#
# Created: 1/25/2008
# Author: Rick Walsh
# richard_walsh@uhc.com
#
#########################
# Check variables exist #
#########################

if [[ $# != 1 ]]; then
        echo "ERROR - Script usage:\ml_upgrade.ksh <host or hostlist file>\n"
        exit
fi


#########################
# Set global variables  #
#########################

UPGRADE_DIR=/tmp/UPGRADE_TL5-CSP
GET_CONFIGS_DIR=nima8001:/uht_packages/GETCFGS
AIX_QA_DIR=nima8001:/uht_packages/AIX53
MY_SCRIPTS=/home/rwalsh2/SCRIPTS
MK_BACKUPS=mk_backups.ksh
NIMCLIENT_CONFIG=nimclient_config.ksh
AIX_QA=AIX53_QA_script.ksh
GET_CONFIGS=get_configs_AIX
SYSBACK=/usr/local/bin/sysback_svr.ksh

#########################
# Define scripts to run #
#########################
#
# Script to check for Efixes on AIX systems
# and remove them
#
_efix_chk() {

EFIXES=`ssh -q $HOST emgr -P |grep -v -E "PACKAGE|=|There is no efix data" |awk {'print $3'} |awk '$0!~/^$/ {print $0}'`
if [[ "$EFIXES" = '' ]]; then
	echo "No efixes found on $HOST"
else
	while true
	do
       	echo "Efixes found on host $HOST. Would you like to remove? Y|N"
       	read REMOVE
		if [[ $REMOVE != Y && $REMOVE != y && $REMOVE != N && $REMOVE != n ]]; then
			echo "Invalid option.  Please try again.."
		else
      			case $REMOVE in
       			Y|y)
       	        		echo "Removing Efixes..."
				for a in $EFIXES
					do
       	        			ssh -q $HOST emgr -r -L $a
					done
       	        		echo "Efixes removed from $HOST.  Verifying..."
       	        		ssh -q $HOST emgr -P
				break
       	        		;;
       			N|n)
       		        	echo "Efixes found but not removed."
				break
       		        	;;
       			esac
		fi
	done
fi
echo ""
}

#
# Script to commit all current filesets
#
_commit_lpps() { 
ssh -q $HOST /usr/lib/instl/sm_inst installp_cmd -c -f'all' '-g' '-X'
if [[ $? -ne 0 ]] ; then
	echo "Error commiting filesets on $HOST. Please repair before continuing."
	exit 1
else
	echo "Filesets commited on $HOST. Continuing..."
	break
fi
echo ""
}

#
# Script to verify the necessary 700MB
# exists in the /usr filesystem
#
_usr_chk() {

MB_FREE_RAW=`ssh -q $HOST df -m /usr |grep /usr |awk {'print $3'}`
MB_FREE=${MB_FREE_RAW%.*}

if [ $MB_FREE -gt 699 ]; then
        echo "Host $HOST has $MB_FREE MB free in /usr.  Your requirements are met."
        break
else
        MB_DIFF=$((700 - $MB_FREE))
        echo "Host $HOST has $MB_FREE MB free in /usr.  The system needs $MB_DIFF MB to meet upgrade requirements."
	while true
	do
        	echo "Would you like to add $MB_DIFF MB to the /usr filesystem on $HOST now? y|n"
        	read YES_NO
		if [[ $YES_NO != Y && $YES_NO != y && $YES_NO != N && $YES_NO != n ]]; then
			echo "Invalid option.  Please try again.."
		else
        		case $YES_NO in
        		y|Y)
				while true
				do										
                			echo "You sure? y|n"
                			read YOU_SURE
					if [[ $YOU_SURE != Y && $YOU_SURE != y && $YOU_SURE != N && $YOU_SURE != n ]]; then
                       		 		echo "Invalid option.  Please try again.."
              		  		else
                				case $YOU_SURE in
                				y|Y)
                        				echo "Adding $MB_DIFF MB to /usr on $HOST"
                        				ssh -q $HOST chfs -a size=+"$MB_DIFF"M /usr
							if [ $? -eq 0 ] ; then
								echo "Error occured while attempting to modify this host. Please correct before continuing." 
								exit 1
							else
								echo "Change is complete."
								break
							fi
                        				;;
                				n|N)
                        				echo "Change not made. /usr remains at $MB_FREE"
                        				break
                       		 			;;
               		 			esac
					fi
				done
                        	;;
        		n|N)
                		echo "Change not made. /usr remains at $MB_FREE"
                		break
                		;;
        		esac
		fi
	done
fi
echo ""
}

#
# Script to configure host as NIM client
#
_nimclient_config() {
while true
do
        echo "Please enter the primary network interface for $HOST (e.g. en0): "
        read PRI_INT
        echo "Please enter the NIM server hostname for $HOST (e.g. nima8001): "
        read NIM_SERV
        echo "You entered $PRI_INT for the primary network interface and $NIM_SERV for the NIM server host.  Is this correct? Y|N: "
        read VERIFY
        case $VERIFY in
              	Y|y)
                      	echo "Configuring $HOST as NIM client with the supplied settings..."
                      	ssh -q $HOST "$UPGRADE_DIR/$NIMCLIENT_CONFIG -n $HOST -i $PRI_INT -m $NIM_SERV -P chrp -S nimsh"
                      	if [[ $? -ne 0 ]]; then
                       	       echo "Configuration of $HOST as NIM client failed. Please configure manually"
                       	       break
                      	else
                       	       echo "$HOST configured as NIM client on $NIM_SERV successfully!"
                       	       break
                      	fi
                      	;;
              	N|n)
                     	echo "Please enter settings again"
                      	;;
		*)
			echo "Invalid option.  Please enter settings again"
			;;		
              	esac
done
echo ""
}

###############
# Main Script #
###############
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
# Gather the latest scripts to be run and create tarball
#
echo "Gathering scripts for deployment..."
scp -q $GET_CONFIGS_DIR/$GET_CONFIGS .
scp -q $AIX_QA_DIR/$AIX_QA .
cp $MY_SCRIPTS/$MK_BACKUPS .
cp $MY_SCRIPTS/$NIMCLIENT_CONFIG .
chmod 744 $GET_CONFIGS
chmod 744 $AIX_QA
chmod 744 $MK_BACKUPS
chmod 744 $NIMCLIENT_CONFIG

tar -cf ml_update.tar $GET_CONFIGS $AIX_QA $MK_BACKUPS $NIMCLIENT_CONFIG

if [ $? -ne 0 ] ; then
       echo "Error occured gathering necessary scripts.  Exiting."
       exit 1
else
       echo "Scripts gathered successfully. Continuing..."
       break
fi

chmod 744 ml_update.tar

rm $GET_CONFIGS
rm $AIX_QA
rm $MK_BACKUPS
rm $NIMCLIENT_CONFIG

#
# Ask if SYSBACK has been run on hosts
#
echo "Please verify SYSBACK has run on all hosts.  Has SYSBACK already been run on host(s)? Y|N"
read SYSBACK_YN
if [[ $SYSBACK_YN = Y || $SYSBACK_YN = y ]]; then
	echo "Continuing...."
else
	echo "Please run $SYSBACK on host(s)"
	exit
fi

#
# Begin running loop on each system
#
for HOST in $I
do
echo "============================="
echo "Currently working on $HOST"
echo "============================="

#
# Set variables
#
OS=`ssh -q $HOST uname -a |awk {'print $1'}`
VER=`ssh -q $HOST uname -a |awk {'print $3'}`

#
# Verify system is an AIX box running 5.3 minimum
#
if [[ $OS != "AIX" || $VER -lt 3 ]]; then
        echo "$HOST is not an AIX host or is not running AIX 5.3"
        break
else
	echo "$HOST is an AIX host running 5.3...continuing"
fi	 

#
# Copy files to host, create backups, gather info and run bosboot
#
issotrim $HOST >> cons.lst
echo "Copying necessary files to $HOST"
ssh -q $HOST "mkdir $UPGRADE_DIR"
scp -q ml_update.tar $HOST:$UPGRADE_DIR
ssh -q $HOST "cd $UPGRADE_DIR; tar -xf ml_update.tar"
echo "Copy complete"
echo "Creating backup files and copying authorized keys..."
ssh -q $HOST "$UPGRADE_DIR/$MK_BACKUPS"
scp -q /.ssh/authorized_keys* $HOST:/.ssh/
echo "Backup files created. Gathering information which will be stored in napsp8125:/resource/nasstaging/configs/"
ssh -q $HOST "$UPGRADE_DIR/$GET_CONFIGS"
echo "Running bosboot on system..."
ssh -q $HOST "bosboot -a"
echo "bosboot complete."
echo ""

#
# Check for Efixes
#
echo "Checking system for Efixes"
_efix_chk

#
# Commit filesets
#
echo "Commiting all filesets on $HOST"
_commit_lpps

#
# Verify enough space exists in /usr
#
echo "Verifying minimum 700MB exists in /usr"
_usr_chk

# 
# Configure as NIM client
#
echo "Configuring host as NIM client"
_nimclient_config

done
