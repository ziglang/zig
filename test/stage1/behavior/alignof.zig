const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

const Foo = struct {
    x: u32,
    y: u32,
    z: u32,
};

test "@alignOf(T) before referencing T" {
    comptime expect(@alignOf(Foo) != maxInt(usize));
    if (builtin.arch == builtin.Arch.x86_64) {
        comptime expect(@alignOf(Foo) == 4);
    }
}

test "comparison of @alignOf(T) against zero" {
    {
        const T = struct { x: u32 };
        expect(!(@alignOf(T) == 0));
        expect(@alignOf(T) != 0);
        expect(!(@alignOf(T) < 0));
        expect(!(@alignOf(T) <= 0));
        expect(@alignOf(T) > 0);
        expect(@alignOf(T) >= 0);
    }
    {
        const T = struct {};
        expect(@alignOf(T) == 0);
        expect(!(@alignOf(T) != 0));
        expect(!(@alignOf(T) < 0));
        expect(@alignOf(T) <= 0);
        expect(!(@alignOf(T) > 0));
        expect(@alignOf(T) >= 0);
    }
}
