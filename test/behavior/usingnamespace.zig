const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const A = struct {
    pub const B = bool;
};

const C = struct {
    usingnamespace A;
};

test "basic usingnamespace" {
    try std.testing.expect(C.B == bool);
}

fn Foo(comptime T: type) type {
    return struct {
        usingnamespace T;
    };
}

test "usingnamespace inside a generic struct" {
    const std2 = Foo(std);
    const testing2 = Foo(std.testing);
    try std2.testing.expect(true);
    try testing2.expect(true);
}

usingnamespace struct {
    pub const foo = 42;
};

test "usingnamespace does not redeclare an imported variable" {
    comptime try std.testing.expect(@This().foo == 42);
}

usingnamespace @import("usingnamespace/foo.zig");
test "usingnamespace omits mixing in private functions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(@This().privateFunction());
    try expect(!@This().printText());
}
fn privateFunction() bool {
    return true;
}

test {
    _ = @import("usingnamespace/import_segregation.zig");
}

usingnamespace @import("usingnamespace/a.zig");
test "two files usingnamespace import each other" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(@This().ok());
}

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const AA = struct {
        x: i32,
        fn b(x: i32) @This() {
            return .{ .x = x };
        }
        fn c() type {
            return if (true) struct {
                const expected: i32 = 42;
            } else struct {};
        }
        usingnamespace c();
    };
    const a = AA.b(42);
    try expect(a.x == AA.c().expected);
}

comptime {
    _ = @import("usingnamespace/file_1.zig");
}
