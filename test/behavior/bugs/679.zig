const std = @import("std");
const expect = std.testing.expect;

pub fn List(comptime T: type) type {
    _ = T;
    return u32;
}

const ElementList = List(Element);
const Element = struct {
    link: ElementList,
};

test "false dependency loop in struct definition" {
    const listType = ElementList;
    var x: listType = 42;
    _ = &x;
    try expect(x == 42);
}
