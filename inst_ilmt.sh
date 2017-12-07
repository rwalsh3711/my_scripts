#!/usr/bin/bash
#
# Script to install the ILMT 9.2 client on 
# either RHEL5 and above or AIX6.1TL4 or above
#
# Author: Rick Walsh
# Date: 5/17/2017

## Notification to run as root ##

        if [ "$(id -u)" != "0" ]; then
           echo "This script must be run as root" 1>&2
           exit 1
        fi


## Gather host information ##

fflag=
sflag=
while getopts f:s:h name; do
        case $name in
        f)      fflag=1
                fval=${OPTARG};;
        s)      sflag=1 
                sval=${OPTARG};;
	h)	echo "Usage: $0 [-h] [-s <server name>] [-f <file name>]"; exit ;;
        esac
done
if [ ! -z "$fflag" ]; then
        HOSTLIST=`cat ${fval}`
elif [ ! -z "$sflag" ]; then
        HOSTLIST=${sval}
else
        echo "What is the name of the server or host file?"

        read ANSWER

        echo "Is \""${ANSWER}"\" a (s)erver or a (f)ile?"
        printf "Enter (s) or (f): "
        read ANS
        if [ ${ANS} == "s" ]; then
                HOSTLIST=${ANSWER}
        elif [ ${ANS} == "f" ]; then
                HOSTLIST=`cat ${ANSWER}`
        else
                echo "Invalid answer"
                exit 0
        fi
fi

## Begin loop on HOSTLIST ##

for HOST in ${HOSTLIST}
do
	OUTFILE=/usr/local/admin/lists/ILMT_INSTALL_RESULTS/${HOST}.ilmt_install.`date +%m%d%Y`.out
	exec > >(tee -i ${OUTFILE})
	echo ""
	echo "## ${HOST} ##" 


## Verify access ##

        printf "\tTesting if server is reachable..."
        ping -c 1 ${HOST} >/dev/null 2>&1
                if [ $? = 0 ] ; then
                printf "${HOST} is Reachable\n"
                else
                printf "${HOST} is Not Reachable.  Skipping...\n"
                continue
                fi

        # Check if root user can log into host
        printf "\tTesting if server has SSH keys..."
        ARCH=`ssh -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "uname -p" 2>/dev/null`
                if [ -z "${ARCH}" ] ; then
			printf "SSH Keys Not Installed.  Skipping...\n"
			continue
                else
			printf "SSH Keys Installed Correctly\n"
			OS=`ssh ${HOST} "uname -s"`
                fi

## Verify OS version ##

	printf "\tTesting if the OS version is supported..."
        if [ "${OS}" = "AIX" ]; then
                VERS=`ssh ${HOST} "oslevel -r"`
                REL=`echo ${VERS} |awk -F- {'print $1'}`
                TL=`echo ${VERS} |awk -F- {'print $2'}`
                if [ ${REL} -ge 6200 ]; then
                        printf "AIX version ${VERS} OK to install!\n"
                elif [ ${REL} -eq 6100 ] && [ ${TL} -ge 4 ]; then
                        printf "AIX version ${VERS} OK to install!\n"
                else
                        printf "AIX version ${VERS} not supported!\n"
                        continue 
                fi
	elif [ "${OS}" = "Linux" ]; then
		RHEL_CHK=`ssh ${HOST} "grep -o '[^ ]*\.[^ ]*' /etc/redhat-release 2>/dev/null" |awk -F. {'print $1'}`
		SLES_CHK=`ssh ${HOST} "cat /etc/S*SE-release 2>/dev/null" |grep -i version |cut -d" " -f3`
		if [ -z "${RHEL_CHK}" ] && [ -z "${SLES_CHK}" ]; then
			printf "Linux version not supported.  Skipping...\n"
			continue
		fi
		if [ -n "${SLES_CHK}" ]; then
			if [ ${SLES_CHK} -eq 11 ] && [ "${ARCH}" = "i686" ]; then
				LINUX_INSTALLER=BESAgent-9.5.4.38-sle11.i686.rpm
				printf "Linux SUSE version ${SLES_CHK} OK to install!\n"
			elif [ ${SLES_CHK} -eq 11 ] && [ "${ARCH}" != "i686" ]; then
				LINUX_INSTALLER=BESAgent-9.5.4.38-sle11.x86_64.rpm
				printf "Linux SUSE version ${SLES_CHK} OK to install!\n"
			elif [ ${SLES_CHK} -eq 10 ] && [ "${ARCH}" = "i686" ]; then
				LINUX_INSTALLER=BESAgent-9.5.4.38-sle10.i686.rpm
				printf "Linux SUSE version ${SLES_CHK} OK to install!\n"
			elif [ ${SLES_CHK} -eq 10 ] && [ "${ARCH}" != "i686" ]; then
				LINUX_INSTALLER=BESAgent-9.5.4.38-sle10.x86_64.rpm
				printf "Linux SUSE version ${SLES_CHK} OK to install!\n"
			else 
				printf "Linux SUSE version unknown!  Skipping...\n"
				continue
			fi
		elif [ -n "${RHEL_CHK}" ]; then
			if [ ${RHEL_CHK} -ge 5 ]; then
				printf "Linux RedHat version ${RHEL_CHK} OK to install!\n"
				if [ "${ARCH}" = "i686" ]; then
					LINUX_INSTALLER=BESAgent-9.5.4.38-rhe5.i686.rpm
				else
					LINUX_INSTALLER=BESAgent-9.5.4.38-rhe5.x86_64.rpm
				fi	
			fi
		fi
	fi

