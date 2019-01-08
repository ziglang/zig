const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");

test "@bytesToslice on a packed struct" {
    const F = packed struct {
        a: u8,
    };

    var b = [1]u8{9};
    var f = @bytesToSlice(F, b);
    assertOrPanic(f[0].a == 9);
}

