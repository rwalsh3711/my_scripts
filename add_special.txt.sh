#!/bin/sh
#
# Script to display "/etc/special.txt"
# from login profile if file exists
#
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

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

for HOST in ${HOSTLIST}
do

	# Test if the server is reachable
        echo "\t\t- PING RESULTS -"
        ping -c 1 ${HOST} >/dev/null 2>&1
                if [ $? = 0 ] ; then
                printf "${HOST} is Reachable\n"
                else
                printf "${HOST} is Not Reachable\n"
                continue
                fi
        echo ""

        # Check if root user can log into host
        echo "\t\t- SSH RESULTS -"
        ssh -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "echo ok" >/dev/null 2>&1
                if [ $? != 0 ] ; then
                echo "SSH Keys Not Installed"
                continue
                else
                echo "SSH Keys Installed Correctly"
                echo ""
                fi

        # Collect the OS Level and push the commands to the proper file
	COMMAND='printf "\n
			## The following entry will cat /etc/special.txt if it exists ##\n
			if [ -f /etc/special.txt ] ; then\n
			\tcat "/etc/special.txt"\n
			fi\n"'

        OS=`ssh ${HOST} "uname -s"`

	if [ $OS = AIX ]; then
                ssh ${HOST} ""${COMMAND}" >> ~/.profile"
                echo "Entry created on ${HOST}"
        elif [ $OS = Linux ]; then
                ssh ${HOST} ""${COMMAND}" >> ~/.bash_profile"
                echo "Entry created on ${HOST}"
        else
                echo "${HOST} OS not recognized. Skipping."
                continue
        fi
done
