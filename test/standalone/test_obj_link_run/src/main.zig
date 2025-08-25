test {
    try std.testing.expect(true);
}

test "equality" {
    try std.testing.expect(one() == 1);
}

test "arithmetic" {
    try std.testing.expect(one() + 2 == 3);
}

fn one() u32 {
    return 1;
}

const std = @import("std");
