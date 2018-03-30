@echo on
cd %APPVEYOR_BUILD_FOLDER%
SET "PREVPATH=%PATH%"
SET "PREVMSYSEM=%MSYSTEM%"

SET "PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%"
SET "MSYSTEM=MINGW64"
SET "APPVEYOR_CACHE_ENTRY_ZIP_ARGS=-m0=Copy"

bash -lc "cd ${APPVEYOR_BUILD_FOLDER} && if [ -s ""llvm+clang-6.0.0-win64-msvc-release.tar.xz"" ]; then echo 'skipping LLVM download'; else wget 'https://s3.amazonaws.com/ziglang.org/deps/llvm%%2bclang-6.0.0-win64-msvc-release.tar.xz'; fi && tar xf llvm+clang-6.0.0-win64-msvc-release.tar.xz" || exit /b


SET "PATH=%PREVPATH%"
SET "MSYSTEM=%PREVMSYSTEM%"
SET "ZIGBUILDDIR=%APPVEYOR_BUILD_FOLDER%\build-msvc-release"
SET "ZIGPREFIXPATH=%APPVEYOR_BUILD_FOLDER%\llvm+clang-6.0.0-win64-msvc-release"

call "C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\SetEnv.cmd" /x64
call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" x86_amd64

mkdir %ZIGBUILDDIR%
cd %ZIGBUILDDIR%
cmake.exe .. -Thost=x64 -G"Visual Studio 14 2015 Win64" "-DCMAKE_INSTALL_PREFIX=%ZIGBUILDDIR%" "-DCMAKE_PREFIX_PATH=%ZIGPREFIXPATH%" -DCMAKE_BUILD_TYPE=Release || exit /b
msbuild /p:Configuration=Release INSTALL.vcxproj || exit /b

bin\zig.exe build --build-file ..\build.zig test || exit /b
