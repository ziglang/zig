const std = @import("std");
const Cases = @import("src/Cases.zig");

pub fn addCases(cases: *Cases) !void {
    try @import("compile_errors.zig").addCases(cases);
    try @import("cbe.zig").addCases(cases);
    try @import("nvptx.zig").addCases(cases);
}
