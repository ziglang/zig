const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("add", .{
        .root_source_file = b.path("add.add.zig"),
    });
}
