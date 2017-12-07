#!/bin/sh
if [ $# != 1 ] ; then
	echo "USAGE: ${0} <host_list_file>"
	exit 0
fi

echo "Enter your user name: "
	read USER
echo "Enter your password: "
	read PASS
HOST_LIST=`cat $1`

for HOST in $HOST_LIST
	do
	# Check if the server is reachable first
		ping -c 1 $HOST &>/dev/null
		if [ $? != 0 ] ; then
			continue
		fi

{
/usr/bin/expect -- << EOF
spawn ssh -q -l $USER -oStrictHostKeyChecking=no -oConnectTimeout=10 $HOST
expect "*?assword:"
send "$PASS\r";
expect \n
send "mkdir .ssh\r";
expect \n
send "chmod 755 .ssh\r";
expect \n
send "exit\r";
expect \n
spawn scp authorized_keys $USER@$HOST:~/.ssh/
expect "*?assword:"
send "$PASS\r";
sleep 5;
expect \n
EOF
}
	echo "Completed $HOST"
done
