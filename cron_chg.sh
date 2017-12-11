#!/bin/sh

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

for HOST in $HOSTLIST
do

ssh ${HOST} "sed -i '/0 0 \* \* \* \/usr\/local\/bin\/startnmon > \/dev\/null 2>&1/c\0 6 \* \* \* \/usr\/local\/bin\/startnmon > \/dev\/null 2>&1' /var/spool/cron/root"
ssh ${HOST} "sed -i '/0 0 \* \* \* \/usr\/local\/admin\/bin\/startnmon > \/dev\/null 2>&1/c\0 6 \* \* \* \/usr\/local\/admin\/bin\/startnmon > \/dev\/null 2>&1' /var/spool/cron/root"

echo ${HOST}: 
ssh ${HOST} "cat /var/spool/cron/root" |grep startnmon
echo ""

done
