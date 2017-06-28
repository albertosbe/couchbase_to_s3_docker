#!/bin/bash
#
# Backup script for  Couchbase 4.5 and up
#

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/opt/couchbase/bin

set -e

: ${AWS_PROFILE:=testing}
: ${AWS_REGION:=us-east-1}
: ${S3_BUCKET:=example-backup}

: ${SERVER_IP:="127.0.0.1"}
: ${SERVER_USER:="Administrator"}
: ${SERVER_PASSWORD:="secret"}

: ${BACKUP_PATH:=/data}
: ${BACKUP_REPO:=example-repo}
: ${RECOVERY_PATH:=/data_recovery}

# ========================================================================================
# END of configuration
# ========================================================================================

sync_s3_up () {
  bpath="$(echo $BACKUP_PATH | sed 's/^\///')"
  aws --region=${AWS_REGION} \
    s3 sync \
    --storage-class STANDARD_IA \
    /${bpath} \
    s3://${S3_BUCKET}/${bpath}
}

sync_s3_down () {
  bpath="$(echo $BACKUP_PATH | sed 's/^\///')"
  aws --region=${AWS_REGION} \
    s3 sync \
    s3://${S3_BUCKET}/${bpath} \
    ${RECOVERY_PATH}
}

run_backup () {
  mkdir -p ${BACKUP_PATH}
  cbbackup http://${SERVER_IP} ${BACKUP_PATH} \
              -m full \
              -u ${SERVER_USER} \
              -p ${SERVER_PASSWORD}
}

compress_backup () {
  OWD="$(pwd)"
  cd "${BACKUP_PATH}"
  for dir in */; do
    tar czf "$(basename "$dir").tar.gz" "$dir" && rm -rf "$dir"
  done
  cd "$OWD"
}

do_backup () {
  run_backup
  compress_backup
  sync_s3_up
}

do_restore () {
  sync_s3_down
  restore_backup
}

main () {
  case $1 in

    backup)
      echo "Starting Couchbase Server Backup "
      do_backup
      ;;

    restore)
      echo "Starting Couchbase Server restore "
      do_restore
      ;;

    -h|--help|-\?)
      echo "usage: $0 backup|restore"
      exit 1
      ;;

    *)
      exec "$@"
  esac
}

main $@
