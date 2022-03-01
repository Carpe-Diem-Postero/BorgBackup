############DEPRECATED##############


#!/bin/sh
log="/mnt/user/scripts/logtemp/overkiller-qnap-borg.log"
echo "Montando directorios SMB" >> $log
#mount -t cifs //192.168.1.100/Multimedia /mnt/Multimedia -o credentials=/root/cifs-credentials >> $log
#mount -t cifs //192.168.1.100/Nextcloud /mnt/Nextcloud -o credentials=/root/cifs-credentials >> $log
#mount -t cifs //192.168.1.100/Sync /mnt/Sync -o credentials=/root/cifs-credentials >> $log
#mount -t cifs //192.168.1.100/logs /root/logs -o credentials=/root/cifs-credentials >> $log
echo "iniciando backup con fecha: `date +%Y-%m-%d`" >> $log
/mnt/backup.sh 2>> $log
# Comprueba si es la primera semana del mes
dia=`date +%d`
if [ "$dia" -ge 1 ] && [ "$dia" -le 7 ]; then # Si el numero del dia esta¡ entre 1 y 7 (primera semana)
  echo "================= Primera semana del mes. Iniciando Check =================" >> $log
  /root/check.sh 2>> $log # script para iniciar check
  sleep 5
  cp /root/logtemp/overkiller-qnap-borg.log /root/logs/overkiller-qnap-borg.log
  sleep 5
  echo "Desmontando directorios SMB" >> $log
  umount /mnt/* >> $log
  umount /root/logs >> $log
  sleep 5
  sudo rtcwake -m off -l -t $(date +%s -d "next friday 23:25")
  exit 0
fi
# Si no se cumple el IF (no es la primera semana del mes), no se realiza check
echo "=========================== FINALIZANDO Y APAGANDO QNAP-OMV ===========================" >> $log
cp /root/logtemp/overkiller-qnap-borg.log /root/logs/overkiller-qnap-borg.log
sleep 5
echo "Desmontando directorios SMB" >> $log
umount /mnt/* >> $log
umount /root/logs >> $log
sleep 5
sudo rtcwake -m off -l -t $(date +%s -d "next friday 23:25")
