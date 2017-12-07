#!/bin/sh
#
# Script to add the SecPolicy line to 
# users .profile
#
if [ $# != 2 ] ; then
        echo "USAGE: ${0} <user_name> <host_list_file>"
        exit 0
fi

USERID=$1
HOSTLIST=`cat $2`

for HOST in ${HOSTLIST}
        do
	ssh ${HOST} "cat /home/${USERID}/.profile" |grep SecPolicy >/dev/null
		if [ $? = 0 ] ; then
		printf "${HOST} is already configured\n"
                continue
        	fi
        echo "Adding policy to ${HOST}"
        ssh ${HOST} "echo '\nswrole SecPolicy' >>/home/${USERID}/.profile"
        echo "Last line of ${USERID} .profile is: " `ssh ${HOST} "tail -n1 /home/${USERID}/.profile"`
        done
