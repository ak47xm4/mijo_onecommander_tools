@echo off

cd /d %~dp0

xcopy /d /y scripts\* "%localappdata%\OneCommander\Resources\Scripts\"