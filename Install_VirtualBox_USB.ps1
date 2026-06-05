# ============================================================
#  VirtualBox Portable - Авто-установка на флешку
#  Запускать от имени Администратора!
# ============================================================

param(
    [string]$DriveLetter = ""
)

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   VirtualBox Portable Installer dla USB" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# --- Определяем букву флешки ---
if ($DriveLetter -eq "") {
    Write-Host "Доступные диски:" -ForegroundColor Yellow
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object {
        $size = [math]::Round($_.Used / 1GB + $_.Free / 1GB, 1)
        Write-Host "  [$($_.Name):] - $size GB" -ForegroundColor White
    }
    Write-Host ""
    $DriveLetter = Read-Host "Введите букву вашей флешки (например: E)"
}

$USB = "${DriveLetter}:"
if (-not (Test-Path $USB)) {
    Write-Host "ОШИБКА: Диск $USB не найден!" -ForegroundColor Red
    exit 1
}

# --- FIX: Проверяем свободное место (нужно минимум 10 GB) ---
$drive = Get-PSDrive -Name $DriveLetter -PSProvider FileSystem
$freeGB = [math]::Round($drive.Free / 1GB, 1)
Write-Host "Свободно на $USB $freeGB GB" -ForegroundColor White
if ($freeGB -lt 10) {
    Write-Host "ОШИБКА: Недостаточно места! Нужно минимум 10 GB, доступно $freeGB GB" -ForegroundColor Red
    exit 1
}

Write-Host "Установка на диск: $USB" -ForegroundColor Green
Write-Host ""

# --- Создаём структуру папок ---
$folders = @(
    "$USB\VirtualBox",
    "$USB\VMs\Windows11",
    "$USB\ISO"
)

foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "  [+] Создана папка: $folder" -ForegroundColor Green
    }
}

# --- Скачиваем VirtualBox ---
Write-Host ""
Write-Host "Шаг 1: Скачиваем VirtualBox..." -ForegroundColor Yellow

# FIX: Обновлён до актуальной версии 7.1.6
$vboxVersion = "7.1.6"
$vboxBuild   = "167084"
$vboxUrl     = "https://download.virtualbox.org/virtualbox/$vboxVersion/VirtualBox-$vboxVersion-$vboxBuild-Win.exe"
$vboxInstaller = "$env:TEMP\VirtualBox_installer.exe"

Write-Host "  Загрузка VirtualBox $vboxVersion с virtualbox.org..." -ForegroundColor White
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $vboxUrl -OutFile $vboxInstaller -UseBasicParsing
    Write-Host "  [OK] VirtualBox скачан!" -ForegroundColor Green
} catch {
    Write-Host "  [!] Не удалось скачать автоматически." -ForegroundColor Red
    Write-Host "  Скачайте вручную: https://www.virtualbox.org/wiki/Downloads" -ForegroundColor Yellow
    Write-Host "  И запустите установщик, указав путь: $USB\VirtualBox" -ForegroundColor Yellow
    $vboxInstaller = ""
}

