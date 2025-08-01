const std = @import("../std.zig");
const testing = std.testing;

/// Returns true if and only if the pointers have the same length and all elements
/// compare true using equality operator.
pub fn eql(comptime T: type, comptime sentinel: T, a: [*:sentinel]const T, b: [*:sentinel]const T) bool {
    if (a == b) return true;

    var i: usize = 0;
    while (a[i] == b[i]) : (i += 1) {
        if (a[i] == sentinel) return true;
    }
    return false;
}

test eql {
    try testing.expect(eql(u8, 0, "abcd", "abcd"));
    try testing.expect(!eql(u8, 0, "abcdef", "abZdef"));
    try testing.expect(!eql(u8, 0, "abcdefg", "abcdef"));

    try testing.expect(eql(u16, 1, ([5]u16{ 5, 6, 7, 8, 1 })[0..4 :1].ptr, ([5]u16{ 5, 6, 7, 8, 1 })[0..4 :1].ptr));
    try testing.expect(!eql(u16, 1, ([7]u16{ 5, 6, 7, 8, 9, 10, 1 })[0..6 :1].ptr, ([7]u16{ 5, 6, 17, 8, 9, 10, 1 })[0..6 :1].ptr));
    try testing.expect(!eql(u16, 1, ([8]u16{ 5, 6, 7, 8, 9, 10, 11, 1 })[0..7 :1].ptr, ([7]u16{ 5, 6, 7, 8, 9, 10, 1 })[0..6 :1].ptr));
}

/// Returns true if and only if the pointer and slice have the same length and all elements
/// compare true using equality operator.
pub fn eqlSlice(comptime T: type, comptime sentinel: T, a: [*:sentinel]const T, b: []const T) bool {
    for (b, 0..) |b_elem, i| {
        if (a[i] == sentinel or a[i] != b_elem) return false;
    }
    return a[b.len] == sentinel;
}

test eqlSlice {
    try testing.expect(eqlSlice(u8, 0, "abcd", "abcd"));
    try testing.expect(!eqlSlice(u8, 0, "abcdef", "abZdef"));
    try testing.expect(!eqlSlice(u8, 0, "abcdefg", "abcdef"));

    try testing.expect(eqlSlice(u16, 1, ([5]u16{ 5, 6, 7, 8, 1 })[0..4 :1].ptr, &[4]u16{ 5, 6, 7, 8 }));
    try testing.expect(!eqlSlice(u16, 1, ([7]u16{ 5, 6, 7, 8, 9, 10, 1 })[0..6 :1].ptr, &[6]u16{ 5, 6, 17, 8, 9, 10 }));
    try testing.expect(!eqlSlice(u16, 1, ([8]u16{ 5, 6, 7, 8, 9, 10, 11, 1 })[0..7 :1].ptr, &[6]u16{ 5, 6, 7, 8, 9, 10 }));
}

/// Returns true if all elements in the pointer are equal to the scalar value provided
pub fn allEqual(comptime T: type, comptime sentinel: T, ptr: [*:sentinel]const T, scalar: T) bool {
    var i: usize = 0;
    while (ptr[i] != sentinel) : (i += 1) {
        if (ptr[i] != scalar) return false;
    }
    return true;
}

test allEqual {
    try testing.expect(allEqual(u8, 0, "aaaa", 'a'));
    try testing.expect(!allEqual(u8, 0, "abaa", 'a'));
    try testing.expect(allEqual(u8, 0, "", 'a'));
}
