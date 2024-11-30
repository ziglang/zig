const builtin = @import("builtin");
const std = @import("std");

fn _start() callconv(.naked) void {}

comptime {
    @export(&_start, .{ .name = if (builtin.cpu.arch.isMIPS()) "__start" else "_start" });
}

// compile
// backend=stage2,llvm
// target=arm-freestanding,armeb-freestanding,thumb-freestanding,thumbeb-freestanding,aarch64-freestanding,aarch64_be-freestanding,loongarch64-freestanding,mips-freestanding,mipsel-freestanding,mips64-freestanding,mips64el-freestanding,powerpc-freestanding,powerpcle-freestanding,powerpc64-freestanding,powerpc64le-freestanding,riscv32-freestanding,riscv64-freestanding,s390x-freestanding,x86-freestanding,x86_64-freestanding
// pic=true
// output_mode=Exe
