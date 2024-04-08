const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("root", .{
        .root_source_file = b.path("root.zig"),
        .target = b.host,
        .optimize = .Debug,
    });
    const exe = b.addExecutable(.{
        .name = "main1",
        .root_source_file = b.path("main1.zig"),
        .target = b.host,
        .optimize = .Debug,
    });
    b.installArtifact(exe);
}
