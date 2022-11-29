$TARGET = "$($Env:ARCH)-windows-gnu"
$ZIG_LLVM_CLANG_LLD_NAME = "zig+llvm+lld+clang-$TARGET-0.11.0-dev.25+499dddb4c"
$ZIG_LLVM_CLANG_LLD_URL = "https://ziglang.org/deps/$ZIG_LLVM_CLANG_LLD_NAME.zip"

Write-Output "Downloading $ZIG_LLVM_CLANG_LLD_URL"

Invoke-WebRequest -Uri "$ZIG_LLVM_CLANG_LLD_URL" -OutFile "$ZIG_LLVM_CLANG_LLD_NAME.zip"

Write-Output "Extracting..."

Add-Type -AssemblyName System.IO.Compression.FileSystem ; 
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/$ZIG_LLVM_CLANG_LLD_NAME.zip", "$PWD")

Set-Variable -Name ZIGLIBDIR -Value "$(Get-Location)\lib"
Set-Variable -Name ZIGINSTALLDIR -Value "$(Get-Location)\stage3-release"
Set-Variable -Name ZIGPREFIXPATH -Value "$(Get-Location)\$ZIG_LLVM_CLANG_LLD_NAME"
      
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

Write-Output "::group:: Building Zig..."
& "$ZIGPREFIXPATH\bin\zig.exe" build `
    --prefix "$ZIGINSTALLDIR" `
    --search-prefix "$ZIGPREFIXPATH" `
    --zig-lib-dir "$ZIGLIBDIR" `
    -Denable-stage1 `
    -Dstatic-llvm `
    -Drelease `
    -Duse-zig-libcxx `
    -Dtarget="$TARGET"
CheckLastExitCode
Write-Output "::endgroup::"

Write-Output "::group:: zig build test docs..."
& "$ZIGINSTALLDIR\bin\zig.exe" build test docs `
    --search-prefix "$ZIGPREFIXPATH" `
    -Dstatic-llvm `
    -Dskip-non-native `
    -Denable-symlinks-windows
CheckLastExitCode
Write-Output "::endgroup::"

# Produce the experimental std lib documentation.
Write-Output "::group:: zig test std/std.zig..."
& "$ZIGINSTALLDIR\bin\zig.exe" test "$ZIGLIBDIR\std\std.zig" `
    --zig-lib-dir "$ZIGLIBDIR" `
    -femit-docs `
    -fno-emit-bin
CheckLastExitCode
Write-Output "::endgroup::"