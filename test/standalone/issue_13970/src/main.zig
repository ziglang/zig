const std = @import("std");
const package = @import("package.zig");
const root = @import("root");
const builtin = @import("builtin");

pub fn main() !void {
    _ = package.decl;
}
