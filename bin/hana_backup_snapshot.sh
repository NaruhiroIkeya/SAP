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
CLOUD=AZURE
#Parameter name for SSM of data and log volumes
SSMPARAMDATAVOL=imdbmaster-hdb-datavolumes
SSMPARAMLOGVOL=imdbmaster-hdb-logvolumes
#Key-Name of hdbuserstore
HDBUSERSTORE=SYSTEM
# HANA Snapshot backup ID
SnapshotID=$1

#* SET more variables automatically
if [ "AWS" = $CLOUD ]; then
  TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
  instanceid=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`
  az=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone`
  region=`echo $az | sed 's/[a-z]$//'`
  sidadm=$(ps -C sapstart -o user |awk 'NR ==2' | awk '{print $1}')
elif [ "AZURE" = $CLOUD ]; then
  instanceid=`curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.name'`
  resourcegroup=`curl -s -H Metadata:true --noProxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.resourceGroupName'`
  region=`curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.location'`
  subscriptionId=`curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.subscriptionId'`
  target_disk_name_list=`curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.compute.storageProfile.dataDisks[].name'`       else
  echo "CLOUD Environment: 'AWS' or 'AZURE' or 'GCP??' "
  exit 1
fi

#Log output to AWS console log
logfile="/var/log/user-data.log"

# Get status of first Tenant DB. status online=yes
# status=$(sudo -u $sidadm -i hdbsql -U $HDBUSERSTORE "SELECT ACTIVE_STATUS from M_DATABASES;" | awk 'FNR==3' |sed 's/\"//g')

#********************** Function Declarations ************************************************************************

# Function: Log an event.
log() {
  echo "[$(date +"%Y-%m-%d"+"%T")]: $*"
}

# Function: Prerequisite check - check if HANA DB and tenant is online.
status="YES"
prerequisite_check() {
if [ $status == "YES" ]; then
  log "INFO: HANA and tenant DB is online and ready for backup"
  return 0
else
  log "ERROR: HANA or tenant is offline - Snapshot procedure failed"
  return 1
fi
}

# Function: Create snapshot.
snapshot_instance() {
  snapshot_suffix="-HANA-Snapshot-$(date +%Y%m%d%H%M%S)"
  snapshot_description="$(hostname)-$instanceid-HANA-Snapshot-$(date +%Y-%m-%d-%H:%M:%S)"

  if [ "AWS" = $CLOUD ]; then
    recent_snapshot_list_new=($(aws ec2 create-snapshots --region $region --instance-specification InstanceId=$instanceid,ExcludeBootVolume=true --description $snapshot_description --tag-specifications "ResourceType=snapshot,Tags=[{Key=Createdby,Value=AWS-HANA-Snapshot_of_${HOSTNAME}}]" | jq -r ".Snapshots[] | .SnapshotId"))
  elif [ "AZURE" = $CLOUD ]; then
    array_target_disk_name=($target_disk_name_list)
    tmpfile=$(mktemp)
    for ((i=0; i<${#array_target_disk_name[@]}; ++i)); do az snapshot create --name "${array_target_disk_name[$i]}$snapshot_suffix" --resource-group $resourcegroup --source ${array_target_disk_name[$i]} --incremental="true" --tags "Createdby=AWS-HANA-Snapshot_of_${HOSTNAME}"; done | jq -r ".name" > $tmpfile
    result_snapshot_list=`cat $tmpfile`
    rm -f $tmpfile
    recent_snapshot_list_new=($result_snapshot_list)
  else
    return 1
  fi
  for((i=0; i<${#recent_snapshot_list_new[@]}; ++i)); do log "INFO: EBS Snapshot ID-$i: ${recent_snapshot_list_new[$i]}"; done
}

tag_mountinfo() {
  if [ "AWS" = $CLOUD ]; then
    OIFS=$IFS;
    IFS=",";
    volume_list_data=$(aws ssm get-parameters --region $region --names $SSMPARAMDATAVOL | jq -r ".Parameters[] | .Value")
    volume_list_log=$(aws ssm get-parameters --region $region --names $SSMPARAMLOGVOL | jq -r ".Parameters[] | .Value")
    volume_list="$volume_list_data$volume_list_log"
    declare -a volume_id_sorted
    declare -a device_name_sorted
    volume_id=($volume_list);
    for ((i=0; i<${#recent_snapshot_list_new[@]}; ++i));
    do
      #get device name of volume
      volume_id_sorted+=($(aws ec2 describe-snapshots --region $region --snapshot-ids ${recent_snapshot_list_new[$i]} | jq -r ".Snapshots[] | .VolumeId"))
      device_name_sorted+=($(aws ec2 describe-volumes --region $region --output=text --volume-ids ${volume_id_sorted[$i]} --query 'Volumes[0].{Devices:Attachments[0].Device}'))

      #add tag to snapshot
      aws ec2 create-tags --region $region --resource ${recent_snapshot_list_new[$i]} --tags Key=device_name,Value=${device_name_sorted[$i]}
      
    done
    IFS=$OIFS;
  elif [ "AZURE" = $CLOUD ]; then

    return 0

  else
    return 1
  fi
}

delete_invalid_snap() {
  SNAP_VALIDATION=$(sudo -u $sidadm -i hdbsql -U $HDBUSERSTORE "select STATE_NAME from m_backup_catalog where ENTRY_TYPE_NAME = 'data snapshot' order by SYS_START_TIME desc limit 1" | awk 'FNR==2' |sed 's/\"//g')
  if [ $SNAP_VALIDATION == "successful" ]; then
    log "INFO: Snapshot successful, keep AWS snapshot"
  else
    if [ "AWS" = $CLOUD ]; then
      for((i=0; i<${#recent_snapshot_list_new[@]}; ++i));  do
        aws ec2 delete-snapshot --region $region --snapshot_id ${recent_snapshot_list_new[$i]}
        log "ERROR: Backup was not marked as successful in HANA backup catalog - delete EBS snapshot: $recent_snapshot_id"
      done
    elif [ "AZURE" = $CLOUD ]; then
      return 0
    else
      return 1
    fi
  fi
}

#**********************************************************************************************************************************
### Call functions in required order
log "INFO: Start AWS snapshot backup"

#log_setup
log "INFO: Check log file $logfile for more information"
log "INFO: HANA prepared for Snapshot -- HANA Snapshot-ID: " $SnapshotID

# 1) Check prerequisites
if prerequisite_check; then :
else log "ERROR: Database or Tenant DB is not online, no connection possible"
   exit 1
fi

# 2) Execute EBS Snapshot
if snapshot_instance; then :
else log "ERROR: EBS Snapshot was not successful"
   delete_invalid_snap
   exit 1
fi

# 3) Tag snapshot with device name
if tag_mountinfo; then :
else log "ERROR: Could not create tags for EBS snapshots"
   exit 1
fi

# 6) Validate snap
if delete_invalid_snap; then :
else log "ERROR: EBS snapshots could not be deleted - please remove invalid snapshots manually"
   exit 1
fi

log "INFO: End of AWS snapshot backup"

exit 0
#################################################################End of script ########################################
