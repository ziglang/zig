@echo on
cd %APPVEYOR_BUILD_FOLDER%
SET "PREVPATH=%PATH%"
SET "PREVMSYSEM=%MSYSTEM%"

SET "PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%"
SET "MSYSTEM=MINGW64"
SET "APPVEYOR_CACHE_ENTRY_ZIP_ARGS=-m0=Copy"

bash -lc "cd ${APPVEYOR_BUILD_FOLDER} && if [ -s ""llvm+clang-6.0.0-win64-msvc-release.tar.xz"" ]; then echo 'skipping LLVM download'; else wget 'https://s3.amazonaws.com/superjoe/temp/llvm%%2bclang-6.0.0-win64-msvc-release.tar.xz'; fi && tar xf llvm+clang-6.0.0-win64-msvc-release.tar.xz" || exit /b


SET "PATH=%PREVPATH%"
SET "MSYSTEM=%PREVMSYSTEM%"
SET "ZIGBUILDDIR=%APPVEYOR_BUILD_FOLDER%\build-msvc-release"
SET "ZIGPREFIXPATH=%APPVEYOR_BUILD_FOLDER%\llvm+clang-6.0.0-win64-msvc-release"

mkdir %ZIGBUILDDIR%
cd %ZIGBUILDDIR%
cmake.exe .. -Thost=x64 -G"Visual Studio 14 2015 Win64" "-DCMAKE_INSTALL_PREFIX=%ZIGBUILDDIR%" "-DCMAKE_PREFIX_PATH=%ZIGPREFIXPATH%" -DCMAKE_BUILD_TYPE=Release "-DZIG_LIBC_INCLUDE_DIR=C:\Program Files (x86)\Windows Kits\10\Include\10.0.10240.0\ucrt" "-DZIG_LIBC_LIB_DIR=C:\Program Files (x86)\Windows Kits\10\bin\x64\ucrt" "-DZIG_LIBC_STATIC_LIB_DIR=C:\Program Files (x86)\Windows Kits\10\Lib\10.0.10240.0\ucrt\x64" || exit /b
msbuild /p:Configuration=Release INSTALL.vcxproj || exit /b

bin\zig.exe build --build-file ..\build.zig test || exit /b

@echo "MSVC build succeeded, proceeding with MinGW build"
cd %APPVEYOR_BUILD_FOLDER%
SET "PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%"
SET "MSYSTEM=MINGW64"

bash -lc "pacman -Syu --needed --noconfirm"
bash -lc "pacman -Su --needed --noconfirm"

bash -lc "pacman -S --needed --noconfirm make mingw64/mingw-w64-x86_64-make mingw64/mingw-w64-x86_64-cmake mingw64/mingw-w64-x86_64-clang mingw64/mingw-w64-x86_64-llvm mingw64/mingw-w64-x86_64-lld mingw64/mingw-w64-x86_64-gcc"

bash -lc "cd ${APPVEYOR_BUILD_FOLDER} && mkdir build && cd build && cmake .. -G""MSYS Makefiles"" -DCMAKE_INSTALL_PREFIX=$(pwd) -DZIG_LIBC_LIB_DIR=$(dirname $(cc -print-file-name=crt1.o)) -DZIG_LIBC_INCLUDE_DIR=$(echo -n | cc -E -x c - -v 2>&1 | grep -B1 ""End of search list."" | head -n1 | cut -c 2- | sed ""s/ .*//"") -DZIG_LIBC_STATIC_LIB_DIR=$(dirname $(cc -print-file-name=crtbegin.o)) && make && make install"

@echo "MinGW build successful"
