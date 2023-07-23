const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Unwinding with a frame pointer
    //
    // getcontext version: zig std
    //
    // Unwind info type:
    //   - ELF: DWARF .debug_frame
    //   - MachO: __unwind_info encodings:
    //     - x86_64: RBP_FRAME
    //     - aarch64: FRAME, DWARF
    {
        const exe = b.addExecutable(.{
            .name = "unwind_fp",
            .root_source_file = .{ .path = "unwind.zig" },
            .target = target,
            .optimize = optimize,
        });

        if (target.isDarwin()) exe.unwind_tables = true;
        exe.omit_frame_pointer = false;

        const run_cmd = b.addRunArtifact(exe);
        test_step.dependOn(&run_cmd.step);
    }

    // Unwinding without a frame pointer
    //
    // getcontext version: zig std
    //
    // Unwind info type:
    //   - ELF: DWARF .eh_frame_hdr + .eh_frame
    //   - MachO: __unwind_info encodings:
    //     - x86_64: STACK_IMMD, STACK_IND
    //     - aarch64: FRAMELESS, DWARF
    {
        const exe = b.addExecutable(.{
            .name = "unwind_nofp",
            .root_source_file = .{ .path = "unwind.zig" },
            .target = target,
            .optimize = optimize,
        });

        exe.omit_frame_pointer = true;
        exe.unwind_tables = true;

        const run_cmd = b.addRunArtifact(exe);
        test_step.dependOn(&run_cmd.step);
    }

    // Unwinding through a C shared library without a frame pointer (libc)
    //
    // getcontext version: libc
    //
    // Unwind info type:
    //   - ELF: DWARF .eh_frame + .debug_frame
    //   - MachO: __unwind_info encodings:
    //     - x86_64: STACK_IMMD, STACK_IND
    //     - aarch64: FRAMELESS, DWARF
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
