const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "decl literal" {
    const S = struct {
        x: u32,
        const foo: @This() = .{ .x = 123 };
    };

    const val: S = .foo;
    try expect(val.x == 123);
}

test "call decl literal" {
    const S = struct {
        x: u32,
        fn init() @This() {
            return .{ .x = 123 };
        }
    };

    const val: S = .init();
    try expect(val.x == 123);
}

test "call decl literal with error union" {
    const S = struct {
        x: u32,
        fn init(err: bool) !@This() {
            if (err) return error.Bad;
            return .{ .x = 123 };
        }
    };

    const val: S = try .init(false);
    try expect(val.x == 123);
}
