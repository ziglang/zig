const expect = @import("std").testing.expect;

test "noinline function call" {
    try expect(@call(.auto, add, .{ 3, 9 }) == 12);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

// test
