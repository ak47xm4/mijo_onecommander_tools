@echo off

cd /d %~dp0

xcopy /y scripts\* "%localappdata%\OneCommander\Resources\Scripts\"