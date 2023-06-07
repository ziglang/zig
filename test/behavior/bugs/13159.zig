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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var foo = Bar.Baz.fizz;
    try expect(foo == .fizz);
}
