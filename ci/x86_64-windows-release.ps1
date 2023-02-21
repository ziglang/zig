$TARGET = "$($Env:ARCH)-windows-gnu"
$ZIG_LLVM_CLANG_LLD_NAME = "zig+llvm+lld+clang-$TARGET-0.11.0-dev.448+e6e459e9e"
$MCPU = "baseline"
$ZIG_LLVM_CLANG_LLD_URL = "https://ziglang.org/deps/$ZIG_LLVM_CLANG_LLD_NAME.zip"
$PREFIX_PATH = "$(Get-Location)\$ZIG_LLVM_CLANG_LLD_NAME"
$ZIG = "$PREFIX_PATH\bin\zig.exe"
$ZIG_LIB_DIR = "$(Get-Location)\lib"

Write-Output "Downloading $ZIG_LLVM_CLANG_LLD_URL"
Invoke-WebRequest -Uri "$ZIG_LLVM_CLANG_LLD_URL" -OutFile "$ZIG_LLVM_CLANG_LLD_NAME.zip"

Write-Output "Extracting..."
Add-Type -AssemblyName System.IO.Compression.FileSystem ;
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/$ZIG_LLVM_CLANG_LLD_NAME.zip", "$PWD")

function CheckLastExitCode {
    if (!$?) {
        exit 1
    }
    return 0
}

# Make the `zig version` number consistent.
# This will affect the `zig build` command below which uses `git describe`.
git config core.abbrev 9
git fetch --tags

if ((git rev-parse --is-shallow-repository) -eq "true") {
    git fetch --unshallow # `git describe` won't work on a shallow repo
}

Write-Output "Building from source..."
Remove-Item -Path 'build-release' -Recurse -Force -ErrorAction Ignore
New-Item -Path 'build-release' -ItemType Directory
Set-Location -Path 'build-release'

# CMake gives a syntax error when file paths with backward slashes are used.
# Here, we use forward slashes only to work around this.
& cmake .. `
  -GNinja `
  -DCMAKE_INSTALL_PREFIX="stage3-release" `
  -DCMAKE_PREFIX_PATH="$($PREFIX_PATH -Replace "\\", "/")" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_C_COMPILER="$($ZIG -Replace "\\", "/");cc;-target;$TARGET;-mcpu=$MCPU" `
  -DCMAKE_CXX_COMPILER="$($ZIG -Replace "\\", "/");c++;-target;$TARGET;-mcpu=$MCPU" `
  -DZIG_TARGET_TRIPLE="$TARGET" `
  -DZIG_TARGET_MCPU="$MCPU" `
  -DZIG_STATIC=ON
CheckLastExitCode

ninja install
CheckLastExitCode

Write-Output "Main test suite..."
& "stage3-release\bin\zig.exe" build test docs `
  --zig-lib-dir "$ZIG_LIB_DIR" `
  --search-prefix "$PREFIX_PATH" `
  -Dstatic-llvm `
  -Dskip-non-native `
  -Denable-symlinks-windows
CheckLastExitCode

Write-Output "Testing Autodocs..."
& "stage3-release\bin\zig.exe" test "..\lib\std\std.zig" `
  --zig-lib-dir "$ZIG_LIB_DIR" `
  -femit-docs `
  -fno-emit-bin
CheckLastExitCode

Write-Output "Build x86_64-windows-msvc behavior tests using the C backend..."
& "stage3-release\bin\zig.exe" test `
  ..\test\behavior.zig `
  --zig-lib-dir "$ZIG_LIB_DIR" `
  -I..\test `
  -I..\lib `
  -ofmt=c `
  -femit-bin="test-x86_64-windows-msvc.c" `
  --test-no-exec `
  -target x86_64-windows-msvc `
  -lc
CheckLastExitCode

& "stage3-release\bin\zig.exe" build-obj `
  ..\lib\compiler_rt.zig `
  --zig-lib-dir "$ZIG_LIB_DIR" `
  -ofmt=c `
  -OReleaseSmall `
  --name compiler_rt `
  -femit-bin="compiler_rt-x86_64-windows-msvc.c" `
  --mod build_options::config.zig `
  --deps build_options `
  -target x86_64-windows-msvc
CheckLastExitCode

Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
CheckLastExitCode

Enter-VsDevShell -VsInstallPath "C:\Program Files\Microsoft Visual Studio\2022\Enterprise" `
  -DevCmdArguments '-arch=x64 -no_logo' `
  -StartInPath $(Get-Location)
CheckLastExitCode

Write-Output "Build and run behavior tests with msvc..."
& cl.exe -I..\lib test-x86_64-windows-msvc.c compiler_rt-x86_64-windows-msvc.c /W3 /Z7 -link -nologo -debug -subsystem:console kernel32.lib ntdll.lib libcmt.lib
CheckLastExitCode

& .\test-x86_64-windows-msvc.exe
CheckLastExitCode
