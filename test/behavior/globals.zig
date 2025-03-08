const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

var pos = [2]f32{ 0.0, 0.0 };
test "store to global array" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(pos[1] == 0.0);
    pos = [2]f32{ 0.0, 1.0 };
    try expect(pos[1] == 1.0);
}

var vpos = @Vector(2, f32){ 0.0, 0.0 };
test "store to global vector" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(vpos[1] == 0.0);
    vpos = @Vector(2, f32){ 0.0, 1.0 };
    try expect(vpos[1] == 1.0);
}

test "slices pointing at the same address as global array." {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const a = [_]u8{ 1, 2, 3 };

        fn checkAddress(s: []const u8) !void {
            for (s, 0..) |*i, j| {
                try expect(i == &a[j]);
            }
        }
    };

    try S.checkAddress(&S.a);
    try comptime S.checkAddress(&S.a);
}

test "global loads can affect liveness" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        const ByRef = struct {
            a: u32,
        };

        var global_ptr: *ByRef = undefined;

        fn f() void {
            global_ptr.* = .{ .a = 42 };
        }
    };

    var x: S.ByRef = .{ .a = 1 };
    S.global_ptr = &x;
    const y = x;
    S.f();
    try std.testing.expect(y.a == 1);
}

test "global const can be self-referential" {
    const S = struct {
        self: *const @This(),
        x: u32,

        const foo: @This() = .{ .self = &foo, .x = 123 };
    };

    try std.testing.expect(S.foo.x == 123);
    try std.testing.expect(S.foo.self.x == 123);
    try std.testing.expect(S.foo.self.self.x == 123);
    try std.testing.expect(S.foo.self == &S.foo);
    try std.testing.expect(S.foo.self.self == &S.foo);
}

test "global var can be self-referential" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        self: *@This(),
        x: u32,

        var foo: @This() = .{ .self = &foo, .x = undefined };
    };

    S.foo.x = 123;

    try std.testing.expect(S.foo.x == 123);
    try std.testing.expect(S.foo.self.x == 123);
    try std.testing.expect(S.foo.self == &S.foo);

    S.foo.self.x = 456;

    try std.testing.expect(S.foo.x == 456);
    try std.testing.expect(S.foo.self.x == 456);
    try std.testing.expect(S.foo.self == &S.foo);

    S.foo.self.self.x = 789;

    try std.testing.expect(S.foo.x == 789);
    try std.testing.expect(S.foo.self.x == 789);
    try std.testing.expect(S.foo.self == &S.foo);
}

test "global const can be indirectly self-referential" {
    const S = struct {
        other: *const @This(),
        x: u32,

        const foo: @This() = .{ .other = &bar, .x = 123 };
        const bar: @This() = .{ .other = &foo, .x = 456 };
    };

    try std.testing.expect(S.foo.x == 123);
    try std.testing.expect(S.foo.other.x == 456);
    try std.testing.expect(S.foo.other.other.x == 123);
    try std.testing.expect(S.foo.other.other.other.x == 456);
    try std.testing.expect(S.foo.other == &S.bar);
    try std.testing.expect(S.foo.other.other == &S.foo);

    try std.testing.expect(S.bar.x == 456);
    try std.testing.expect(S.bar.other.x == 123);
    try std.testing.expect(S.bar.other.other.x == 456);
    try std.testing.expect(S.bar.other.other.other.x == 123);
    try std.testing.expect(S.bar.other == &S.foo);
    try std.testing.expect(S.bar.other.other == &S.bar);
}

test "global var can be indirectly self-referential" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        other: *@This(),
        x: u32,

        var foo: @This() = .{ .other = &bar, .x = undefined };
        var bar: @This() = .{ .other = &foo, .x = undefined };
    };

    S.foo.other.x = 123; // bar.x
    S.foo.other.other.x = 456; // foo.x

    try std.testing.expect(S.foo.x == 456);
    try std.testing.expect(S.foo.other.x == 123);
    try std.testing.expect(S.foo.other.other.x == 456);
    try std.testing.expect(S.foo.other.other.other.x == 123);
    try std.testing.expect(S.foo.other == &S.bar);
    try std.testing.expect(S.foo.other.other == &S.foo);

    S.bar.other.x = 111; // foo.x
    S.bar.other.other.x = 222; // bar.x

    try std.testing.expect(S.bar.x == 222);
    try std.testing.expect(S.bar.other.x == 111);
    try std.testing.expect(S.bar.other.other.x == 222);
    try std.testing.expect(S.bar.other.other.other.x == 111);
    try std.testing.expect(S.bar.other == &S.foo);
    try std.testing.expect(S.bar.other.other == &S.bar);
}
