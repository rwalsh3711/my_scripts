#!/bin/bash
#
# Script to restore Postgresql backup to AWX Postgresql instance
#
# Revision: 1.0
# Date: 11/20/2019
# Author: Rick Walsh
# Email: richard_walsh@optum.com

OC_INSTANCE="https://ocp-ctc-core-nonprod.optum.com"
OC_USER="wdtdepl1"
OC_PASS="uC4M9fTd"
OC_PROJECT="hsid-ops"
PG_DBASE="awx"
RESTORE_LOG="/awx_backups/restore-$(date +%m-%d-%Y-%H:%M).log"

/usr/local/bin/oc login ${OC_INSTANCE} -u ${OC_USER} -p ${OC_PASS} --insecure-skip-tls-verify=true >/dev/null
/usr/local/bin/oc project ${OC_PROJECT} >/dev/null

PG_INSTANCE=`/usr/local/bin/oc get pods |grep postgresql |awk {'print $1'}`

options=( $(find /awx_backups -maxdepth 1 -name '*.sql' -print0|sort -z |xargs -0))

clear
cat << EOF
## IMPORTANT NOTE ##
This utility restores a Postgresql backup file to a running AWX Postgres instance. Please
confirm that AWX Postgres instance "${PG_INSTANCE}" is up and operating properly in the
"${OC_INSTANCE}" environment under the "${OC_PROJECT}" project and that 
an empty database named "${PG_DBASE}" is created in it before proceeding

EOF

PS3="Please select a backup file to restore: "
select opt in "${options[@]}" "Quit"; do
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        read -p  "You picked option $REPLY which is file $opt.  Is this correct? y|n: " -n 1 -r CONFIRM
        if [[ $CONFIRM =~ ^[Yy]$ ]]; then
          echo ""
          echo "Restoring backup file \"$opt\" to AWX Postgres instance \"$PG_INSTANCE\" running in \"$OC_INSTANCE\".  Please wait..."
          /usr/local/bin/oc rsh ${PG_INSTANCE} bash -c "psql ${PG_DBASE}" < $opt 1> ${RESTORE_LOG} 2>&1
          if [ $? = 0 ]; then
            echo "Restore complete! Restore log located at $RESTORE_LOG"
            exit
          else
            echo "Restore failed! Review restore log located at $RESTORE_LOG"
          fi
        else
          echo ""
          continue
        fi
        break

    else
        echo "Invalid option. Try another one."
    fi
done   
