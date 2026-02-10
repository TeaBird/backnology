# import posh ssh
try {
    Import-Module "D:\progs\Posh-SSH\Posh-SSH\Posh-SSH.psd1"
    Write-Host "Модуль Posh-SSH загружен"
} catch {
    Write-Host "ОШИБКА: Не удалось загрузить модуль Posh-SSH"
    Write-Host "Проверьте путь: D:\progs\Posh-SSH\Posh-SSH\Posh-SSH.psd1"
    exit 1
}

# config
$XpenologyIP = ""
$Port = 
$Username = ""
$Password = ""

# paths
$SourceFolder = "D:\TEST_FOLDER"
$RemoteFolder = "/volume1/Backup1/TEST_FOLDER"

# logs
$LogFile = "C:\BackupScripts\transfer_log.txt"
$ErrorActionPreference = "Stop"

# logs function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Add-Content -Path $LogFile -Value $logMessage
    Write-Host $logMessage
}

Write-Log "=== Начало передачи файлов ==="

try {
    # sftp session
    Write-Log "Подключаюсь к $XpenologyIP`:$Port..."
    
    $sessionParams = @{
        ComputerName = $XpenologyIP
        Port = $Port
        Credential = (New-Object System.Management.Automation.PSCredential($Username, 
                    (ConvertTo-SecureString $Password -AsPlainText -Force)))
        AcceptKey = $true
		ConnectionTimeout = 60000
    }
    
    $sftpSession = New-SFTPSession @sessionParams
    
    if (-not $sftpSession.Connected) {
        throw "Не удалось подключиться к SFTP серверу"
    }
    
    Write-Log "Успешное подключение. Session ID: $($sftpSession.SessionId)"
    
    # 5. file check
    $files = Get-ChildItem -Path $SourceFolder -File
    
    if ($files.Count -eq 0) {
        Write-Log "Нет файлов для передачи в $SourceFolder"
    } else {
        Write-Log "Найдено файлов для передачи: $($files.Count)"
        
        # 6. recursive file sending
        foreach ($file in $files) {
            $localFile = $file.FullName
            $remoteFile = "$RemoteFolder/$($file.Name)"
            $fileSizeMB = [math]::Round($file.Length / 1kb, 2)
            
            Write-Log "Отправка: $($file.Name) ($fileSizeMB kb)..."
            
            try {
                Set-SFTPItem -SessionId $sftpSession.SessionId `
                            -Path $localFile `
                            -Destination $remoteFile
                Write-Log " Успешно отправлен: $($file.Name)"
                      
                
            } catch {
                Write-Log " Ошибка отправки $($file.Name): $_"
            }
        }
    }
    
    # 7. close session
    Remove-SFTPSession -SessionId $sftpSession.SessionId | Out-Null
    Write-Log "Сессия закрыта"
    
} catch {
    Write-Log "Критическая ошибка: $_"
    Write-Log $_.Exception.Message
} finally {
    Write-Log "Передача завершена"
}
