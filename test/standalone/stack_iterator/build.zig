const std = @import("std");
const builtin = @import("builtin");

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
        const exe = b.addExecutable2(.{
            .name = "unwind_fp",
            .root_module = b.createModule(.{
                .root_source_file = b.path("unwind.zig"),
                .target = target,
                .optimize = optimize,
                .unwind_tables = if (target.result.isDarwin()) true else null,
                .omit_frame_pointer = false,
            }),
        });

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
        const exe = b.addExecutable2(.{
            .name = "unwind_nofp",
            .root_module = b.createModule(.{
                .root_source_file = b.path("unwind.zig"),
                .target = target,
                .optimize = optimize,
                .unwind_tables = true,
                .omit_frame_pointer = true,
            }),
        });

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
        const c_mod = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
            .strip = false,
            .link_libc = true,
        });
        if (target.result.os.tag == .windows)
            c_mod.addCMacro("LIB_API", "__declspec(dllexport)");
        c_mod.addCSourceFile(.{
            .file = b.path("shared_lib.c"),
            .flags = &.{"-fomit-frame-pointer"},
        });

        const c_shared_lib = b.addSharedLibrary2(.{
            .name = "c_shared_lib",
            .root_module = c_mod,
        });

        const main_mod = b.createModule(.{
            .root_source_file = b.path("shared_lib_unwind.zig"),
            .target = target,
            .optimize = optimize,
            .unwind_tables = if (target.result.isDarwin()) true else null,
            .omit_frame_pointer = true,
        });
        main_mod.linkLibrary(c_shared_lib);

        const exe = b.addExecutable2(.{
            .name = "shared_lib_unwind",
            .root_module = main_mod,
        });

        const run_cmd = b.addRunArtifact(exe);
        test_step.dependOn(&run_cmd.step);

        // Separate debug info ELF file
        if (target.result.ofmt == .elf) {
            const filename = b.fmt("{s}_stripped", .{exe.out_filename});
            const stripped_exe = b.addObjCopy(exe.getEmittedBin(), .{
                .basename = filename, // set the name for the debuglink
                .compress_debug = true,
                .strip = .debug,
                .extract_to_separate_file = true,
            });

            const run_stripped = std.Build.Step.Run.create(b, b.fmt("run {s}", .{filename}));
            run_stripped.addFileArg(stripped_exe.getOutput());
            test_step.dependOn(&run_stripped.step);
        }
    }

    // Unwinding without libc/posix
    //
    // No "getcontext" or "ucontext_t"
    {
        const exe = b.addExecutable2(.{
            .name = "unwind_freestanding",
            .root_module = b.createModule(.{
                .root_source_file = b.path("unwind_freestanding.zig"),
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = .x86_64,
                    .os_tag = .freestanding,
                }),
                .optimize = optimize,
                .unwind_tables = null,
                .omit_frame_pointer = false,
            }),
        });

        // This "freestanding" binary is runnable because it invokes the
        // Linux exit syscall directly.
        if (builtin.os.tag == .linux and builtin.cpu.arch == .x86_64) {
            const run_cmd = b.addRunArtifact(exe);
            test_step.dependOn(&run_cmd.step);
        } else {
            test_step.dependOn(&exe.step);
        }
    }
}
