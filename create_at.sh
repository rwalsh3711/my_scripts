#!/bin/sh
#
# Create an "at" job on remote server(s)
#
# Collect host information ##

clear
        echo "What is the name of the server or host file?"

        read ANSWER

        echo "Is \""${ANSWER}"\" a (s)erver or a (f)ile?"
        printf "Enter (s) or (f): "
        read ANS
	echo ""
        if [ ${ANS} == "s" ]; then
                HOSTLIST=${ANSWER}
        elif [ ${ANS} == "f" ]; then
                HOSTLIST=`cat ${ANSWER}`
		if [ $? != 0 ]; then
			echo "FILE NOT FOUND!!"
			exit 1 
		fi
        else
                echo "Invalid answer"
                exit 1
        fi

# Enter in the "at" job details

	echo "What command(s) would you like to schedule?"
	echo ""
	echo "HINT - If you want to schedule multiple commands," 
	echo "append all but the last command with \";\\\""
	echo ""

	read AT_JOB

# Enter in the time to schedule the job

	echo ""
	echo "When would you like to schedule the job?"
	echo "Examples of valid time formats are "now", "9:30 AM Tue", "1400 Wed""
	echo ""

	read TIME


# Schedule the "at" job on the remote systems
	
clear
for HOST in ${HOSTLIST}
do
AT_INSTALLED=`ssh ${HOST} 'which at >/dev/null 2>&1; echo $?'`
if [ "$AT_INSTALLED" != 0 ]; then
	echo "## AT is not installed on ${HOST}! ##"
	echo ""
	exit 1
fi
echo "Adding the following at job to ${HOST}"
echo "${AT_JOB}"
echo "Scheduled for ${TIME}"
echo ""
ssh -oConnectTimeout=10 ${HOST} at ${TIME} <<EOF
${AT_JOB}
EOF
if [ $? = 0 ]; then
	echo "## AT Job Scheduled on ${HOST} ##"
else
	echo "## ERROR Scheduling AT Job!! ##"
	exit 1
fi
echo ""
done
