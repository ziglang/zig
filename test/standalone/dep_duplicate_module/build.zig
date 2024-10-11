const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("mod", .{
        .root_source_file = b.path("mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary2(.{
        .name = "lib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "mod",
                    .module = mod,
                },
            },
        }),
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "mod",
                .module = mod,
            },
        },
    });
    exe_mod.linkLibrary(lib);

    const exe = b.addExecutable2(.{
        .name = "app",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);
}
