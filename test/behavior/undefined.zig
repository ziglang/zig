const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

fn initStaticArray() [10]i32 {
    var array: [10]i32 = undefined;
    array[0] = 1;
    array[4] = 2;
    array[7] = 3;
    array[9] = 4;
    return array;
}
const static_array = initStaticArray();
test "init static array to undefined" {
    // This test causes `initStaticArray()` to be codegen'd, and the
    // C backend does not yet support returning arrays, so it fails
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(static_array[0] == 1);
    try expect(static_array[4] == 2);
    try expect(static_array[7] == 3);
    try expect(static_array[9] == 4);

    comptime {
        try expect(static_array[0] == 1);
        try expect(static_array[4] == 2);
        try expect(static_array[7] == 3);
        try expect(static_array[9] == 4);
    }
}

const Foo = struct {
    x: i32,

    fn setFooXMethod(foo: *Foo) void {
        foo.x = 3;
    }
};

fn setFooX(foo: *Foo) void {
    foo.x = 2;
}

test "assign undefined to struct" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime {
        var foo: Foo = undefined;
        setFooX(&foo);
        try expect(foo.x == 2);
    }
    {
        var foo: Foo = undefined;
        setFooX(&foo);
        try expect(foo.x == 2);
    }
}

test "assign undefined to struct with method" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime {
        var foo: Foo = undefined;
        foo.setFooXMethod();
        try expect(foo.x == 3);
    }
    {
        var foo: Foo = undefined;
        foo.setFooXMethod();
        try expect(foo.x == 3);
    }
}

test "type name of undefined" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const x = undefined;
    try expect(mem.eql(u8, @typeName(@TypeOf(x)), "@TypeOf(undefined)"));
}

test "undefined propagation in equality operators for bool" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo: bool = undefined;
    const x = foo == undefined;
    try expectEqual(x, @as(bool, undefined));
}

test "undefined propagation in equality operators for pointer" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo: *i32 = undefined;
    const x = foo == undefined;
    try expectEqual(x, @as(bool, undefined));
}

test "undefined propagation in equality operators for optional" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo: ?*i32 = undefined;
    const x = foo == undefined;
    try expectEqual(x, @as(bool, undefined));
}

test "undefined propagation in equality operators for error union" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo: anyerror = undefined;
    const x = foo == @as(anyerror!i32, undefined);
    try expectEqual(x, @as(bool, undefined));
}

test "undefined propagation in equality operators for integers" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var foo: i32 = undefined;
    const x = foo == undefined;
    try expectEqual(x, @as(bool, undefined));
}

test "undefined propagation in equality operators for vectors" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var lhs = @Vector(3, u8){1, 2, undefined};
    var rhs = @Vector(3, u8){undefined, 2, 3};
    try expectEqual(lhs == rhs, @Vector(3, bool){undefined, true, undefined});
}
