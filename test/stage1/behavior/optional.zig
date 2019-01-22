const assertOrPanic = @import("std").debug.assertOrPanic;

pub const EmptyStruct = struct {};

test "optional pointer to size zero struct" {
    var e = EmptyStruct{};
    var o: ?*EmptyStruct = &e;
    assertOrPanic(o != null);
}

test "equality compare nullable pointers" {
    testNullPtrsEql();
    comptime testNullPtrsEql();
}

fn testNullPtrsEql() void {
    var number: i32 = 1234;

    var x: ?*i32 = null;
    var y: ?*i32 = null;
    assertOrPanic(x == y);
    y = &number;
    assertOrPanic(x != y);
    assertOrPanic(x != &number);
    assertOrPanic(&number != x);
    x = &number;
    assertOrPanic(x == y);
    assertOrPanic(x == &number);
    assertOrPanic(&number == x);
}

test "address of unwrap optional" {
    const S = struct {
        const Foo = struct {
            a: i32,
        };

        var global: ?Foo = null;

        pub fn getFoo() anyerror!*Foo {
            return &global.?;
        }
    };
    S.global = S.Foo{ .a = 1234 };
    const foo = S.getFoo() catch unreachable;
    assertOrPanic(foo.a == 1234);
}

test "passing an optional integer as a parameter" {
    const S = struct {
        fn entry() bool {
            var x: i32 = 1234;
            return foo(x);
        }

        fn foo(x: ?i32) bool {
            return x.? == 1234;
        }
    };
    assertOrPanic(S.entry());
    comptime assertOrPanic(S.entry());
}
