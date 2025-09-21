const std = @import("std");

// The self-hosted backends can't handle `.hidden _DYNAMIC` and `.weak _DYNAMIC`
// directives in inline assembly yet, so this test is LLVM only for now.
pub fn main() void {}

// run
// backend=llvm
// target=arm-linux,armeb-linux,thumb-linux,thumbeb-linux,aarch64-linux,aarch64_be-linux,loongarch64-linux,mips-linux,mipsel-linux,mips64-linux,mips64el-linux,powerpc-linux,powerpcle-linux,powerpc64-linux,powerpc64le-linux,riscv32-linux,riscv64-linux,x86-linux,x86_64-linux
// pie=true
