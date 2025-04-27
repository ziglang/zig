$TARGET = "$($Env:ARCH)-windows-gnu"
$ZIG_LLVM_CLANG_LLD_NAME = "zig+llvm+lld+clang-$TARGET-0.15.0-dev.233+7c85dc460"
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
git fetch --tags

if ((git rev-parse --is-shallow-repository) -eq "true") {
    git fetch --unshallow # `git describe` won't work on a shallow repo
}

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
$Env:ZIG_GLOBAL_CACHE_DIR="$(Get-Location)\zig-global-cache"
$Env:ZIG_LOCAL_CACHE_DIR="$(Get-Location)\zig-local-cache"

Write-Output "Building from source..."
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
  -DCMAKE_AR="$ZIG" `
  -DZIG_AR_WORKAROUND=ON `
  -DZIG_TARGET_TRIPLE="$TARGET" `
  -DZIG_TARGET_MCPU="$MCPU" `
  -DZIG_STATIC=ON `
  -DZIG_NO_LIB=ON
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

# Ensure that stage3 and stage4 are byte-for-byte identical.
Write-Output "Build and compare stage4..."
& "stage3-release\bin\zig.exe" build `
  --prefix stage4-release `
  -Denable-llvm `
  -Dno-lib `
  -Doptimize=ReleaseFast `
  -Dstrip `
  -Dtarget="$TARGET" `
  -Duse-zig-libcxx `
  -Dversion-string="$(stage3-release\bin\zig version)"
CheckLastExitCode

# Compare-Object returns an error code if the files differ.
Write-Output "If the following command fails, it means nondeterminism has been"
Write-Output "introduced, making stage3 and stage4 no longer byte-for-byte identical."
Compare-Object (Get-Content stage3-release\bin\zig.exe) (Get-Content stage4-release\bin\zig.exe)
CheckLastExitCode