## Uninstall old version if it exists ##

	printf "\tChecking if older version is installed..."
	if [ "${OS}" = "AIX" ]; then
		INST_STATUS=`ssh ${HOST} "lslpp -l ILMT-TAD4D-agent 2>/dev/null" |wc -l`
		if [ ${INST_STATUS} -ge 1 ]; then 
			printf "previous version found!  Removing..."
			EXIT_STAT=`ssh ${HOST} "installp -u ILMT-TAD4D-agent >/dev/null 2>&1; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "\nUninstall failed for ${HOST}.  Skipping...\n"
				continue
			else
				printf "Done!\n"
			fi	
		else
			printf "older version not installed.  Continuing...\n"
		fi
	elif [ "${OS}" = "Linux" ]; then
		INST_STATUS=`ssh ${HOST} "rpm -qa" |egrep "BESAgent-8|ILMT-TAD4D-agent" |wc -l`
		if [ ${INST_STATUS} -ge 1 ]; then 
			printf "previous version found!  Removing..."
			EXIT_STAT=`ssh ${HOST} "rpm -e ILMT-TAD4D-agent;rpm -e BESAgent >/dev/null 2>&1; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "\nUninstall failed for ${HOST}.  Skipping...\n"
				continue
			else
				printf "Done!\n"
			fi	
		else
			printf "older version not installed.  Continuing...\n"
		fi
	fi

## Install new agent ##
	printf "\tChecking if ILMT 9.2 is already installed..."
	if [ "${OS}" = "AIX" ]; then
		INST_VAR=`ssh ${HOST} "lslpp -l BESClient 2>/dev/null" |wc -l`
		if [ ${INST_VAR} -ge 1 ]; then
			printf "ILMT client already installed.  Skipping...\n"
			continue
		else
			printf "ILMT client not installed.\n"
		fi
		printf "\tRunning ILMT 9.2 installer on AIX host ${HOST}\n"
		printf "\tMounting NFS installer share..."
		EXIT_STAT=`ssh ${HOST} "mount xclha1:/opt/local/patches/ibmtools /mnt; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "NFS mount failed for ${HOST}.  Skipping...\n"
				continue
			else
				printf "Done!\n"
			fi	
		printf "\tCreating install directory and copying files..."
		EXIT_STAT=`ssh ${HOST} "mkdir -p /etc/opt/BESClient; cp /mnt/ILMT9_2/aix/actionsite.afxm /etc/opt/BESClient/; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "Directory creation or file copy failed on ${HOST}.  Skipping...\t"
				ssh ${HOST} "umount /mnt"
				continue
			else
				printf "\tDone!\n"
			fi	
		printf "\tInstalling ILMT 9.2 Client..."
		EXIT_STAT=`ssh ${HOST} "installp -agqYXd /mnt/ILMT9_2/aix/BESAgent-9.5.4.38.ppc64_aix61.pkg BESClient >/dev/null 2>&1; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "\tInstallation failed on ${HOST}.  Skipping...\n"
				ssh ${HOST} "umount /mnt"
				continue
			else
				printf "Done!\n"
			fi	
		printf "\tStarting the ILMT agent..."
		EXIT_STAT=`ssh ${HOST} "/etc/rc.d/rc2.d/SBESClientd start >/dev/null 2>&1; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "ILMT agent startup failed on ${HOST}.  Please investigate...\n"
				ssh ${HOST} "umount /mnt"
				continue
			else
				printf "Done!\n"
			fi	
		printf "\tCleaning up...\n"
		ssh ${HOST} "umount /mnt"
		printf "\tInstallation of ILMT agent complete on ${HOST}!\n"

	elif [ "${OS}" = "Linux" ]; then
		INST_VAR=`ssh ${HOST} "rpm -qa BESAgent 2>/dev/null" |wc -l`
		if [ ${INST_VAR} -ge 1 ]; then
			printf "ILMT client already installed.  Skipping...\n"
			continue
		else
			printf "ILMT client not installed.\n"
		fi
		printf "\tRunning ILMT 9.2 installer on Linux host ${HOST}\n"
		printf "\tCreating install directory and copying files..."
		ssh ${HOST} "mkdir -p /etc/opt/BESClient"
		scp /opt/local/patches/ibmtools/ILMT9_2/linux/actionsite.afxm ${HOST}:/etc/opt/BESClient/
			if [ $? != 0 ]; then
				printf "File copy failed on ${HOST}.  Skipping...\t"
				continue
			else
				printf "Done!\n"
			fi	
		printf "\tInstalling ILMT 9.2 Client..."
		EXIT_STAT=`ssh ${HOST} "rpm -ivh http://170.152.5.121/ILMT9_2/${LINUX_INSTALLER} >/dev/null 2>&1; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "Installation failed on ${HOST}.  Skipping...\n"
				continue
			else
				printf "Done!\n"
			fi	
		printf "\tStarting the ILMT agent..."
		EXIT_STAT=`ssh ${HOST} "/etc/init.d/besclient start >/dev/null 2>&1; echo $?"`
			if [ ${EXIT_STAT} != 0 ]; then
				printf "ILMT agent startup failed on ${HOST}.  Please investigate...\n"
				continue
			else
				printf "Done!\n"
			fi	
		printf "\tInstallation of ILMT agent complete on ${HOST}!\n"
	else
		printf "\tThis is not a supported OS.  Skipping..."
	fi

	printf "\tInstall results located at ${OUTFILE}\n\n"
done
