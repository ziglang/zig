const assert = @import("std").debug.assert;

fn foo(id: u64) -> %i32 {
    return switch (id) {
        1 => getErrInt(),
        2 => {
            const size = %return getErrInt();
            return %return getErrInt();
        },
        else => error.ItBroke,
    }
}

fn getErrInt() -> %i32 { 0 }

error ItBroke;

test "irBlockDeps" {
    assert(%%foo(1) == 0);
    assert(%%foo(2) == 0);
}
