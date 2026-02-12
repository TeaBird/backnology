# import
try {
    Import-Module "C:\backnology\Posh-SSH.psd1" -ErrorAction Stop
    Write-Host "Модуль Posh-SSH загружен"
} catch {
    Write-Host "ОШИБКА: Не удалось загрузить модуль Posh-SSH"
    exit 1
}


# config

$XpenologyIP = ""
$Port        = 33878
$Username    = "backup_user"
$SecurePassword = Get-Content "C:\backnology\sftp_pass.txt" | ConvertTo-SecureString
$credential     = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)

$Mode = "recursive"
Write-Host "Выбран режим: $Mode"
Write-Host ""

# paths
$SourceFolders = @(
    "D:\TEST_FOLDER",
    "D:\ARCHIVE"
)
$RemoteRoot = "/Backup1/TEST_FOLDER"
$LogFile    = "C:\backnology\backup_log.txt"
$ErrorActionPreference = "Stop"


# log functions

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Add-Content -Path $LogFile -Value $logMessage
    Write-Host $logMessage
}

function Test-FileLocked {
    param([string]$Path)
    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $stream.Close()
        return $false
    } catch {
        return $true
    }
}

function Send-TelegramMessage {
    param([string]$Message)
    $BotToken = "8461617617:AAEis91c1hz9Goouhag4zDaTZ_Zg-FxJEY8"
    $ChatId   = "540824120"
    $url      = "https://api.telegram.org/bot$BotToken/sendMessage"
    $body     = @{
        chat_id    = $ChatId
        text       = $Message
        parse_mode = "HTML"
    }
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $body
    } catch {
        Write-Host "Не удалось отправить сообщение в Telegram: $($_.Exception.Message)"
    }
}


# main backup

Write-Log "Старт скрипта"
Write-Log "Режим работы: $Mode"

try {
    Write-Log "Подключение к $XpenologyIP`:$Port..."
    
    # Создаём SFTP сессию
    $sftpSession = New-SFTPSession -ComputerName $XpenologyIP `
                                   -Port $Port `
                                   -Credential $credential `
                                   -AcceptKey `
                                   -ConnectionTimeout 60000

    if (-not $sftpSession -or -not $sftpSession.Connected) {
        throw "Не удалось подключиться к SFTP серверу"
    }

    Write-Log "Успешное подключение. Session ID: $($sftpSession.SessionId)"

    # Проверка корневой папки
    try {
        Get-SFTPChildItem -SessionId $sftpSession.SessionId -Path $RemoteRoot -ErrorAction Stop | Out-Null
        Write-Log "Корневая папка существует: $RemoteRoot"
    } catch {
        Write-Log "Корневая папка не существует. Создаю: $RemoteRoot"
        New-SFTPItem -SessionId $sftpSession.SessionId -Path $RemoteRoot -ItemType Directory | Out-Null
        Write-Log "Корневая папка создана: $RemoteRoot"
    }

    
    # перебор исходных папок
    
    foreach ($RootFolder in $SourceFolders) {
        if (-not (Test-Path $RootFolder)) {
            Write-Log "Локальная папка не существует: $RootFolder"
            continue
        }

        $SubFolders = if ($Mode -eq "recursive") { Get-ChildItem -Path $RootFolder -Directory } else { @($RootFolder) }

        foreach ($SubFolder in $SubFolders) {
            $folderPath = if ($Mode -eq "recursive") { $SubFolder.FullName } else { $SubFolder }
            Write-Log "Обрабатываю папку: $folderPath"

            $latestFile = Get-ChildItem -Path $folderPath -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $latestFile) {
                Write-Log "Нет файлов в папке: $folderPath"
                continue
            }

            $fileSizeKB = [math]::Round($latestFile.Length / 1KB, 2)
            Write-Log "Последний файл: $($latestFile.Name) ($fileSizeKB KB)"
            $remoteFolder = "$RemoteRoot/$([System.IO.Path]::GetFileName($folderPath))"

            try { Get-SFTPChildItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ErrorAction Stop | Out-Null }
            catch { New-SFTPItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ItemType Directory | Out-Null }

            # проверка блокировки файла
            $maxAttempts = 10
            $attempt     = 0
            $waitSeconds = 30

            while (Test-FileLocked $latestFile.FullName -and $attempt -lt $maxAttempts) {
                Write-Log "Файл занят другим процессом. Ожидание $waitSeconds сек... (Попытка $($attempt+1)/$maxAttempts)"
                Start-Sleep -Seconds $waitSeconds
                $attempt++
            }

            if (Test-FileLocked $latestFile.FullName) {
                Write-Log "Файл так и не освободился. Пропускаю: $($latestFile.Name)"
                Send-TelegramMessage "Бэкап не выполнен: $($latestFile.FullName) — файл занят"
                continue
            }

            # Отправка файла
            try {
                Set-SFTPItem -SessionId $sftpSession.SessionId `
                             -Path $latestFile.FullName `
                             -Destination $remoteFolder `
                             -Force
                Write-Log "Файл успешно отправлен: $($latestFile.Name) -> $remoteFolder"
                Send-TelegramMessage "Бэкап выполнен: $($latestFile.FullName) -> $remoteFolder"
            } catch {
                Write-Log "Ошибка отправки файла: $($_.Exception.Message)"
                Send-TelegramMessage "Бэкап не выполнен: $($latestFile.FullName) — ошибка: $($_.Exception.Message)"
            }
        }
    }

    # Закрытие сессии
    Remove-SFTPSession -SessionId $sftpSession.SessionId | Out-Null
    Write-Log "Сессия закрыта"

} catch {
    Write-Log "Критическая ошибка: $($_.Exception.Message)"
    Send-TelegramMessage "Критическая ошибка бэкапа: $($_.Exception.Message)"
} finally {
    Write-Log "Передача завершена"
}

Write-Log "Скрипт завершён."
