const builtin = @import("builtin");
const expect = @import("std").testing.expect;

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

fn foo(a: A) i32 {
    return a.b.c.d();
}

test "incomplete struct param top level declaration" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a = A{
        .b = B{
            .c = C{ .x = 13 },
        },
    };
    try expect(foo(a) == 13);
}
