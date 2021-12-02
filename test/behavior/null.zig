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
    try testTestNullRuntime(null);
}
fn testTestNullRuntime(x: ?i32) !void {
    try expect(x == null);
    try expect(!(x != null));
}

test "optional void" {
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
    const EmptyStruct = struct {};
    var x: ?*EmptyStruct = null;
    try expect(x == null);
}

test "if var maybe pointer" {
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
