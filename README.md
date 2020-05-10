# BorgBackup

Script Genérico de Borg Backup para uso personal. Utiliza Borg Backup para hacer push de archivos a repositorio local por NFS.

Incluye:
- Montar carpeta de repositorio por NFS
- Backup usando push
- Control del día actual. Si el día del mes es la primera semana, al finalizar el backup, inicia un script por SSH en el servidor del repositorio para que realice borg check por su cuenta
- Notificaciones por Telegram
- Guarda todo lo realizado en un archivo log

Costa de dos archivos: start.sh y backup.sh. El script se inicia con start.sh, monta carpeta, lanza backup.sh, y finaliza.

# Pendiente:
- Crear archivo .conf para las credenciales de Borg y del bot de Telegram
- Modificar los sh para incluir las credenciales
- Subir el archivo start-check.sh que se ejecuta server-side
