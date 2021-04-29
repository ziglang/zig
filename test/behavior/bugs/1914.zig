const std = @import("std");

const A = struct {
    b_list_pointer: *const []B,
};
const B = struct {
    a_pointer: *const A,
};

const b_list: []B = &[_]B{};
const a = A{ .b_list_pointer = &b_list };

test "segfault bug" {
    const assert = std.debug.assert;
    const obj = B{ .a_pointer = &a };
    assert(obj.a_pointer == &a); // this makes zig crash
}

const A2 = struct {
    pointer: *B,
};

pub const B2 = struct {
    pointer_array: []*A2,
};

var b_value = B2{ .pointer_array = &[_]*A2{} };

test "basic stuff" {
    std.debug.assert(&b_value == &b_value);
}
