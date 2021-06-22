const std = @import("std");
const expect = std.testing.expect;
const c = @cImport(@cInclude("b.h"));

test "import C sub" {
    const result = c.sub(2, 1);
    try expect(result == 1);
}
