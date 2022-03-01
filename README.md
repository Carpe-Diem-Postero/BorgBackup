# BorgBackup

Script Genérico de Borg Backup para uso personal. Utiliza Borg Backup para hacer pull de directorios montados por SMB y realizar backup en local.

Incluye:
- Backup usando pull
- Control del día actual. Si el día del mes es la primera semana, al finalizar el backup, inicia check del repositorio
- Notificaciones por Telegram
- Monitorización de los trabajos a través de Healthcheks.io
- Guarda todo lo realizado en un archivo log
