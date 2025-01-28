const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared_mod = b.createModule(.{
        .root_source_file = b.path("mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("mod", shared_mod);
    exe_mod.addImport("mod", shared_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "lib",
        .root_module = lib_mod,
    });

    exe_mod.linkLibrary(lib);

    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);
}
