const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

test "cast *[1][*]const u8 to [*]const ?[*]const u8" {
    const window_name = [1][*]const u8{"window name"};
    const x: [*]const ?[*]const u8 = &window_name;
    try expect(mem.eql(u8, std.mem.sliceTo(@as([*:0]const u8, @ptrCast(x[0].?)), 0), "window name"));
}

// test
