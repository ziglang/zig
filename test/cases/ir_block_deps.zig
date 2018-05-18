const assert = @import("std").debug.assert;

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

fn getErrInt() error!i32 {
    return 0;
}

test "ir block deps" {
    assert((foo(1) catch unreachable) == 0);
    assert((foo(2) catch unreachable) == 0);
}
