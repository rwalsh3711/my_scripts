#!/bin/ksh
# Script to Check SIEBEL is installed 
for i in `cat $1`
do
echo "$i ========================================"
	CNT=`ssh -q $i grep -i role /etc/group|wc -l`
	if (( $CNT > 0 )); then
        	echo "SIEBEL app is installed"
	else
        	echo "SIEBEL app is NOT installed"
	fi

# Check to see if ldap binaries already exist by
# anyone other than "root"

ldapsearch_status=`ssh -q $i ls -l /usr/bin/ldapsearch 2>/dev/null |awk {'print $3'}`

if [[ "$ldapsearch_status" = 'root' || "$ldapsearch_status" = '' ]]; then
        echo "$i ok to convert to LDAP"
else
        echo "$i has LDAP binaries owned by $ldapsearch_status.  Not OK to convert."
fi

# Checking for local accounts

echo "accounts other than bin and lp may need to be removed"
ssh -q $i more /etc/passwd |egrep -v -i 'root|daemon|sys|adm|uucp|guest|nobody|lpd|ldap|sbnet|snapp|ipsec|tivoli|pdwebpi|opc_op|\+'
done

