pub fn build(b: *std.Build) !void {
    _ = b.addModule("module", .{
        .root_source_file = b.path("src/root.zig"),
    });
    @panic("overridden-buildtime package has not been overridden");
}

const std = @import("std");
