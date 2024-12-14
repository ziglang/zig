const std = @import("std");

// Eventually, this test should be made to work without libc by providing our
// own `__tls_get_addr` implementation. powerpcle-linux should be added to the
// target list here when that happens.
//
// https://github.com/ziglang/zig/issues/20625
pub fn main() void {}

// run
// backend=stage2,llvm
// target=arm-linux,armeb-linux,thumb-linux,thumbeb-linux,aarch64-linux,aarch64_be-linux,loongarch64-linux,mips-linux,mipsel-linux,mips64-linux,mips64el-linux,powerpc-linux,powerpc64-linux,powerpc64le-linux,riscv32-linux,riscv64-linux,s390x-linux,x86-linux,x86_64-linux
// pic=true
// link_libc=true
