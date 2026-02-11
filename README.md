<img width="727" height="535" alt="image" src="https://github.com/user-attachments/assets/92423818-ad02-4f6d-bd9e-6daa1442fdfd" /># backnology
posh_ssh + xpenology + backups script

Скрипт для отправки бекапов на удаленный хост по fstp через Posh-Ssh

#Конфигурация для хостов:
'
paths:
$SourceFolder = "D:\TEST_FOLDER"
$RemoteFolder = "/Backup1/TEST_FOLDER"
$ErrorActionPreference = "Stop"
'
#Необходимые компоненты:
Powershell v5.1+
.Net Framework v4.8+
