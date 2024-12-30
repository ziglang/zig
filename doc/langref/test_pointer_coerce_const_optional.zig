const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

test "cast *[1][*:0]const u8 to []const ?[*:0]const u8" {
    const window_name = [1][*:0]const u8{"window name"};
    const x: []const ?[*:0]const u8 = &window_name;
    try expect(mem.eql(u8, mem.span(x[0].?), "window name"));
}

// test
