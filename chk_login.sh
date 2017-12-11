#!/bin/sh
#
# Script to check password on multiple systems
#
if [ $# != 1 ] ; then
	echo "USAGE: ${0} <host_list_file> | MUST BE RUN AS ROOT" 
		exit 0 
	fi 

echo "Enter your user name: " 
	read USER 
echo "Enter location of authorized_keys file or <enter> for none: " 
	read KEYS

HOST_LIST=`cat $1`

for HOST in ${HOST_LIST}
	do
	# Check if the server is reachable first
		ping -c 1 ${HOST} >/dev/null
		if [ $? != 0 ] ; then
			echo "${HOST}: Unreachable"
			continue
		fi
	
	# Check if root user can log into host
	STATUS=`ssh -o BatchMode=yes -o ConnectTimeout=5 ${HOST} "echo ok" 2>/dev/null`
		if [ "${STATUS}" != ok ] ; then
		printf "${HOST}: root login not configured\n"
		continue
		fi

	# Check if user account exists on host
	printf "Checking login on ${HOST}: "
	ssh -q -oConnectTimeout=5 ${HOST} "id ${USER}" >/dev/null
	if [ $? != 0 ] ; then
		echo "User does not exist"
		continue
	fi

	# Check if users ssh keys exist on host and install
	# if they don't and an authorized_key file was provided
	ssh -q -oConnectTimeout=5 ${HOST} "test -e /home/${USER}/.ssh/authorized_keys && exit 0 || exit 1"
		if [ $? = 1 ] ; then
			echo "authorized_keys not installed."
			if [ -z "${KEYS}" ]; then
				continue
			fi
			printf "Installing authorized_keys..."
				ssh -q ${HOST} "test -d /home/${USER}/.ssh && exit 0 || exit 1"
					if [ $? = 1 ] ; then
					ssh -q ${HOST} "mkdir /home/${USER}/.ssh/ >/dev/null; chmod 755 /home/${USER}/.ssh; chown ${USER} /home/${USER}/.ssh"
					fi
			scp ${KEYS} ${HOST}:/home/${USER}/.ssh/ >/dev/null
			ssh -q ${HOST} "chown ${USER} /home/${USER}/.ssh/authorized_keys"
			printf "Done\n"
			continue
		fi
	echo "Login exists with SSH key installed"
done
