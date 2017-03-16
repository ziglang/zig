const assert = @import("std").debug.assert;

type int = u8;

fn add(a: int, b: int) -> int {
    a + b
}
test "typedef" {
    assert(add(12, 34) == 46);
}
