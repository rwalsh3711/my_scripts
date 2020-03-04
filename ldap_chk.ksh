#!/bin/ksh

ldapsearch_status=`ssh -q $1 ls -l /usr/bin/ldapsearch 2>/dev/null |awk {'print $3'}`

if [[ "$ldapsearch_status" = 'root' || "$ldapsearch_status" = '' ]]; then
	echo "$1 ok to convert to LDAP"
else
	echo "$1 has LDAP binaries owned by $ldapsearch_status.  Not OK to convert."
fi
