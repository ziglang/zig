const expect = @import("std").testing.expect;

const Foo = struct {
    a: u64 = 10,

    fn one(self: Foo) u64 {
        return self.a + 1;
    }

    const two = __two;

    fn __two(self: Foo) u64 {
        return self.a + 2;
    }

    const three = __three;

    const four = custom(Foo, 4);
};

fn __three(self: Foo) u64 {
    return self.a + 3;
}

fn custom(comptime T: type, comptime num: u64) fn (T) u64 {
    return struct {
        fn function(self: T) u64 {
            return self.a + num;
        }
    }.function;
}

test "fn delegation" {
    const foo = Foo{};
    expect(foo.one() == 11);
    expect(foo.two() == 12);
    expect(foo.three() == 13);
    expect(foo.four() == 14);
}
