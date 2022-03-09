const std = @import("std");
pub fn do() bool {
    inline for (.{"a"}) |_| {
        if (true) return false;
    }
    return true;
}

test "bug" {
    try std.testing.expect(!do());
}
