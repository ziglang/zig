const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

const Foo = struct {
    x: u32,
    y: u32,
    z: u32,
};

test "@alignOf(T) before referencing T" {
    comptime assertOrPanic(@alignOf(Foo) != maxInt(usize));
    if (builtin.arch != builtin.Arch.x86_64) {
        return error.SkipZigTest;
    }
    comptime assertOrPanic(@alignOf(Foo) == 4);
}

