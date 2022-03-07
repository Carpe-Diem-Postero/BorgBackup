#!/bin/sh

## General variables. Chatid is telegram chatid to send notifications. api is telegram bot's token. Healthcheck is healthchecks.io's API. Modify them as you need
chatid="xxxx"
api="yyyyy"
healthcheck="zzzzz"

## Set current Date
datelog=`date +%Y-%m-%d`
## Log file to store Borg output
log="/mnt/user/scripts/logtemp/overkiller-qnap-borg.log"
echo "iniciando backup con fecha: $datelog" >> $log

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=/mnt/user/borgbackup

# Setting this, so you won't be asked for your repository passphrase:
export BORG_PASSPHRASE='PASSWORD'
# or this to ask an external program to supply the passphrase:
# export BORG_PASSCOMMAND='pass show backup'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Starting backup"

# Time count start
timestart=$SECONDS

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
    --verbose                                          \
    --filter AME                                       \
    --list                                                    \
    --stats                                                 \
    --show-rc                                            \
    --compression lz4                             \
    --files-cache ctime,size                     \
    --exclude-caches                                \
    --exclude '/home/*/.cache/*'           \
    --exclude '/var/cache/*'                     \
    --exclude '/var/tmp/*'                        \
    --exclude '*@Recycle/*'                     \
    --exclude '*@Recently-Snapshot/*' \
    --exclude '*.@__thumb/*'                  \
                                      \
    ::'Overkiller-{now:%Y-%m-%d}'          \
     /mnt/remotes/              \
     2>> $log

backup_exit=$?

if [ $backup_exit -eq 0 ]; then backup_re="Backup correcto"
elif [ $backup_exit -eq 1 ]; then backup_re="Backup completado pero con advertencias"
else backup_re="ERROR EN BACKUP"

info "Pruning repository"

# Use the `prune` subcommand to maintain last 8, 12 weekly and 24 monthly
# archives of THIS machine. The '{hostname}-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                     \
    --list                              \
    --prefix 'Overkiller-'    \
    --show-rc                      \
    --keep-last     8	      \
    --keep-weekly   12       \
    --keep-monthly  24      \
    2>> $log

prune_exit=$?

if [ $prune_exit -eq 0 ]; then prune_re="Prune correcto"
elif [ $prune_exit -eq 1 ]; then prune_re="Prune completado pero con advertencias"
else prune_re="ERROR EN PRUNE"

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup and Prune finished successfully"
elif [ ${global_exit} -eq 1 ]; then
    info "Backup and/or Prune finished with warnings"
else
    info "Backup and/or Prune finished with errors"
fi

#capturing log to send using telegram bot
telegramlog="/mnt/user/scripts/backup$datelog.log"
grep -B 1 -A 100 "Archive name: Overkiller-$datelog" /mnt/user/scripts/logtemp/overkiller-qnap-borg.log > $telegramlog

# Time count stop
timestop=`date +%s`
# Total execution time (in seconds)
runtime=$(( SECONDS - timestart ))
# Total execution time conversion
D=$((runtime/60/60/24))
H=$((runtime/60/60%24))
M=$((runtime/60%60))
S=$((runtime%60))
totaltime="$D días, $H horas, $M minutos, $S segundos"

# Notification to Telegram (End Backup + Send Log)
curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->QNAP%0A    <i>Tarea:</i> <b>Backup</b>%0A    <i>Tiempo total:</i>$totaltime%0A    <i>Estado:</i> $backup_re , $prune_re" \
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

# Checks if it's the first week of month, and perform perform repository check if so.
dia=`date +%d`
if [ "$dia" -ge 1 ] && [ "$dia" -le 7 ]; then # Si el numero del dia esta entre 1 y 7 (primera semana)
  
  # Notification to Telegram (Start Check)
  curl -s \
    --data parse_mode=HTML \
    --data chat_id=$chatid \
    --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->UnQNAP%0A    <i>Tarea:</i> <b>Check</b>%0A    <i>Estado:</i> Iniciando Check del Repositorio" \
  "https://api.telegram.org/bot$api/sendMessage"
  
  echo "================= Primera semana del mes. Iniciando Check =================" >> $log
  borg check                 \
    -v                              \
    -p                              \
    --show-rc                 \
    2>> $log

  check_exit=$?

  if [ $check_exit -eq 0 ]; then check_re="Check correcto"
  elif [ $check_exit -eq 1 ]; then check_re="Check completado pero con advertencias"
  else check_re="ERROR EN CHECK"

  # Notification to Telegram (End Check)
  curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->QNAP%0A    <i>Tarea:</i> <b>Check del repositorio</b>%0A    <i>Estado:</i> $check_re" \
  "https://api.telegram.org/bot$api/sendMessage"
  
  echo "=========================== FINALIZANDO Y APAGANDO UnQNAP ===========================" >> $log
  # Copy log to remote device and shutdown local device until next Friday 23:35h 
  sleep 5
  cp /mnt/user/scripts/logtemp/overkiller-qnap-borg.log /mnt/remotes/logs/overkiller-qnap-borg.log
  sleep 5
  rtcwake -m off -l -t $(date +%s -d "next friday 23:25")
  exit 0
fi

# If it's not the first week of month, don't perform repository check.
echo "=========================== FINALIZANDO Y APAGANDO UnQNAP ===========================" >> $log

# Copy log to remote device and shutdown local device until next Friday 23:35h 
cp /mnt/user/scripts/logtemp/overkiller-qnap-borg.log /mnt/remotes/logs/overkiller-qnap-borg.log
sleep 5
rtcwake -m off -l -t $(date +%s -d "next friday 23:25")

exit ${global_exit}
