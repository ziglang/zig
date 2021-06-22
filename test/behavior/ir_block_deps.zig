const expect = @import("std").testing.expect;

fn foo(id: u64) !i32 {
    return switch (id) {
        1 => getErrInt(),
        2 => {
            const size = try getErrInt();
            _ = size;
            return try getErrInt();
        },
        else => error.ItBroke,
    };
}

fn getErrInt() anyerror!i32 {
    return 0;
}

test "ir block deps" {
    try expect((foo(1) catch unreachable) == 0);
    try expect((foo(2) catch unreachable) == 0);
}
