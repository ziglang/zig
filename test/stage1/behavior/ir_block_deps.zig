const assertOrPanic = @import("std").debug.assertOrPanic;

fn foo(id: u64) !i32 {
    return switch (id) {
        1 => getErrInt(),
        2 => {
            const size = try getErrInt();
            return try getErrInt();
        },
        else => error.ItBroke,
    };
}

fn getErrInt() anyerror!i32 {
    return 0;
}

test "ir block deps" {
    assertOrPanic((foo(1) catch unreachable) == 0);
    assertOrPanic((foo(2) catch unreachable) == 0);
}
