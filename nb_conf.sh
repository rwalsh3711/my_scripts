#!/bin/sh

TMPFILE=nb_conf.tmp
echo "What is the fully qualified server name?"
read SERVER

echo "Where is the server located (go/lo)?"
read LOC

GOCONF=$(cat << EOF
SERVER = nbtabk01
SERVER = NBUCPGO01
SERVER = NBUCPGO02
SERVER = NBUCPGO05
SERVER = NOMCPLC01
SERVER = nomcplc01.corp.xcelenergy.com
SERVER = NBUCPGO01.corp.xcelenergy.com
SERVER = NBUCPGO05.corp.xcelenergy.com
SERVER = nbgobk10
SERVER = nbgobk11
CLIENT_NAME = $SERVER
CONNECT_OPTIONS = localhost 1 0 2
EOF
)

LOCONF=$(cat << EOF
SERVER = nblcbk01
SERVER = nblcbk02.xcelenergy.com
SERVER = nblcbk04.xcelenergy.com
SERVER = NBUCPLC01.corp.xcelenergy.com
SERVER = NBUCPLC05.corp.xcelenergy.com
SERVER = nblcbk10.xcelenergy.com
SERVER = nblcbk11.xcelenergy.com
SERVER = nbsfbk01
SERVER = nbsfbk02.xcelenergy.com
SERVER = NOMCPLC01
SERVER = nomcplc01.corp.xcelenergy.com
CLIENT_NAME = $SERVER
CONNECT_OPTIONS = localhost 1 0 2
EOF
)

if [ $LOC = GO ] || [ $LOC = go ]; then
	echo "$GOCONF" > $TMPFILE
	scp $TMPFILE $SERVER:/usr/openv/netbackup/bp.conf
elif [ $LOC = LO ] || [ $LOC = lo ]; then
	echo "$LOCONF" > $TMPFILE
	scp $TMPFILE $SERVER:/usr/openv/netbackup/bp.conf
fi
rm $TMPFILE
