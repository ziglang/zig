const std = @import("std");
const expect = std.testing.expect;
const c = @cImport(@cInclude("a.h"));

test "import C add" {
    const result = c.add(2, 1);
    try expect(result == 3);
}
