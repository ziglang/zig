const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const link_step = b.step("link", "Link with libcxx");
    const run_step = b.step("run", "Run executables");
    b.default_step = link_step;

    {
        const exe = b.addExecutable(.{
            .name = "mt",
            .root_source_file = b.path("mt.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibCpp();
        exe.addCSourceFile(.{ .file = b.path("mt_doit.cpp") });
        link_step.dependOn(&exe.step);
        b.installArtifact(exe);
        run_step.dependOn(&b.addRunArtifact(exe).step);
    }
    {
        const exe = b.addExecutable(.{
            .name = "st",
            .root_source_file = b.path("st.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
        });
        exe.linkLibCpp();
        exe.addCSourceFile(.{ .file = b.path("st_doit.cpp") });
        link_step.dependOn(&exe.step);
        b.installArtifact(exe);
        run_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
