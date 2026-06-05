@echo off
title VirtualBox USB - Установка и Запуск
color 0B
chcp 65001 >nul

echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║   VirtualBox Portable - Установщик на флешку    ║
echo  ╚══════════════════════════════════════════════════╝
echo.
echo  Этот скрипт установит VirtualBox прямо на флешку.
echo.

:: Проверяем права администратора
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] Нужны права Администратора!
    echo  Кликните правой кнопкой -> "Запуск от имени администратора"
    echo.
    pause
    exit /b 1
)

echo  [OK] Права администратора - есть
echo.

:: Запускаем PowerShell скрипт
echo  Запускаем установщик...
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0Install_VirtualBox_USB.ps1"

if %errorLevel% neq 0 (
    echo.
    echo  [!] Ошибка при запуске PowerShell скрипта.
    echo  Попробуйте запустить вручную:
    echo  PowerShell -> правая кнопка -> Запуск от администратора
    echo  Затем: Set-ExecutionPolicy Bypass -Scope Process
    echo  Затем: .\Install_VirtualBox_USB.ps1
    pause
)
