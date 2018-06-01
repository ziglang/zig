const assert = @import("std").debug.assert;

const A = struct {
    b: B,
};

const B = struct {
    c: C,
};

const C = struct {
    x: i32,

    fn d(c: *const C) i32 {
        return c.x;
    }
};

fn foo(a: *const A) i32 {
    return a.b.c.d();
}

test "incomplete struct param top level declaration" {
    const a = A{
        .b = B{
            .c = C{ .x = 13 },
        },
    };
    assert(foo(a) == 13);
}
