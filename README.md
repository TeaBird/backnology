<img width="100" height="100" alt="dura_seagull" src="https://github.com/user-attachments/assets/61ce4fdb-c717-4570-b4e3-679aaefe6e5a" />

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
- предлагает два режима отправки: рекурсивно подпапки в папке и простой - последний файл из папок

---

##  Конфигурация

Основные параметры:

```powershell
# Вводим пароль
$Password = Read-Host "Введите пароль SFTP" -AsSecureString

# Сохраняем зашифрованный пароль в файл
$Password | ConvertFrom-SecureString | Set-Content "C:\backnology\sftp_pass.txt"
```

```powershell
# Paths
$SourceFolders = @(
    "D:\TEST_FOLDER",
    "D:\ARCHIVE"
)
$RemoteFolder = "/Backup1/TEST_FOLDER"

# Error handling
$ErrorActionPreference = "Stop"
```

## Развертка

https://teabird.github.io/documentation/backnology.html
