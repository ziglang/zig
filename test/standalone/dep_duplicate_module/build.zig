const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("mod", .{
        .root_source_file = b.path("mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "lib",
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("mod", mod);

    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("mod", mod);
    exe.root_module.linkLibrary(lib);

    b.installArtifact(exe);
}
