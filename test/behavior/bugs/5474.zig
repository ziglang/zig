const std = @import("std");
const builtin = @import("builtin");

// baseline (control) struct with array of scalar
const Box0 = struct {
    items: [4]Item,

    const Item = struct {
        num: u32,
    };
};

// struct with array of empty struct
const Box1 = struct {
    items: [4]Item,

    const Item = struct {};
};

// struct with array of zero-size struct
const Box2 = struct {
    items: [4]Item,

    const Item = struct {
        nothing: void,
    };
};

fn mutable() !void {
    var box0: Box0 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box0.items[0..])).Pointer.is_const == false);

    var box1: Box1 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box1.items[0..])).Pointer.is_const == false);

    var box2: Box2 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box2.items[0..])).Pointer.is_const == false);
}

fn constant() !void {
    const box0: Box0 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box0.items[0..])).Pointer.is_const == true);

    const box1: Box1 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box1.items[0..])).Pointer.is_const == true);

    const box2: Box2 = .{ .items = undefined };
    try std.testing.expect(@typeInfo(@TypeOf(box2.items[0..])).Pointer.is_const == true);
}

test "pointer-to-array constness for zero-size elements, var" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    try mutable();
    comptime try mutable();
}

test "pointer-to-array constness for zero-size elements, const" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    try constant();
    comptime try constant();
}
