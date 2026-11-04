@echo off
chcp 65001 >nul
setlocal

rem ---- config: env vars win, fall back to paths relative to this script ----
if not defined ARENA_HOME        set "ARENA_HOME=%~dp0..\qwen-code"
if not defined ARENA_BRIDGE_DIR  set "ARENA_BRIDGE_DIR=%~dp0..\bridge"
if not defined ARENA_SYSTEM_MD   set "ARENA_SYSTEM_MD=%~dp0..\arena-system.md"
if not defined ARENA_API_KEY     set "ARENA_API_KEY=sk-arena-local"
if not defined ARENA_CWD         set "ARENA_CWD=%USERPROFILE%\arena-cwd"
if not defined ARENA_CHROME      set "ARENA_CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe"
if not defined ARENA_PROFILE     set "ARENA_PROFILE=%~dp0..\profiles\arena"

if not exist "%ARENA_CWD%" mkdir "%ARENA_CWD%"
cd /d "%ARENA_CWD%"

if not defined ARENA_NO_LAUNCH (
  curl.exe -s -m 2 http://127.0.0.1:9222/json/version >nul 2>&1
  if errorlevel 1 (
    if exist "%ARENA_CHROME%" (
      start "" "%ARENA_CHROME%" --remote-debugging-port=9222 --user-data-dir="%ARENA_PROFILE%" --no-first-run --no-default-browser-check
      ping -n 9 127.0.0.1 >nul
    ) else (
      echo [arena] Chrome not found: %ARENA_CHROME%
    )
  )
)

curl.exe -s -m 2 http://127.0.0.1:17892/health >nul 2>&1
if errorlevel 1 (
  if exist "%ARENA_BRIDGE_DIR%\arena_bridge.js" (
    start "" /min cmd /c "cd /d "%ARENA_BRIDGE_DIR%" && node arena_bridge.js >> "%ARENA_BRIDGE_DIR%\bridge.log" 2>&1"
    ping -n 5 127.0.0.1 >nul
  ) else (
    echo [arena] bridge not found: %ARENA_BRIDGE_DIR%\arena_bridge.js
  )
)

node "%ARENA_HOME%\packages\cli\dist\index.js" %*
