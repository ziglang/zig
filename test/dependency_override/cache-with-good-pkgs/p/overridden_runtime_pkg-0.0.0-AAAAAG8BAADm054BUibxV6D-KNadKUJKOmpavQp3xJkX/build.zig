pub fn build(b: *std.Build) !void {
    _ = b.addModule("module", .{
        .root_source_file = b.path("src/root.zig"),
    });
}

const std = @import("std");
