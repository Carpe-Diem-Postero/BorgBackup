
##########DEPRECATED###########


#!/bin/sh
log="/logs/qnap-synology-borg.log"
echo "iniciando backup con fecha: `date +%Y-%m-%d`" >> $log
mount 192.168.1.20:/volume1/BACKUP /mnt/synology
if [ $? -ne 0 ]
  then
  echo "error montando carpeta. Terminando backup" >> $log
# Notification to Telegram
  curl -s \
    --data parse_mode=HTML \
    --data chat_id=$chatid \
    --data text="<b>Borg Backup</b>%0A <i>Repo:</i> Qnap-Synology%0A <i>Tarea:</i> <b>Backup</b>%0A  <i>Estado:</i>Error montando carpeta. No se realiza Backup" \
  "https://api.telegram.org/bot$api/sendMessage"
  exit 0
fi
echo "carpeta montada correctamente. Iniciando Backup" >> $log
/persist/backup.sh 2>> $log
# Comprueba si es la primera semana del mes
dia=`date +%d`
if [ "$dia" -ge 1 ] && [ "$dia" -le 7 ]; then # Si el número del día está entre 1 y 7 (primera semana)
  echo "================= Primera semana del mes. Iniciando Check y apagando Synology =================" >> $log
  ssh -i /persist/ssh/qnapcontainer admin@192.168.1.20 nohup sudo /var/services/homes/admin/start-check.sh & # script para iniciar check
  exit 0
fi
# Si no se cumple el IF (no es la primera semana del me�s), no se realiza check
echo "=========================== FINALIZANDO Y APAGANDO SYNOLOGY ===========================" >> $log
ssh -i /persist/ssh/qnapcontainer admin@192.168.1.20 sudo poweroff
