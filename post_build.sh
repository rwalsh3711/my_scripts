#!/usr/bin/bash
#
# Post build script for FlexPod VMs 
# created with current template (3/31/2017)
#
# Author - Rick Walsh
# v1.1
#
# Changes made with this script:
# Configure server name
# Configure timezone
# Apply correct server to the LogInsight config file
# Build/push the NetBackup configuration file
# Push the sudoer files 
# Run an OpenSCAP securityscan and create the html file on ifop0500
# Run any post-build fixes to be implemented in future templates


if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

## VARIABLES ##

TMPFILE=post_build.tmp

## FUNCTIONS ##

## Gather information ##

_gather_info() {
clear
echo "What is the fully qualified server name?"
read SERVER

echo "Where is the server located (go/lo)?"
read LOC

_verify_info
}

## Verify information ##

_verify_info() {
if [ ${LOC} = LO ] || [ ${LOC} = lo ]; then
	VER_LOC="LOOKOUT (Denver)"
elif [ ${LOC} = GO ] || [ ${LOC} = go ]; then
	VER_LOC="GO (Minneapolis)"
else
	VER_LOC="UNKNOWN"
fi

ping -c 1 ${SERVER} > /dev/null 2>&1
if [ $? != 0 ]; then
	echo "ERROR!:"
	echo "This server name is not reachable.  Please verify the server is powered"
	echo "on, the IP is properly configured and the DNS entry is correct.  Exiting."
	exit
else
	echo "Configure new server ${SERVER} in ${VER_LOC}.  Is this correct?(y/n)"
	read ANS

	if [ ${ANS} = y ] || [ ${ANS} = Y ]; then
		echo "Configuring ${SERVER} in ${VER_LOC}..."
	else 
		clear
		_gather_info
	fi
fi
}


## Set the system hostname ##

_set_hostname() {
echo "Configuring the system hostname..."
ssh ${SERVER} "hostname ${SERVER}"
echo "Done..."
}

## Configure the correct timezone ##

_set_timezone() {
echo "Configuring the correct timezone..."
if [ ${LOC} = GO ] || [ ${LOC} = go ]; then
	ssh ${SERVER} "timedatectl set-timezone US/Central"
elif [ ${LOC} = LO ] || [ ${LOC} = lo ]; then
	ssh ${SERVER} "timedatectl set-timezone US/Mountain"
else
	echo "Location not recognized.  Please set timezone manually."
	continue
fi
echo "Done..."
}

## Set variables for NetBackup configuration file ##

_set_bp_conf() {
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

## Build and transfer the NetBackup configuration file ##

echo "Configuring the NetBackup configuration file..."
if [ ${LOC} = GO ] || [ ${LOC} = go ]; then
	echo "${GOCONF}" > ${TMPFILE}
	scp ${TMPFILE} ${SERVER}:/usr/openv/netbackup/bp.conf
elif [ ${LOC} = LO ] || [ ${LOC} = lo ]; then
	echo "${LOCONF}" > $TMPFILE
	scp ${TMPFILE} ${SERVER}:/usr/openv/netbackup/bp.conf
fi
rm ${TMPFILE}
echo "Done..."
}

## Configure the correct LogInsight server

_set_li() {
echo "Configuring the correct LogInsight server"
if [ ${LOC} = GO ] || [ ${LOC} = go ]; then
	ssh ${SERVER} "sed -i '/hostname=/c\hostname=svc-loginsight-go.xcelenergy.com' /etc/liagent.ini"
elif [ ${LOC} = LO ] || [ ${LOC} = lo ]; then
	ssh ${SERVER} "sed -i '/hostname=/c\hostname=svc-loginsight-lo.xcelenergy.com' /etc/liagent.ini"
else
	echo "Location not recognized.  Please configure the liagent.ini file manually."
	continue
fi
echo "Done..."
}

## Push out the SUDOERS files ##
_push_sudoers() {
echo "Pushing out current sudoers files..."
scp /etc/sudoers ${SERVER}:/etc/sudoers
scp /etc/sudoers.d/* ${SERVER}:/etc/sudoers.d/
echo "Done..."
}

## Run the post-build SCAP security scan ##

_run_scap() {
echo "Running the OpenSCAP scan on ${SERVER}..."
echo "OpenSCAP scan on ${SERVER} in progress.  Please check your email for results"
ssh ifop0500 "/usr/share/xml/scap/ssg/custom/remote_scap_scan.sh ${SERVER}"
}

## MAIN SCRIPT ##
_gather_info

OUTFILE=/usr/local/admin/lists/post_build_outputs/post_build.${SERVER}.`date +%m%d%Y`.out

exec > >(tee -i ${OUTFILE})
exec 2>&1

_set_hostname
_set_timezone
_set_bp_conf
_set_li
_push_sudoers
_run_scap

### Post Build Steps to clean template issues  		###
### These are issues to be fixed in future releases 	###

echo "Running post build cleanups..."
	# Modify "maxclassrepeat" setting
	echo "Fixing maxclassrepeat setting in pwquality.conf"
	ssh ${SERVER} "sed -i '/maxclassrepeat = 2/c\# maxclassrepeat = 0' /etc/security/pwquality.conf"

	# Install ksh
	echo "Installing ksh"
	ssh ${SERVER} "yum clean all;sleep 5;yum repolist;sleep 5;yum -y install ksh"

	# Install ILMT Client
	echo "Installing ILMT client"
	/usr/local/admin/bin/inst_ilmt.sh -s ${SERVER}

	# Copy over the latest MOTD
	echo "Configuring current MOTD"
	scp /etc/motd ${SERVER}:/etc/motd 

echo "Completed post build cleanup..."

echo ""
echo "Post Build script for ${SERVER} complete!"
echo ""
echo "The output of this script has been saved to:"
echo "${OUTFILE}"
echo ""
echo "Verify the OpenSCAP results and perform post reboot of server before hand-off."
