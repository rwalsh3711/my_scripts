#!/usr/local/bin/bash

FILE="/etc/systemd/system/axway*"

for host in `cat $1`
do
	ssh -q -o BatchMode=yes -o ConnectTimeout=5 $host "ls $FILE >/dev/null 2>&1"

		if [ $? != 0 ]; then
			echo "Not on $host"
			continue
		else
			echo "File exists on $host!"
			exit
		fi
done

