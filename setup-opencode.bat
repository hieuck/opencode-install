@echo off
chcp 65001 >nul
title Cài đặt & Cấu hình OpenCode Full Suite
echo ========================================================
echo   OPENCODE FULL SUITE INSTALLER
echo   (OpenCode CLI + Desktop + Superpowers + ECC + CodeGraph + Karpathy + Goal)
echo ========================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-opencode.ps1" %*
echo.
pause