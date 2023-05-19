const std = @import("std");
const builtin = @import("builtin");

test "registers get overwritten when ignoring return" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.cpu.arch != .x86_64 or builtin.os.tag != .linux) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const fd = open();
    _ = write(fd, "a", 1);
    _ = close(fd);
}

fn open() usize {
    return 42;
}

fn write(fd: usize, a: [*]const u8, len: usize) usize {
    return syscall4(.WRITE, fd, @ptrToInt(a), len);
}

fn syscall4(n: enum { WRITE }, a: usize, b: usize, c: usize) usize {
    _ = n;
    _ = a;
    _ = b;
    _ = c;
    return 23;
}

fn close(fd: usize) usize {
    if (fd != 42)
        unreachable;
    return 0;
}
