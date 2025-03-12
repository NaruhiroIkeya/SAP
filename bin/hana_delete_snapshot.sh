#!/bin/bash
set -ue
#set -x

#====================================================================================
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#====================================================================================
#* SET variables*
# Cloud Environment
CLOUD=AWS
#Key-Name of hdbuserstore
HDBUSERSTORE=ZSYSTEM_BACKUP
# HANA Snapshot backup ID
SnapshotID=$1

#* SET more variables automatically
if [ "AWS" = $CLOUD ]; then
  TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
  instanceid=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`
  az=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone`
  region=`echo $az | sed 's/[a-z]$//'`
elif [ "AZURE" = $CLOUD ]; then
  instanceid=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.name')
  resourcegroup=$(curl -s -H Metadata:true --noProxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.resourceGroupName')
  region=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.location')
  subscriptionId=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.subscriptionId')
  target_disk_name_list=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.storageProfile.dataDisks[].name')
else
  echo "CLOUD Environment: 'AWS' or 'AZURE' or 'GCP??' "
  exit 1
fi

#Log output to AWS console log
logfile="/var/log/user-data.log"

#********************** Function Declarations ************************************************************************

# Function: Log an event.
log() {
  echo "[$(date +"%Y-%m-%d"+"%T")]: $*"
}

delete_snapshot() {
  if [ "AWS" = $CLOUD ]; then
    snapshot_ids+=($(aws ec2 describe-snapshots --region $region --filters Name=tag:hana_snapshot_id,Values=${SnapshotID} | jq -r ".Snapshots[] | .SnapshotId"))
    for((i=0; i<${#snapshot_ids[@]}; ++i));  do
      aws ec2 delete-snapshot --region $region --snapshot-id ${snapshot_ids[$i]}
      log "ERROR: Backup was not marked as successful in HANA backup catalog - delete EBS snapshot: ${snapshot_ids[$i]}"
    done
  elif [ "AZURE" = $CLOUD ]; then
    return 0
  else
    return 1
  fi
}

#**********************************************************************************************************************************
### Call functions in required order
log "INFO: Start AWS remove snapshot backup"

#log_setup
log "INFO: Check log file $logfile for more information"
log "INFO: HANA removable for Snapshot -- HANA Snapshot-ID: " $SnapshotID

# 1) Delete snap
if delete_snapshot; then :
else log "ERROR: EBS snapshots could not be deleted - please remove invalid snapshots manually"
   exit 1
fi

log "INFO: End of AWS snapshot deleted"

exit 0
#################################################################End of script ########################################
