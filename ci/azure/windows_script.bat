@echo on
SET "SRCROOT=%cd%"
SET "PREVPATH=%PATH%"
SET "PREVMSYSEM=%MSYSTEM%"

set "PATH=%CD:~0,2%\msys64\usr\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem"
SET "MSYSTEM=MINGW64"
bash -lc "cd ${SRCROOT} && ci/azure/windows_script" || exit /b
