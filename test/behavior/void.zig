const expect = @import("std").testing.expect;
const builtin = @import("builtin");

const Foo = struct {
    a: void,
    b: i32,
    c: void,
};

test "compare void with void compile time known" {
    comptime {
        const foo = Foo{
            .a = {},
            .b = 1,
            .c = {},
        };
        try expect(foo.a == {});
    }
}

test "iterate over a void slice" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var j: usize = 0;
    for (times(10), 0..) |_, i| {
        try expect(i == j);
        j += 1;
    }
}

fn times(n: usize) []const void {
    return @as([*]void, undefined)[0..n];
}

test "void optional" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: ?void = {};
    _ = &x;
    try expect(x != null);
}

test "void array as a local variable initializer" {
    var x = [_]void{{}} ** 1004;
    _ = &x[0];
    _ = x[0];
}

const void_constant = {};
test "reference to void constants" {
    var a = void_constant;
    _ = &a;
}

// See issue #23307
const Bar = extern struct {
    a: u8,
    b: u8,
    c: void,
};

test "store void in extern struct through a pointer at compile-time" {
    comptime {
        var x: Bar = undefined;
        const y = &x;
        y.* = Bar{
            .a = 0,
            .b = 1,
            .c = {},
        };
    }
}

test "store void in extern struct inside an array at compile-time" {
    comptime {
        var x: [5]Bar = undefined;

        for (&x) |*y| y.* = .{
            .a = 0,
            .b = 1,
            .c = {},
        };
    }
}

const PackedBar = packed struct(u8) { a: u8, b: void };

test "store void in packed struct through a pointer at compile-time" {
    comptime {
        var x: PackedBar = undefined;
        const y = &x;
        y.* = PackedBar{
            .a = 0,
            .b = {},
        };
    }
}

test "store void in packed struct inside an array at compile-time" {
    comptime {
        var x: [5]PackedBar = undefined;

        for (&x) |*y| y.* = .{
            .a = 0,
            .b = {},
        };
    }
}
