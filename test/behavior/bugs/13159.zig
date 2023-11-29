const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

const Bar = packed struct {
    const Baz = enum {
        fizz,
        buzz,
    };
};

test {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo = Bar.Baz.fizz;
    _ = &foo;
    try expect(foo == .fizz);
}
