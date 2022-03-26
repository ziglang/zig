const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "super basic invocations" {
    const foo = struct {
        fn foo() i32 {
            return 1234;
        }
    }.foo;
    try expect(@call(.{}, foo, .{}) == 1234);
    comptime try expect(@call(.{ .modifier = .always_inline }, foo, .{}) == 1234);
    {
        // comptime call without comptime keyword
        const result = @call(.{ .modifier = .compile_time }, foo, .{}) == 1234;
        comptime try expect(result);
    }
}

test "basic invocations" {
    if (builtin.zig_backend != .stage1) return error.SkipZigTest; // TODO

    const foo = struct {
        fn foo() i32 {
            return 1234;
        }
    }.foo;
    try expect(@call(.{}, foo, .{}) == 1234);
    comptime {
        // modifiers that allow comptime calls
        try expect(@call(.{}, foo, .{}) == 1234);
        try expect(@call(.{ .modifier = .no_async }, foo, .{}) == 1234);
        try expect(@call(.{ .modifier = .always_tail }, foo, .{}) == 1234);
        try expect(@call(.{ .modifier = .always_inline }, foo, .{}) == 1234);
    }
    {
        // comptime call without comptime keyword
        const result = @call(.{ .modifier = .compile_time }, foo, .{}) == 1234;
        comptime try expect(result);
    }
    {
        // call of non comptime-known function
        var alias_foo = foo;
        try expect(@call(.{ .modifier = .no_async }, alias_foo, .{}) == 1234);
        try expect(@call(.{ .modifier = .never_tail }, alias_foo, .{}) == 1234);
        try expect(@call(.{ .modifier = .never_inline }, alias_foo, .{}) == 1234);
    }
}

test "tuple parameters" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const add = struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add;
    var a: i32 = 12;
    var b: i32 = 34;
    try expect(@call(.{}, add, .{ a, 34 }) == 46);
    try expect(@call(.{}, add, .{ 12, b }) == 46);
    try expect(@call(.{}, add, .{ a, b }) == 46);
    try expect(@call(.{}, add, .{ 12, 34 }) == 46);
    if (builtin.zig_backend == .stage1) comptime try expect(@call(.{}, add, .{ 12, 34 }) == 46); // TODO
    try expect(comptime @call(.{}, add, .{ 12, 34 }) == 46);
    {
        const separate_args0 = .{ a, b };
        const separate_args1 = .{ a, 34 };
        const separate_args2 = .{ 12, 34 };
        const separate_args3 = .{ 12, b };
        try expect(@call(.{ .modifier = .always_inline }, add, separate_args0) == 46);
        try expect(@call(.{ .modifier = .always_inline }, add, separate_args1) == 46);
        try expect(@call(.{ .modifier = .always_inline }, add, separate_args2) == 46);
        try expect(@call(.{ .modifier = .always_inline }, add, separate_args3) == 46);
    }
}

test "comptime call with bound function as parameter" {
    if (builtin.zig_backend != .stage1) return error.SkipZigTest; // TODO

    const S = struct {
        fn ReturnType(func: anytype) type {
            return switch (@typeInfo(@TypeOf(func))) {
                .BoundFn => |info| info,
                else => unreachable,
            }.return_type orelse void;
        }

        fn call_me_maybe() ?i32 {
            return 123;
        }
    };

    var inst: S = undefined;
    try expectEqual(?i32, S.ReturnType(inst.call_me_maybe));
}

test "result location of function call argument through runtime condition and struct init" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const E = enum { a, b };
    const S = struct {
        e: E,
    };
    const namespace = struct {
        fn foo(s: S) !void {
            try expect(s.e == .b);
        }
    };
    var runtime = true;
    try namespace.foo(.{
        .e = if (!runtime) .a else .b,
    });
}
