@echo on
SET "SRCROOT=%cd%"
SET "PREVPATH=%PATH%"
SET "PREVMSYSEM=%MSYSTEM%"

set "PATH=%CD:~0,2%\msys64\usr\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem"
SET "MSYSTEM=MINGW64"
bash -lc "cd ${SRCROOT} && ci/azure/windows_install" || exit /b
SET "PATH=%PREVPATH%"
SET "MSYSTEM=%PREVMSYSTEM%"

SET "ZIGBUILDDIR=%SRCROOT%\build"
SET "ZIGINSTALLDIR=%ZIGBUILDDIR%\dist"
SET "ZIGPREFIXPATH=%SRCROOT%\llvm+clang-9.0.0-win64-msvc-release"

call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64

mkdir %ZIGBUILDDIR%
cd %ZIGBUILDDIR%
REM Here we use MinSizeRel instead of Release to work around https://github.com/ziglang/zig/issues/3024
cmake.exe .. -Thost=x64 -G"Visual Studio 16 2019" -A x64 "-DCMAKE_INSTALL_PREFIX=%ZIGINSTALLDIR%" "-DCMAKE_PREFIX_PATH=%ZIGPREFIXPATH%" -DCMAKE_BUILD_TYPE=MinSizeRel || exit /b
msbuild /p:Configuration=MinSizeRel INSTALL.vcxproj || exit /b

"%ZIGINSTALLDIR%\bin\zig.exe" build test || exit /b

set "PATH=%CD:~0,2%\msys64\usr\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem"
SET "MSYSTEM=MINGW64"
bash -lc "cd ${SRCROOT} && ci/azure/windows_upload" || exit /b
