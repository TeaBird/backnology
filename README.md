<img width="40" height="40" alt="dura_seagull" src="https://github.com/user-attachments/assets/61ce4fdb-c717-4570-b4e3-679aaefe6e5a" />

# backnology 

**Posh-SSH + Xpenology + Backup Script**

Скрипт для автоматической отправки резервных копий на удалённый хост по SFTP через модуль Posh-SSH.

---

## Описание

Скрипт выполняет:

- подключение к удалённому серверу (Xpenology / NAS)
- передачу файлов по SFTP
- логирование всех операций
- (опционально) запуск в цикле раз в 7 дней
- отправку только последнего по времени файла

---

##  Конфигурация

Основные параметры:

```powershell
# Paths
$SourceFolder = "D:\TEST_FOLDER"
$RemoteFolder = "/Backup1/TEST_FOLDER"

# Error handling
$ErrorActionPreference = "Stop"
