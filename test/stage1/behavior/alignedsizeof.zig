const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

const Foo = struct {
    w: u32,
    x: u32,
    y: u32,
    z: u24,
};

const FooPacked = packed struct {
    w: u32,
    x: u32,
    y: u32,
    z: u24,
};

test "@alignedSizeOf(T) before referencing T" {
    comptime assert(@alignedSizeOf(Foo) != maxInt(usize));
    if (builtin.arch != builtin.Arch.x86_64) {
        return error.SkipZigTest;
    }

    //Foo type
    comptime assert(@sizeOf(Foo) == 16);
    comptime assert(@alignOf(Foo) == 4);
    comptime assert(@alignedSizeOf(Foo) == 16);

    //FooPacked type
    comptime assert(@sizeOf(FooPacked) == 15);
    comptime assert(@alignOf(FooPacked) == 1);
    comptime assert(@alignedSizeOf(FooPacked) == 15);

    //u24 type
    comptime assert(@sizeOf(u24) == 3);
    comptime assert(@alignOf(u24) == 4);
    comptime assert(@alignedSizeOf(u24) == 4);
}
