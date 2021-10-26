const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "params" {
    try expect(testParamsAdd(22, 11) == 33);
}
fn testParamsAdd(a: i32, b: i32) i32 {
    return a + b;
}

test "local variables" {
    testLocVars(2);
}
fn testLocVars(b: i32) void {
    const a: i32 = 1;
    if (a + b != 3) unreachable;
}

test "mutable local variables" {
    var zero: i32 = 0;
    try expect(zero == 0);

    var i = @as(i32, 0);
    while (i != 3) {
        i += 1;
    }
    try expect(i == 3);
}

test "separate block scopes" {
    {
        const no_conflict: i32 = 5;
        try expect(no_conflict == 5);
    }

    const c = x: {
        const no_conflict = @as(i32, 10);
        break :x no_conflict;
    };
    try expect(c == 10);
}

fn @"weird function name"() i32 {
    return 1234;
}
test "weird function name" {
    try expect(@"weird function name"() == 1234);
}

test "assign inline fn to const variable" {
    const a = inlineFn;
    a();
}

inline fn inlineFn() void {}

fn outer(y: u32) fn (u32) u32 {
    const Y = @TypeOf(y);
    const st = struct {
        fn get(z: u32) u32 {
            return z + @sizeOf(Y);
        }
    };
    return st.get;
}

test "return inner function which references comptime variable of outer function" {
    var func = outer(10);
    try expect(func(3) == 7);
}

test "discard the result of a function that returns a struct" {
    const S = struct {
        fn entry() void {
            _ = func();
        }

        fn func() Foo {
            return undefined;
        }

        const Foo = struct {
            a: u64,
            b: u64,
        };
    };
    S.entry();
    comptime S.entry();
}

test "inline function call that calls optional function pointer, return pointer at callsite interacts correctly with callsite return type" {
    const S = struct {
        field: u32,

        fn doTheTest() !void {
            bar2 = actualFn;
            const result = try foo();
            try expect(result.field == 1234);
        }

        const Foo = struct { field: u32 };

        fn foo() !Foo {
            var res: Foo = undefined;
            res.field = bar();
            return res;
        }

        inline fn bar() u32 {
            return bar2.?();
        }

        var bar2: ?fn () u32 = null;

        fn actualFn() u32 {
            return 1234;
        }
    };
    try S.doTheTest();
}
