const builtin = @import("builtin");

test "bytes" {
    const S = struct {
        a: u32,
        c: [5]u8,
    };

    const U = union {
        s: S,
    };

    const s_1 = S{
        .a = undefined,
        .c = "12345".*, // this caused problems
    };
    _ = s_1;

    var u_2 = U{ .s = s_1 };
    _ = u_2;
}

test "aggregate" {
    const S = struct {
        a: u32,
        c: [5]u8,
    };

    const U = union {
        s: S,
    };

    const c = [5:0]u8{ 1, 2, 3, 4, 5 };
    const s_1 = S{
        .a = undefined,
        .c = c, // this caused problems
    };
    _ = s_1;

    var u_2 = U{ .s = s_1 };
    _ = u_2;
}
