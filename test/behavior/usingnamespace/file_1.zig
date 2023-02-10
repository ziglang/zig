const std = @import("std");
const expect = std.testing.expect;
const imports = @import("imports.zig");

const A = 456;

test {
    try expect(imports.A == 123);
}
