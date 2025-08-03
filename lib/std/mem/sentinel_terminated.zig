const std = @import("../std.zig");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const mem = std.mem;
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

/// Returns the smallest number in a pointer. O(n).
/// `ptr` must have at least one element before a sentinel.
pub fn min(comptime T: type, comptime sentinel: T, ptr: [*:sentinel]const T) T {
    assert(ptr[0] != sentinel);
    var best = ptr[0];
    var i: usize = 1;
    while (ptr[i] != sentinel) : (i += 1) {
        best = @min(best, ptr[i]);
    }
    return best;
}

test min {
    try testing.expectEqual(min(u8, 0, "abcdefg"), 'a');
    try testing.expectEqual(min(u8, 0, "bcdefga"), 'a');
    try testing.expectEqual(min(u8, 0, "a"), 'a');
}

/// Returns the largest number in a pointer. O(n).
/// `ptr` must have at least one element before a sentinel.
pub fn max(comptime T: type, comptime sentinel: T, ptr: [*:sentinel]const T) T {
    assert(ptr[0] != sentinel);
    var best = ptr[0];
    var i: usize = 1;
    while (ptr[i] != sentinel) : (i += 1) {
        best = @max(best, ptr[i]);
    }
    return best;
}

test max {
    try testing.expectEqual(max(u8, 0, "abcdefg"), 'g');
    try testing.expectEqual(max(u8, 0, "gabcdef"), 'g');
    try testing.expectEqual(max(u8, 0, "g"), 'g');
}

/// Compares two pointers of numbers lexicographically. O(n).
pub fn order(comptime T: type, comptime sentinel: T, lhs: [*:sentinel]const T, rhs: [*:sentinel]const T) math.Order {
    var i: usize = 0;
    while (lhs[i] == rhs[i] and lhs[i] != sentinel) : (i += 1) {}
    return math.order(lhs[i], rhs[i]);
}

test order {
    try testing.expect(order(u8, 0, "abcd", "bee") == .lt);
    try testing.expect(order(u8, 0, "abc", "abc") == .eq);
    try testing.expect(order(u8, 0, "abc", "abc0") == .lt);
    try testing.expect(order(u8, 0, "", "") == .eq);
    try testing.expect(order(u8, 0, "", "a") == .lt);

    try testing.expect(order(u16, 1, ([_]u16{ 2, 3, 4, 5, 1 })[0..4 :1].ptr, ([_]u16{ 2, 3, 4, 5, 1 })[0..4 :1].ptr) == .eq);
    try testing.expect(order(u16, 1, ([_]u16{ 2, 3, 4, 1 })[0..3 :1].ptr, ([_]u16{ 2, 3, 4, 5, 1 })[0..4 :1].ptr) == .lt);
    try testing.expect(order(u16, 1, ([_]u16{ 3, 4, 5, 6, 1 })[0..4 :1].ptr, ([_]u16{ 2, 3, 4, 5, 1 })[0..4 :1].ptr) == .gt);
    try testing.expect(order(u16, 1, ([_]u16{1})[0..0 :1].ptr, ([_]u16{1})[0..0 :1].ptr) == .eq);
    try testing.expect(order(u16, 1, ([_]u16{1})[0..0 :1].ptr, ([_]u16{ 2, 1 })[0..1 :1].ptr) == .lt);
}

/// Returns true if lhs < rhs, false otherwise
pub fn lessThan(comptime T: type, comptime sentinel: T, lhs: [*:sentinel]const T, rhs: [*:sentinel]const T) bool {
    return order(T, sentinel, lhs, rhs) == .lt;
}

test lessThan {
    try testing.expect(lessThan(u8, 0, "abcd", "bee"));
    try testing.expect(!lessThan(u8, 0, "abc", "abc"));
    try testing.expect(lessThan(u8, 0, "abc", "abc0"));
    try testing.expect(!lessThan(u8, 0, "", ""));
    try testing.expect(lessThan(u8, 0, "", "a"));
}

/// Takes a sentinel-terminated pointer and iterates over the memory to find the
/// sentinel and determine the length.
/// `[*c]` pointers are assumed to be non-null and 0-terminated.
pub const len = mem.len;

/// Takes a sentinel-terminated pointer and returns a slice, iterating over the
/// memory to find the sentinel and determine the length.
/// Pointer attributes such as const are preserved.
/// `[*c]` pointers are assumed to be non-null and 0-terminated.
pub const span = mem.span;
