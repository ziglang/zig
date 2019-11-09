const expect = @import("std").testing.expect;

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
        expect(foo.a == {});
    }
}

test "iterate over a void slice" {
    var j: usize = 0;
    for (times(10)) |_, i| {
        expect(i == j);
        j += 1;
    }
}

fn times(n: usize) []const void {
    return @as([*]void, undefined)[0..n];
}

test "void optional" {
    var x: ?void = {};
    expect(x != null);
}

test "void array as a local variable initializer" {
    var x = [_]void{{}} ** 1004;
    var y = x[0];
}
