#!/bin/sh

log="/mnt/user/scripts/logtemp/overkiller-qnap-borg.log"
echo "iniciando backup con fecha: `date +%Y-%m-%d`" >> $log

##General variables. Modify them as you need
chatid=
api=
healthcheck=

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
timestart=`date +%s`

# Notification to Telegram (Start)
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
#    /home                           \
#    /root                              \
#    /var                                \

backup_exit=$?

if [ $backup_exit -eq 0 ]; then backup_re="Backup correcto"
elif [ $backup_exit -eq 1 ]; then backup_re="Backup completado pero con advertencias"
else backup_re="ERROR EN BACKUP"

info "Pruning repository"

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                     \
    --list                              \
    --prefix 'Overkiller-'    \
    --show-rc                      \
    --keep-last     	8	      \
    --keep-weekly   12       \
    --keep-monthly  24      \

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
telegramlog="/scripts/backup`date +%Y-%m-%d`.log"
grep -B 1 -A 100 "Archive name: Overkiller-`date +%Y-%m-%d`" /mnt/user/scripts/logtemp/overkiller-qnap-borg.log > $telegramlog

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
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->QNAP%0A    <i>Tarea:</i> <b>Backup</b>%0A    <i>Tiempo total:</i>$totaltime%0A    <i>Estado:</i> $backup_re , $prune_re" \
  "https://api.telegram.org/bot$api/sendMessage"

curl -v -4 -F \
  "chat_id=$chatid" \
  -F document=@$telegramlog \
  -F caption="Log: `date +%Y-%m-%d`.log" \
  https://api.telegram.org/bot$api/sendDocument 2> /dev/null

#deleteting temporal log file
rm $telegramlog

# Comprueba si es la primera semana del mes
dia=`date +%d`
if [ "$dia" -ge 1 ] && [ "$dia" -le 7 ]; then # Si el numero del dia esta¡ entre 1 y 7 (primera semana)
  echo "================= Primera semana del mes. Iniciando Check =================" >> $log
  borg check                 \
    -v                              \
    -p                              \
    --show-rc                 \

  check_exit=$?

  if [ $check_exit -eq 0 ]; then check_re="Check correcto"
  elif [ $check_exit -eq 1 ]; then check_re="Check completado pero con advertencias"
  else check_re="ERROR EN CHECK"

  # Notification to Telegram
  curl -s \
  --data parse_mode=HTML \
  --data chat_id=$chatid \
  --data text="<b>Borg Backup</b>%0A    <i>Repo:</i> Overkiller->QNAP%0A    <i>Tarea:</i> <b>Check del repositorio</b>%0A    <i>Estado:</i> $check_re" \
  "https://api.telegram.org/bot$api/sendMessage"

  sleep 5
  cp /mnt/user/scripts/logtemp/overkiller-qnap-borg.log /mnt/remotes/logs/overkiller-qnap-borg.log
  sleep 5
  sudo rtcwake -m off -l -t $(date +%s -d "next friday 23:25")
  exit 0
fi
# Si no se cumple el IF (no es la primera semana del mes), no se realiza check
echo "=========================== FINALIZANDO Y APAGANDO QNAP-OMV ===========================" >> $log
cp /mnt/user/scripts/logtemp/overkiller-qnap-borg.log /mnt/remotes/logs/overkiller-qnap-borg.log
sleep 5



exit ${global_exit}
