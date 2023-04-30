#!/bin/sh

## General variables. Modify them as you need
chatid="XXXXXXXX" #chatid is telegram chatid to send notifications
api="XXXXXX:XXXXXXXXX" #api is telegram bot's token.
healthcheck="XXXXXXXXXXXX" #Healthcheck is healthchecks.io's API.
log="/etc/borgmatic.d/overkiller-qnap-borg.log" #Log file to store Borg output in the current device
logstorage="/remote_logs" #Where final log will be copied in the remote device
# export BORG_BASE_DIR=/mnt/user/borgdir #Location of Borg Backup base directory (cache and temp files storage). Only use if you are not using default path
export BORG_REPO="/bkp-to" #Repository location
export BORG_PASSPHRASE='XXXXXXXXXXXXXXXXXXXX' #Repository Password
# export BORG_PASSCOMMAND='pass show backup' # or this to ask an external program to supply the passphrase:


## Set current Date
datelog=`date +%Y-%m-%d`

echo "iniciando backup con fecha: $datelog" >> $log

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Starting backup"

# Time count start
timestart=`date +%s`

# Notification to Telegram (Start Backup)
curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->UnQNAP%0A    <i>Tarea:</i> <b>Backup</b>%0A    <i>Estado:</i> Iniciando Backup" \
  "https://api.telegram.org/bot$api/sendMessage"

# Healthcheck start hook
 curl -m 10 --retry 5 https://hc-ping.com/$healthcheck/start

# Backup the most important directories into an archive named after
# the machine this script is currently running on:

borg create                                          \
    --verbose                                        \
    --filter AME                                     \
    --list                                           \
    --stats                                          \
    --show-rc                                        \
    --compression lz4                                \
    --files-cache ctime,size                         \
    --exclude-caches                                 \
    --exclude '/home/*/.cache/*'                     \
    --exclude '/var/cache/*'                         \
    --exclude '/var/tmp/*'                           \
    --exclude '*@Recycle/*'                          \
    --exclude '*@Recently-Snapshot/*'                \
    --exclude '*.@__thumb/*'                         \
                                                     \
    ::'Overkiller-{now:%Y-%m-%d}'                    \
     /mnt/remotes/                                   \
     2>> $log

backup_exit=$?

if [ $backup_exit -eq 0 ]; then backup_re="Backup correcto"
elif [ $backup_exit -eq 1 ]; then backup_re="Backup completado pero con advertencias"
else backup_re="ERROR EN BACKUP"
fi

info "Pruning repository"

# Use the `prune` subcommand to maintain last 8, 12 weekly and 24 monthly
# archives of THIS machine. The '{hostname}-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                                           \
    --list                                           \
    --show-rc                                        \
    --keep-last     8                                \
    --keep-weekly   12                               \
    --keep-monthly  24                               \
    2>> $log

prune_exit=$?

if [ $prune_exit -eq 0 ]; then prune_re="Prune correcto"
elif [ $prune_exit -eq 1 ]; then prune_re="Prune completado pero con advertencias"
else prune_re="ERROR EN PRUNE"
fi

# Run Borg Compact
borg compact

compact_exit=$?

if [ $compact_exit -eq 0 ]; then compact_re="Compact correcto"
elif [ $compact_exit -eq 1 ]; then compact_re="Compact completado pero con advertencias"
else compact_re="ERROR EN COMPACT"
fi

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup and Prune finished successfully" >> $log
elif [ ${global_exit} -eq 1 ]; then
    info "Backup and/or Prune finished with warnings" >> $log
else
    info "Backup and/or Prune finished with errors" >> $log
fi

#capturing log to send using telegram bot
telegramlog="/etc/borgmatic.d/backup$datelog.log"
grep -B 1 -A 100 "Archive name: Overkiller-$datelog" $log > $telegramlog

# Time count stop
timestop=`date +%s`
# Total execution time (in seconds)
runtime=$(( timestop - timestart ))
# Total execution time conversion
D=$((runtime/60/60/24))
H=$((runtime/60/60%24))
M=$((runtime/60%60))
S=$((runtime%60))
totaltime="${D}d, ${H}h, ${M}m, ${S}s"

# Notification to Telegram (End Backup + Send Log)
curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->QNAP%0A    <i>Tarea:</i> <b>Backup</b>%0A    <i>Tiempo total:</i>$totaltime%0A    <i>Estado:</i> $backup_re , $prune_re , $compact_re" \
  "https://api.telegram.org/bot$api/sendMessage"

curl -v -4 -F \
  "chat_id=$chatid" \
  -F document=@$telegramlog \
  -F caption="Log: $datelog.log" \
  https://api.telegram.org/bot$api/sendDocument 2> /dev/null

# Deleteting temporal log file
rm $telegramlog

# Healthcheck end hook
 curl -m 10 --retry 5 https://hc-ping.com/$healthcheck

# Checks if it's the first week of month, and perform repository check if so.
dia=`date +%d`
if [ "$dia" -ge 1 ] && [ "$dia" -le 7 ]; then # Si el numero del dia esta entre 1 y 7 (primera semana)

  curl -s \
    --data parse_mode=HTML \
    --data chat_id=$chatid \
    --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->UnQNAP%0A    <i>Tarea:</i> <b>Check</b>%0A    <i>Estado:</i> Iniciando Check del Repositorio" \
  "https://api.telegram.org/bot$api/sendMessage"

  echo "================= Primera semana del mes. Iniciando Check =================" >> $log
  borg check                                         \
    -v                                               \
    -p                                               \
    --show-rc                                        \
    2>> $log

  check_exit=$?

  if [ $check_exit -eq 0 ]; then check_re="Check correcto"
  elif [ $check_exit -eq 1 ]; then check_re="Check completado pero con advertencias"
  else check_re="ERROR EN CHECK"
  fi

  # Notification to Telegram (End Check)
  curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->QNAP%0A    <i>Tarea:</i> <b>Check del repositorio</b>%0A    <i>Estado:</i> $check_re" \
  "https://api.telegram.org/bot$api/sendMessage"

  echo "=========================== FINALIZANDO Y APAGANDO UnQNAP ===========================" >> $log
  # Copy log to remote device and shutdown local device until next Friday 23:35h
  sleep 5
  cp $log $logstorage/overkiller-qnap-borg.log
  sleep 5
#  rtcwake -m off -l -t $(date +%s -d "next friday 23:25") #Uncomment this line if you want rtcwake to sleep your device. Only works if compatible
  exit 0
fi

# If it's not the first week of month, don't perform repository check.
echo "=========================== FINALIZANDO Y APAGANDO UnQNAP ===========================" >> $log

# Copy log to remote device and shutdown local device until next Friday 23:35h
cp $log $logstorage/overkiller-qnap-borg.log
sleep 5
# rtcwake -m off -l -t $(date +%s -d "next friday 23:25") #Uncomment this line if you want rtcwake to sleep your device. Only works if compatible

exit ${global_exit}
