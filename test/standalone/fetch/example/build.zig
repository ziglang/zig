const std = @import("std");

pub fn build(b: *std.Build) void {
    const dep = b.dependency("somedependency", .{});
    b.getInstallStep().dependOn(&b.addInstallFile(
        dep.path("example_dep_file.txt"),
        "example_dep_file.txt",
    ).step);
}
