const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "optional type" {
    const x: ?bool = true;

    if (x) |y| {
        if (y) {
            // OK
        } else {
            unreachable;
        }
    } else {
        unreachable;
    }

    const next_x: ?i32 = null;

    const z = next_x orelse 1234;

    try expect(z == 1234);

    const final_x: ?i32 = 13;

    const num = final_x orelse unreachable;

    try expect(num == 13);
}

test "test maybe object and get a pointer to the inner value" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var maybe_bool: ?bool = true;

    if (maybe_bool) |*b| {
        b.* = false;
    }

    try expect(maybe_bool.? == false);
}

test "rhs maybe unwrap return" {
    const x: ?bool = true;
    const y = x orelse return;
    _ = y;
}

test "maybe return" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try maybeReturnImpl();
    comptime try maybeReturnImpl();
}

fn maybeReturnImpl() !void {
    try expect(foo(1235).?);
    if (foo(null) != null) unreachable;
    try expect(!foo(1234).?);
}

fn foo(x: ?i32) ?bool {
    const value = x orelse return null;
    return value > 1234;
}

test "test null runtime" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try testTestNullRuntime(null);
}
fn testTestNullRuntime(x: ?i32) !void {
    try expect(x == null);
    try expect(!(x != null));
}

test "optional void" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try optionalVoidImpl();
    comptime try optionalVoidImpl();
}

fn optionalVoidImpl() !void {
    try expect(bar(null) == null);
    try expect(bar({}) != null);
}

fn bar(x: ?void) ?void {
    if (x) |_| {
        return {};
    } else {
        return null;
    }
}

const Empty = struct {};

test "optional struct{}" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    _ = try optionalEmptyStructImpl();
    _ = comptime try optionalEmptyStructImpl();
}

fn optionalEmptyStructImpl() !void {
    try expect(baz(null) == null);
    try expect(baz(Empty{}) != null);
}

fn baz(x: ?Empty) ?Empty {
    if (x) |_| {
        return Empty{};
    } else {
        return null;
    }
}

test "null with default unwrap" {
    const x: i32 = null orelse 1;
    try expect(x == 1);
}

test "optional pointer to 0 bit type null value at runtime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const EmptyStruct = struct {};
    var x: ?*EmptyStruct = null;
    try expect(x == null);
}

test "if var maybe pointer" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(shouldBeAPlus1(Particle{
        .a = 14,
        .b = 1,
        .c = 1,
        .d = 1,
    }) == 15);
}
fn shouldBeAPlus1(p: Particle) u64 {
    var maybe_particle: ?Particle = p;
    if (maybe_particle) |*particle| {
        particle.a += 1;
    }
    if (maybe_particle) |particle| {
        return particle.a;
    }
    return 0;
}
const Particle = struct {
    a: u64,
    b: u64,
    c: u64,
    d: u64,
};

test "null literal outside function" {
    const is_null = here_is_a_null_literal.context == null;
    try expect(is_null);

    const is_non_null = here_is_a_null_literal.context != null;
    try expect(!is_non_null);
}

const SillyStruct = struct {
    context: ?i32,
};

const here_is_a_null_literal = SillyStruct{ .context = null };

test "unwrap optional which is field of global var" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    struct_with_optional.field = null;
    if (struct_with_optional.field) |payload| {
        _ = payload;
        unreachable;
    }
    struct_with_optional.field = 1234;
    if (struct_with_optional.field) |payload| {
        try expect(payload == 1234);
    } else {
        unreachable;
    }
}
const StructWithOptional = struct {
    field: ?i32,
};

var struct_with_optional: StructWithOptional = undefined;

test "optional types" {
    comptime {
        const opt_type_struct = StructWithOptionalType{ .t = u8 };
        try expect(opt_type_struct.t != null and opt_type_struct.t.? == u8);
    }
}

const StructWithOptionalType = struct {
    t: ?type,
};
