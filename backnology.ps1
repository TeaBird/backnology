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
$Username = ""
$Password = ""

# paths
$SourceFolder = "D:\TEST_FOLDER"
$RemoteFolder = "/Backup1/TEST_FOLDER"

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

    Write-Log "передача файлов"

    try {

        # Создание credential
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($Username, $securePassword)

        # Подключение
        Write-Log "подключение к $XpenologyIP`:$Port..."

        $sessionParams = @{
            ComputerName     = $XpenologyIP
            Port             = $Port
            Credential       = $credential
            AcceptKey        = $true
            ConnectionTimeout = 60000
        }

        $sftpSession = New-SFTPSession @sessionParams

        if (-not $sftpSession.Connected) {
            throw "не удалось подключиться к SFTP серверу"
        }

        Write-Log "успешное подключение session ID: $($sftpSession.SessionId)"

        # проверка удаленной папки
        try {
            Get-SFTPChildItem -SessionId $sftpSession.SessionId -Path $RemoteFolder -ErrorAction Stop | Out-Null
            Write-Log "папка существует: $RemoteFolder"
            }
        catch {
            Write-Log "папка не существует. Создаю: $RemoteFolder"
        try {
            New-SFTPItem -SessionId $sftpSession.SessionId `
                     -Path $RemoteFolder `
                     -ItemType Directory `

            Write-Log "папка создана: $RemoteFolder"
            }
        catch {
            Write-Log "не удалось создать папку ${RemoteFolder}: $($_.Exception.Message)"
        throw
                }
            }

        # поиск последнего файла
        $latestFile = Get-ChildItem -Path $SourceFolder -File |
                      Sort-Object LastWriteTime -Descending |
                      Select-Object -First 1

        if (-not $latestFile) {
            Write-Log "нет файлов для передачи."
        }
        else {
            $fileSizeKB = [math]::Round($latestFile.Length / 1KB, 2)
            Write-Log "отправка последнего файла: $($latestFile.Name) ($fileSizeKB KB)"

            try {
                Set-SFTPItem -SessionId $sftpSession.SessionId `
                             -Path $latestFile.FullName `
                             -Destination $RemoteFolder `
                             -Force

                Write-Log "файл успешно отправлен."
            }
            catch {
                Write-Log "ошибка отправки файла: $($_.Exception.Message)"
            }
        }

        # Закрытие сессии
        Remove-SFTPSession -SessionId $sftpSession.SessionId | Out-Null
        Write-Log "сессия закрыта"

    }
    catch {
        Write-Log "критическая ошибка: $($_.Exception.Message)"
    }
    finally {
        Write-Log "передача завершена"
    }

    # Ожидание 7 дней
    Write-Log "ожидание 7 дней до следующего запуска..."
    Start-Sleep -Seconds 604800 # 7days
}
