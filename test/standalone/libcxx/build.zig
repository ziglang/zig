const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const link_step = b.step("link", "Link with libcxx");
    const run_step = b.step("run", "Run executables");
    b.default_step = link_step;

    {
        const mod = b.createModule(.{
            .root_source_file = b.path("mt.zig"),
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });
        mod.addCSourceFile(.{ .file = b.path("mt_doit.cpp") });

        const exe = b.addExecutable2(.{
            .name = "mt",
            .root_module = mod,
        });
        link_step.dependOn(&exe.step);
        b.installArtifact(exe);
        run_step.dependOn(&b.addRunArtifact(exe).step);
    }
    {
        const mod = b.createModule(.{
            .root_source_file = b.path("st.zig"),
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
            .single_threaded = true,
        });
        mod.addCSourceFile(.{ .file = b.path("st_doit.cpp") });

        const exe = b.addExecutable2(.{
            .name = "st",
            .root_module = mod,
        });
        link_step.dependOn(&exe.step);
        b.installArtifact(exe);
        run_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
