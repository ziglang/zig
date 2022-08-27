const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");
const native_arch = builtin.target.cpu.arch;
const maxInt = std.math.maxInt;

const Foo = struct {
    x: u32,
    y: u32,
    z: u32,
};

test "@alignOf(T) before referencing T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    comptime try expect(@alignOf(Foo) != maxInt(usize));
    if (native_arch == .x86_64) {
        comptime try expect(@alignOf(Foo) == 4);
    }
}

test "comparison of @alignOf(T) against zero" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    {
        const T = struct { x: u32 };
        try expect(!(@alignOf(T) == 0));
        try expect(@alignOf(T) != 0);
        try expect(!(@alignOf(T) < 0));
        try expect(!(@alignOf(T) <= 0));
        try expect(@alignOf(T) > 0);
        try expect(@alignOf(T) >= 0);
    }
    {
        const T = struct {};
        try expect(@alignOf(T) == 0);
        try expect(!(@alignOf(T) != 0));
        try expect(!(@alignOf(T) < 0));
        try expect(@alignOf(T) <= 0);
        try expect(!(@alignOf(T) > 0));
        try expect(@alignOf(T) >= 0);
    }
}