# --- Устанавливаем VirtualBox на флешку ---
if ($vboxInstaller -ne "" -and (Test-Path $vboxInstaller)) {
    Write-Host ""
    Write-Host "Шаг 2: Устанавливаем VirtualBox на флешку..." -ForegroundColor Yellow

    # FIX: Правильные флаги установщика VirtualBox
    # Сначала распаковываем, потом запускаем msiexec с INSTALLDIR
    $extractPath = "$env:TEMP\VBoxExtract"
    Write-Host "  Распаковка установщика..." -ForegroundColor White
    Start-Process -FilePath $vboxInstaller -ArgumentList "--extract --path `"$extractPath`" --silent" -Wait

    # Ищем MSI файл
    $msiFile = Get-ChildItem -Path $extractPath -Filter "VirtualBox*.msi" -Recurse | Select-Object -First 1
    if ($msiFile) {
        Write-Host "  Установка в $USB\VirtualBox..." -ForegroundColor White
        Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/i `"$($msiFile.FullName)`" INSTALLDIR=`"$USB\VirtualBox`" /qn /norestart" `
            -Wait
        Write-Host "  [OK] VirtualBox установлен!" -ForegroundColor Green
    } else {
        Write-Host "  [!] MSI файл не найден. Запустите установщик вручную:" -ForegroundColor Red
        Write-Host "      $vboxInstaller" -ForegroundColor Yellow
    }
}

# --- Создаём конфиг VirtualBox ---
Write-Host ""
Write-Host "Шаг 3: Настраиваем VirtualBox..." -ForegroundColor Yellow

$vboxConfig = @"
<?xml version="1.0"?>
<VirtualBox xmlns="http://www.virtualbox.org/" version="1.12-windows">
  <Global>
    <SystemProperties defaultMachineFolder="${USB}\VMs" />
  </Global>
</VirtualBox>
"@

$configDir = "$USB\VirtualBox\.VirtualBox"
New-Item -ItemType Directory -Path $configDir -Force | Out-Null
$vboxConfig | Out-File -FilePath "$configDir\VirtualBox.xml" -Encoding UTF8
Write-Host "  [OK] Конфиг создан!" -ForegroundColor Green

# --- Создаём скрипт запуска ---
Write-Host ""
Write-Host "Шаг 4: Создаём файл запуска..." -ForegroundColor Yellow

# FIX: убрана кириллица из echo (кодировка ANSI), убран лишний --settingspw
# FIX: VBOX_USER_HOME устанавливается ДО команды start
$startScript = @'
@echo off
title VirtualBox Portable Launcher
color 0B

echo.
echo  =============================================
echo   VirtualBox Portable - USB Launch
echo  =============================================
echo.

set DRIVE=%~d0
set VBOX_DIR=%DRIVE%\VirtualBox
set VBOX_EXE=%VBOX_DIR%\VirtualBox.exe
set VBOX_CONFIG=%DRIVE%\VirtualBox\.VirtualBox

if not exist "%VBOX_EXE%" (
    echo  [ERROR] VirtualBox not found: %VBOX_EXE%
    echo  Please run Install_VirtualBox_USB.ps1 first!
    pause
    exit /b 1
)

echo  Starting VirtualBox...
echo  Path: %VBOX_EXE%
echo.

:: FIX: VBOX_USER_HOME must be set BEFORE launching VirtualBox
set VBOX_USER_HOME=%VBOX_CONFIG%

start "" "%VBOX_EXE%"

echo  VirtualBox launched!
timeout /t 3 >nul
'@

# FIX: сохраняем в ASCII (без кириллицы) чтобы избежать проблем кодировки
$startScript | Out-File -FilePath "$USB\START_VirtualBox.bat" -Encoding ASCII
Write-Host "  [OK] Launch file created: $USB\START_VirtualBox.bat" -ForegroundColor Green

# --- Инструкция ---
$isoInstruction = @"
HOW TO INSTALL WINDOWS 11
==========================

1. Download Windows 11 ISO:
   https://www.microsoft.com/software-download/windows11

2. Copy ISO to:
   $USB\ISO\

3. Launch VirtualBox:
   $USB\START_VirtualBox.bat

4. In VirtualBox click "New":
   - Name: Windows 11
   - Folder: $USB\VMs\
   - Type: Microsoft Windows
   - Version: Windows 11 (64-bit)
   - RAM: 4096 MB minimum
   - Disk: $USB\VMs\Windows11\Win11.vdi (64 GB)

5. VM Settings -> System:
   - Enable EFI
   - Enable TPM 2.0

6. VM Settings -> Storage:
   - Attach ISO from $USB\ISO\

7. Start VM and install Windows 11!
"@

$isoInstruction | Out-File -FilePath "$USB\README_Windows11.txt" -Encoding UTF8
Write-Host "  [OK] Instructions: $USB\README_Windows11.txt" -ForegroundColor Green

# --- Итог ---
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Structure on $USB\" -ForegroundColor White
Write-Host "  |- START_VirtualBox.bat    <- Run this!" -ForegroundColor Yellow
Write-Host "  |- README_Windows11.txt   <- Read this!" -ForegroundColor Yellow
Write-Host "  |- VirtualBox\             <- Program" -ForegroundColor White
Write-Host "  |- VMs\Windows11\          <- Virtual machine" -ForegroundColor White
Write-Host "  |- ISO\                    <- Put Windows 11 ISO here" -ForegroundColor White
Write-Host ""
Write-Host "  Next step:" -ForegroundColor Cyan
Write-Host "  Download Windows 11 ISO from microsoft.com" -ForegroundColor White
Write-Host "  and copy to: $USB\ISO\" -ForegroundColor White
Write-Host ""
pause
