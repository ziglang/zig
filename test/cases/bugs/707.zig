const assert = @import("std").debug.assert;

test "while loop with comptime true condition needs no `else` block to return value with break" {
    const x = while (true) {
        break @as(u32, 69);
    };
    assert(x == 69);
}

// run
// is_test=1
// backend=stage2
