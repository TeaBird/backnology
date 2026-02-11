# import
try {
    Import-Module "C:\backnology\Posh-SSH.psd1"
    Write-Host "Модуль Posh-SSH загружен"
} catch {
    Write-Host "ОШИБКА: Не удалось загрузить модуль Posh-SSH"
    exit 1
}

# config 
$XpenologyIP = ""
$Port = 
$Username = Read-Host "Введите имя пользователя для SFTP"
$Password = Read-Host "Введите пароль для SFTP" -AsSecureString

# paths
$SourceFolders = @(
    "D:\TEST_FOLDER",
    "D:\ARCHIVE"
)
$RemoteRoot = "/Backup1/TEST_FOLDER"

$LogFile = "C:\BackupScripts\backup_log.txt"
$ErrorActionPreference = "Stop"

# log
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Add-Content -Path $LogFile -Value $logMessage
    Write-Host $logMessage
}

# main_loop
while ($true) {

    Write-Log "старт цикла"

    try {

        # Создание credential
        $credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)

        # Подключение
        Write-Log "подключение к $XpenologyIP`:$Port..."
        $sessionParams = @{
            ComputerName      = $XpenologyIP
            Port              = $Port
            Credential        = $credential
            AcceptKey         = $true
            ConnectionTimeout = 60000
        }
        $sftpSession = New-SFTPSession @sessionParams

        if (-not $sftpSession.Connected) {
            throw "не удалось подключиться к SFTP серверу"
        }

        Write-Log "успешное подключение. Session ID: $($sftpSession.SessionId)"

        # проверка корневой папки на сервере
        try {
            Get-SFTPChildItem -SessionId $sftpSession.SessionId -Path $RemoteRoot -ErrorAction Stop | Out-Null
            Write-Log "корневая папка существует: $RemoteRoot"
        } catch {
            Write-Log "корневая папка не существует. Создаю: $RemoteRoot"
            New-SFTPItem -SessionId $sftpSession.SessionId -Path $RemoteRoot -ItemType Directory | Out-Null
            Write-Log "корневая папка создана: $RemoteRoot"
        }

        # перебор всех исходных папок
        foreach ($RootFolder in $SourceFolders) {

            # проверка существования локальной папки
            if (-not (Test-Path $RootFolder)) {
                Write-Log "локальная папка не существует: $RootFolder"
                continue
            }

            # перебор подпапок
            $SubFolders = Get-ChildItem -Path $RootFolder -Directory
            foreach ($SubFolder in $SubFolders) {
                Write-Log "обрабатываю папку: $($SubFolder.FullName)"

                # поиск последнего файла в подпапке
                $latestFile = Get-ChildItem -Path $SubFolder.FullName -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if (-not $latestFile) {
                    Write-Log "нет файлов в папке: $($SubFolder.FullName)"
                    continue
                }

                $fileSizeKB = [math]::Round($latestFile.Length / 1KB, 2)
                Write-Log "последний файл: $($latestFile.Name) ($fileSizeKB KB)"

                # формируем путь на сервере
                $remoteFolder = "$RemoteRoot/$($SubFolder.Name)"

                # проверка существования папки на сервере, если нет – создаём
                try {
                    Get-SFTPChildItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ErrorAction Stop | Out-Null
                    Write-Log "папка существует: $remoteFolder"
                } catch {
                    Write-Log "папка не существует. Создаю: $remoteFolder"
                    New-SFTPItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ItemType Directory | Out-Null
                    Write-Log "папка создана: $remoteFolder"
                }

                # отправка файла
                try {
                    Set-SFTPItem -SessionId $sftpSession.SessionId `
                                 -Path $latestFile.FullName `
                                 -Destination $remoteFolder `
                                 -Force
                    Write-Log "файл успешно отправлен: $($latestFile.Name) -> $remoteFolder"
                } catch {
                    Write-Log "ошибка отправки файла: $($_.Exception.Message)"
                }
            }
        }

        # закрытие сессии
        Remove-SFTPSession -SessionId $sftpSession.SessionId | Out-Null
        Write-Log "сессия закрыта"

    } catch {
        Write-Log "критическая ошибка: $($_.Exception.Message)"
    } finally {
        Write-Log "передача завершена"
    }

    $NextRun = (Get-Date).AddDays(7)
    Write-Log "Ожидание 7 дней до следующего запуска... Следующий запуск: $($NextRun.ToString('yyyy-MM-dd HH:mm:ss'))"
    Start-Sleep -Seconds 604800 # 7 дней
}
