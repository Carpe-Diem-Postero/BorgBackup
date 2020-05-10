#!/bin/sh

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=/path/to/repo

# Setting this, so you won't be asked for your repository passphrase:
export BORG_PASSPHRASE='PASSWORD'
# or this to ask an external program to supply the passphrase:
# export BORG_PASSCOMMAND='pass show backup'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Starting backup"

# Time count start
timestart=`date +%s`

# Notification to Telegram (Start)
curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Qnap-Synology%0A    <i>Tarea:</i> <b>Backup</b>%0A    <i>Estado:</i> Iniciando Backup" \
  "https://api.telegram.org/bot$api/sendMessage"

# Backup the most important directories into an archive named after
# the machine this script is currently running on:

borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    --files-cache ctime,size        \
    --exclude-caches                \
    --exclude '/home/*/.cache/*'    \
    --exclude '/var/cache/*'        \
    --exclude '/var/tmp/*'          \
    --exclude '*@Recycle/*'          \
    --exclude '*@Recently-Snapshot/*' \
    --exclude '*.@__thumb/*'           \
    --exclude '*@DownloadStationTempFiles/*' \
    --exclude '/output/Container/container-station-data/*'    \
                                     \
    ::'QNAP-{now:%Y-%m-%d}'          \
     /output                         \

backup_exit=$?

info "Pruning repository"

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                          \
    --list                          \
    --prefix 'QNAP-'                \
    --show-rc                       \
    --keep-last     20 		    \
    --keep-weekly   12              \
    --keep-monthly  24              \

prune_exit=$?

#borg check                          \
#    -v                              \
#    -p                              \
#    --show-rc                       \
#    --last 1                        \
#
#check_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup and Prune finished successfully"
elif [ ${global_exit} -eq 1 ]; then
    info "Backup and/or Prune finished with warnings"
else
    info "Backup and/or Prune finished with errors"
fi

# Time count stop
timestop=`date +%s`
# Total execution time (in seconds)
runtime=$((timestop-timestart))
# Total execution time conversion
totaltime=`date -d@$runtime -u +%H:%M:%S`

# Notification to Telegram
curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Qnap-Synology%0A    <i>Tarea:</i> <b>Backup</b>%0A    <i>Tiempo total:</i>$totaltime%0A    <i>Estado:</i> Finalizado con status: Backup=rc$backup_exit, Prune=rc$prune_exit" \
  "https://api.telegram.org/bot$api/sendMessage"

exit ${global_exit}
