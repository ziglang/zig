const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Unwinding pure zig code, with a frame pointer
    {
        const exe = b.addExecutable(.{
            .name = "zig_unwind_fp",
            .root_source_file = .{ .path = "zig_unwind.zig" },
            .target = target,
            .optimize = optimize,
        });

        if (target.isDarwin()) exe.unwind_tables = true;
        exe.omit_frame_pointer = false;

        const run_cmd = b.addRunArtifact(exe);
        test_step.dependOn(&run_cmd.step);
    }

    // Unwinding pure zig code, without a frame pointer
    {
        const exe = b.addExecutable(.{
            .name = "zig_unwind_nofp",
            .root_source_file = .{ .path = "zig_unwind.zig" },
            .target = target,
            .optimize = optimize,
        });

        if (target.isDarwin()) exe.unwind_tables = true;
        exe.omit_frame_pointer = true;

        const run_cmd = b.addRunArtifact(exe);
        test_step.dependOn(&run_cmd.step);
    }

    // Unwinding through a C shared library without a frame pointer (libc)
    {
        const c_shared_lib = b.addSharedLibrary(.{
            .name = "c_shared_lib",
            .target = target,
            .optimize = optimize,
        });

        if (target.isWindows()) c_shared_lib.defineCMacro("LIB_API", "__declspec(dllexport)");

        c_shared_lib.strip = false;
        c_shared_lib.addCSourceFile("shared_lib.c", &.{"-fomit-frame-pointer"});
        c_shared_lib.linkLibC();

        const exe = b.addExecutable(.{
            .name = "shared_lib_unwind",
            .root_source_file = .{ .path = "shared_lib_unwind.zig" },
            .target = target,
            .optimize = optimize,
        });

        if (target.isDarwin()) exe.unwind_tables = true;
        exe.omit_frame_pointer = true;
        exe.linkLibrary(c_shared_lib);

        const run_cmd = b.addRunArtifact(exe);
        test_step.dependOn(&run_cmd.step);
    }
}
