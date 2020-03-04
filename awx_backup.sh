#!/bin/bash

OC_INSTANCE="https://ocp-ctc-core-nonprod.optum.com"
OC_USER="wdtdepl1"
OC_PASS="uC4M9fTd"
OC_PROJECT="hsid-ops"
PG_DBASE="awx"
LOG_FILE="awx_backup.log"
BU_FILE="/awx_backups/${PG_DBASE}_bu_$(date +%m-%d-%Y_%H_%M).sql"

exec 3>&1 4>&2
exec 1>${LOG_FILE} 2>&1

# Clean up anything older than 6 days
find /awx_backups/ -mtime +5 -name '*.sql' -exec rm -f {} \;

# Connect to AWX instance and create json backup file
/usr/local/bin/oc login ${OC_INSTANCE} -u ${OC_USER} -p ${OC_PASS} --insecure-skip-tls-verify=true
/usr/local/bin/oc project ${OC_PROJECT}

PG_INSTANCE=`/usr/local/bin/oc get pods |grep postgresql |awk {'print $1'}`

/usr/local/bin/oc rsh $PG_INSTANCE bash -c "pg_dump ${PG_DBASE}" > ${BU_FILE}; BU_RC=$?

echo ""

if [[ $BU_RC = 0 ]]; then 
  echo "Backup file created successfully!"
  echo ""
  echo "New backup file is ${BU_FILE}"
  MSG="Backup of ${PG_DBASE} completed successfully"
else
  echo "Backup failed!"
  MSG="Backup of ${PG_DBASE} FAILED!"
fi

exec 2>&4 1>&3

cat ${LOG_FILE} |mail -s "${MSG}" richard_walsh@optum.com ricks-private-flow@uhg.flowdock.com

rm -f ${LOG_FILE}
