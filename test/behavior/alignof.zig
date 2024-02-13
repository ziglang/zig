const std = @import("std");
const assert = std.debug.assert;
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
    comptime assert(@alignOf(Foo) != maxInt(usize));
    if (native_arch == .x86_64) {
        comptime assert(@alignOf(Foo) == 4);
    }
}

test "comparison of @alignOf(T) against zero" {
    const T = struct { x: u32 };
    try expect(!(@alignOf(T) == 0));
    try expect(@alignOf(T) != 0);
    try expect(!(@alignOf(T) < 0));
    try expect(!(@alignOf(T) <= 0));
    try expect(@alignOf(T) > 0);
    try expect(@alignOf(T) >= 0);
}

test "correct alignment for elements and slices of aligned array" {
    var buf: [1024]u8 align(64) = undefined;
    var start: usize = 1;
    var end: usize = undefined;
    _ = .{ &start, &end };
    try expect(@alignOf(@TypeOf(buf[start..end])) == @alignOf(*u8));
    try expect(@alignOf(@TypeOf(&buf[start..end])) == @alignOf(*u8));
    try expect(@alignOf(@TypeOf(&buf[start])) == @alignOf(*u8));
}
