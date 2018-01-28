@echo on
cd %APPVEYOR_BUILD_FOLDER%

build-msvc-release\bin\zig.exe version >version.txt
set /p ZIGVERSION=<version.txt
appveyor UpdateBuild -Version "%ZIGVERSION%"
SET "RELEASEDIR=zig-%ZIGVERSION%"
mkdir "%RELEASEDIR%"
move build-msvc-release\bin\zig.exe "%RELEASEDIR%"
move build-msvc-release\lib "%RELEASEDIR%"
move zig-cache\langref.html "%RELEASEDIR%"

SET "RELEASEZIP=zig-%ZIGVERSION%.zip"

7z a "%RELEASEZIP%" "%RELEASEDIR%"
appveyor PushArtifact "%RELEASEZIP%"
