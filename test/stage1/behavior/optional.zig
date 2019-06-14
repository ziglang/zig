const expect = @import("std").testing.expect;

pub const EmptyStruct = struct {};

//test "optional pointer to size zero struct" {
//    var e = EmptyStruct{};
//    var o: ?*EmptyStruct = &e;
//    expect(o != null);
//}

test "equality compare nullable pointers" {
    testNullPtrsEql();
    comptime testNullPtrsEql();
}

fn testNullPtrsEql() void {
    var number: i32 = 1234;

    var x: ?*i32 = null;
    var y: ?*i32 = null;
    expect(x == y);
    y = &number;
    expect(x != y);
    expect(x != &number);
    expect(&number != x);
    x = &number;
    expect(x == y);
    expect(x == &number);
    expect(&number == x);
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
    expect(foo.a == 1234);
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
    expect(S.entry());
    comptime expect(S.entry());
}

test "unwrap function call with optional pointer return value" {
    const S = struct {
        fn entry() void {
            expect(foo().?.* == 1234);
            expect(bar() == null);
        }
        const global: i32 = 1234;
        fn foo() ?*const i32 {
            return &global;
        }
        fn bar() ?*i32 {
            return null;
        }
    };
    S.entry();
    // TODO https://github.com/ziglang/zig/issues/1901
    //comptime S.entry();
}
