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

var buf: []u8 = undefined;

test "reslice of undefined global var slice" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var stack_buf: [100]u8 = [_]u8{0} ** 100;
    buf = &stack_buf;
    const x = buf[0..1];
    try @import("std").testing.expect(x.len == 1 and x[0] == 0);
}

test "returned undef is 0xaa bytes when runtime safety is enabled" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const Rect = struct {
        x: f32,
        fn getUndefStruct() @This() {
            @setRuntimeSafety(true);
            return undefined;
        }
        fn getUndefInt() u32 {
            @setRuntimeSafety(true);
            return undefined;
        }
    };
    try std.testing.expect(@as(u32, @bitCast(Rect.getUndefStruct().x)) == 0xAAAAAAAA);
    try std.testing.expect(Rect.getUndefInt() == 0xAAAAAAAA);
}
