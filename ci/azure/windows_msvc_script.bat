@echo on
SET "SRCROOT=%cd%"
SET "PREVPATH=%PATH%"
SET "PREVMSYSEM=%MSYSTEM%"

set "PATH=%CD:~0,2%\msys64\usr\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem"
SET "MSYSTEM=MINGW64"
bash -lc "cd ${SRCROOT} && ci/azure/windows_msvc_install" || exit /b
SET "PATH=%PREVPATH%"
SET "MSYSTEM=%PREVMSYSTEM%"

SET "ZIGBUILDDIR=%SRCROOT%\build"
SET "ZIGINSTALLDIR=%ZIGBUILDDIR%\dist"
SET "ZIGPREFIXPATH=%SRCROOT%\llvm+clang+lld-12.0.0-x86_64-windows-msvc-release-mt"

call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64

REM Make the `zig version` number consistent.
REM This will affect the cmake command below.
git.exe config core.abbrev 9
git.exe fetch --unshallow
git.exe fetch --tags

mkdir %ZIGBUILDDIR%
cd %ZIGBUILDDIR%
cmake.exe .. -Thost=x64 -G"Visual Studio 16 2019" -A x64 "-DCMAKE_INSTALL_PREFIX=%ZIGINSTALLDIR%" "-DCMAKE_PREFIX_PATH=%ZIGPREFIXPATH%" -DCMAKE_BUILD_TYPE=Release -DZIG_OMIT_STAGE2=ON || exit /b
msbuild /maxcpucount /p:Configuration=Release INSTALL.vcxproj || exit /b

"%ZIGINSTALLDIR%\bin\zig.exe" build test-toolchain -Dskip-non-native -Dskip-stage2-tests || exit /b
"%ZIGINSTALLDIR%\bin\zig.exe" build test-std -Dskip-non-native || exit /b
"%ZIGINSTALLDIR%\bin\zig.exe" build docs || exit /b

set "PATH=%CD:~0,2%\msys64\usr\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem"
SET "MSYSTEM=MINGW64"
bash -lc "cd ${SRCROOT} && ci/azure/windows_upload" || exit /b
