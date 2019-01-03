const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");

pub const Info = struct {
    version: u8,
};

pub const diamond_info = Info{ .version = 0 };

test "comptime modification of const struct field" {
    comptime {
        var res = diamond_info;
        res.version = 1;
        assertOrPanic(diamond_info.version == 0);
        assertOrPanic(res.version == 1);
    }
}

test "@bytesToslice on a packed struct" {
    const F = packed struct {
        a: u8,
    };

    var b = [1]u8{9};
    var f = @bytesToSlice(F, b);
    assertOrPanic(f[0].a == 9);
}

