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
$Port = 33878
$Username = Read-Host "Введите имя пользователя для SFTP"
$Password = Read-Host "Введите пароль для SFTP" -AsSecureString

# выбор режима запуска
Write-Host ""
Write-Host "Выберите режим запуска:"
Write-Host "1 - Последний файл из каждой папки массива (simple)"
Write-Host "2 - Рекурсивно: последний файл из каждой подпапки (recursive)"
Write-Host ""

$ModeChoice = Read-Host "Введите 1 или 2"

switch ($ModeChoice) {
    "1" { $Mode = "simple" }
    "2" { $Mode = "recursive" }
    default {
        Write-Host "Некорректный выбор. Используется режим по умолчанию: recursive"
        $Mode = "recursive"
    }
}

Write-Host "Выбран режим: $Mode"
Write-Host ""


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
    Write-Log "режим работы: $Mode"
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
       # выбор логики работы
if ($Mode -eq "simple") {

    Write-Log "режим simple: последний файл из каждой папки массива"

    foreach ($RootFolder in $SourceFolders) {

        if (-not (Test-Path $RootFolder)) {
            Write-Log "локальная папка не существует: $RootFolder"
            continue
        }

        $latestFile = Get-ChildItem -Path $RootFolder -File |
                      Sort-Object LastWriteTime -Descending |
                      Select-Object -First 1

        if (-not $latestFile) {
            Write-Log "нет файлов в папке: $RootFolder"
            continue
        }

        $fileSizeKB = [math]::Round($latestFile.Length / 1KB, 2)
        Write-Log "последний файл: $($latestFile.Name) ($fileSizeKB KB)"

        $remoteFolder = "$RemoteRoot/$([System.IO.Path]::GetFileName($RootFolder))"

        # создаём папку если нет
        try {
            Get-SFTPChildItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ErrorAction Stop | Out-Null
        } catch {
            New-SFTPItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ItemType Directory | Out-Null
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
else {

    Write-Log "режим recursive: последний файл из каждой подпапки"

    foreach ($RootFolder in $SourceFolders) {

        if (-not (Test-Path $RootFolder)) {
            Write-Log "локальная папка не существует: $RootFolder"
            continue
        }

        $SubFolders = Get-ChildItem -Path $RootFolder -Directory

        foreach ($SubFolder in $SubFolders) {

            Write-Log "обрабатываю папку: $($SubFolder.FullName)"

            $latestFile = Get-ChildItem -Path $SubFolder.FullName -File |
                          Sort-Object LastWriteTime -Descending |
                          Select-Object -First 1

            if (-not $latestFile) {
                Write-Log "нет файлов в папке: $($SubFolder.FullName)"
                continue
            }

            $fileSizeKB = [math]::Round($latestFile.Length / 1KB, 2)
            Write-Log "последний файл: $($latestFile.Name) ($fileSizeKB KB)"

            $remoteFolder = "$RemoteRoot/$($SubFolder.Name)"

            try {
                Get-SFTPChildItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ErrorAction Stop | Out-Null
            } catch {
                New-SFTPItem -SessionId $sftpSession.SessionId -Path $remoteFolder -ItemType Directory | Out-Null
            }

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
