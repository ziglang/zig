$TARGET = "$($Env:ARCH)-windows-gnu"
$ZIG_LLVM_CLANG_LLD_NAME = "zig+llvm+lld+clang-$TARGET-0.11.0-dev.1869+df4cfc2ec"
$MCPU = "baseline"
$ZIG_LLVM_CLANG_LLD_URL = "https://ziglang.org/deps/$ZIG_LLVM_CLANG_LLD_NAME.zip"
$PREFIX_PATH = "$(Get-Location)\..\$ZIG_LLVM_CLANG_LLD_NAME"
$ZIG = "$PREFIX_PATH\bin\zig.exe"
$ZIG_LIB_DIR = "$(Get-Location)\lib"

if (!(Test-Path "..\$ZIG_LLVM_CLANG_LLD_NAME.zip")) {
    Write-Output "Downloading $ZIG_LLVM_CLANG_LLD_URL"
    Invoke-WebRequest -Uri "$ZIG_LLVM_CLANG_LLD_URL" -OutFile "..\$ZIG_LLVM_CLANG_LLD_NAME.zip"

    Write-Output "Extracting..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem ;
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\..\$ZIG_LLVM_CLANG_LLD_NAME.zip", "$PWD\..")
}

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

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
$Env:ZIG_GLOBAL_CACHE_DIR="$(Get-Location)\zig-global-cache"
$Env:ZIG_LOCAL_CACHE_DIR="$(Get-Location)\zig-local-cache"

# CMake gives a syntax error when file paths with backward slashes are used.
# Here, we use forward slashes only to work around this.
& cmake .. `
  -GNinja `
  -DCMAKE_INSTALL_PREFIX="stage3-release" `
  -DCMAKE_PREFIX_PATH="$($PREFIX_PATH -Replace "\\", "/")" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_C_COMPILER="$($ZIG -Replace "\\", "/");cc;-target;$TARGET;-mcpu=$MCPU" `
  -DCMAKE_CXX_COMPILER="$($ZIG -Replace "\\", "/");c++;-target;$TARGET;-mcpu=$MCPU" `
  -DCMAKE_AR="$ZIG" `
  -DZIG_AR_WORKAROUND=ON `
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

