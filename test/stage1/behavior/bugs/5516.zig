const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

test "single-item ptr to slice" {
    var x: u32 = 1;
    const single_item_array: *[1]u32 = &x;
    const slice1: []u32 = single_item_array;
    const slice2: []u32 = @as(*[1]u32, &x);
    expect(mem.eql(u32, slice1, slice2));
    const slice3 = @as([]u32, &x);
    expect(mem.eql(u32, slice2, slice3));
}
