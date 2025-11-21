const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    if (builtin.os.tag != .windows) return;

    const expected_console_subsystem = std.fmt.comptimePrint("{}\n", .{@intFromEnum(std.coff.Subsystem.WINDOWS_CUI)});
    const expected_windows_subsystem = std.fmt.comptimePrint("{}\n", .{@intFromEnum(std.coff.Subsystem.WINDOWS_GUI)});

    // Normal Zig main, no libc linked
    {
        const main_mod = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .optimize = optimize,
            .target = target,
        });

        const main_inferred = b.addExecutable(.{
            .name = "main_inferred",
            .root_module = main_mod,
        });
        const run_inferred = b.addRunArtifact(main_inferred);
        run_inferred.expectStdErrEqual(expected_console_subsystem);
        run_inferred.expectExitCode(0);
        test_step.dependOn(&run_inferred.step);

        const main_console = b.addExecutable(.{
            .name = "main_console",
            .root_module = main_mod,
        });
        main_console.subsystem = .console;
        const run_console = b.addRunArtifact(main_console);
        run_console.expectStdErrEqual(expected_console_subsystem);
        run_console.expectExitCode(0);
        test_step.dependOn(&run_console.step);

        const main_windows = b.addExecutable(.{
            .name = "main_windows",
            .root_module = main_mod,
        });
        main_windows.subsystem = .windows;
        const run_windows = b.addRunArtifact(main_windows);
        run_windows.expectStdErrEqual(expected_windows_subsystem);
        run_windows.expectExitCode(0);
        test_step.dependOn(&run_windows.step);
    }

    // Normal Zig main, libc linked
    {
        const main_link_libc_mod = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .optimize = optimize,
            .target = target,
            .link_libc = true,
        });

        const main_link_libc_inferred = b.addExecutable(.{
            .name = "main_link_libc_inferred",
            .root_module = main_link_libc_mod,
        });
        const run_inferred = b.addRunArtifact(main_link_libc_inferred);
        run_inferred.expectStdErrEqual(expected_console_subsystem);
        run_inferred.expectExitCode(0);
        test_step.dependOn(&run_inferred.step);

        const main_link_libc_console = b.addExecutable(.{
            .name = "main_link_libc_console",
            .root_module = main_link_libc_mod,
        });
        main_link_libc_console.subsystem = .console;
        const run_console = b.addRunArtifact(main_link_libc_console);
        run_console.expectStdErrEqual(expected_console_subsystem);
        run_console.expectExitCode(0);
        test_step.dependOn(&run_console.step);

        const main_link_libc_windows = b.addExecutable(.{
            .name = "main_link_libc_windows",
            .root_module = main_link_libc_mod,
        });
        main_link_libc_windows.subsystem = .windows;
        const run_windows = b.addRunArtifact(main_link_libc_windows);
        run_windows.expectStdErrEqual(expected_windows_subsystem);
        run_windows.expectExitCode(0);
        test_step.dependOn(&run_windows.step);
    }

    // wWinMain
    {
        const winmain_mod = b.createModule(.{
            .root_source_file = b.path("winmain.zig"),
            .optimize = optimize,
            .target = target,
        });

        const winmain_inferred = b.addExecutable(.{
            .name = "winmain_inferred",
            .root_module = winmain_mod,
        });
        const run_inferred = b.addRunArtifact(winmain_inferred);
        run_inferred.expectStdErrEqual(expected_windows_subsystem);
        run_inferred.expectExitCode(0);
        test_step.dependOn(&run_inferred.step);

        const winmain_console = b.addExecutable(.{
            .name = "winmain_console",
            .root_module = winmain_mod,
        });
        winmain_console.subsystem = .console;
        const run_console = b.addRunArtifact(winmain_console);
        run_console.expectStdErrEqual(expected_console_subsystem);
        run_console.expectExitCode(0);
        test_step.dependOn(&run_console.step);

        const winmain_windows = b.addExecutable(.{
            .name = "winmain_windows",
            .root_module = winmain_mod,
        });
        winmain_windows.subsystem = .windows;
        const run_windows = b.addRunArtifact(winmain_windows);
        run_windows.expectStdErrEqual(expected_windows_subsystem);
        run_windows.expectExitCode(0);
        test_step.dependOn(&run_windows.step);
    }

    // exported callconv(.c) main, libc must be linked
    {
        const cmain_mod = b.createModule(.{
            .root_source_file = b.path("cmain.zig"),
            .optimize = optimize,
            .target = target,
            .link_libc = true,
        });

        const cmain_inferred = b.addExecutable(.{
            .name = "cmain_inferred",
            .root_module = cmain_mod,
        });
        const run_inferred = b.addRunArtifact(cmain_inferred);
        run_inferred.expectStdErrEqual(expected_console_subsystem);
        run_inferred.expectExitCode(0);
        test_step.dependOn(&run_inferred.step);

        const cmain_console = b.addExecutable(.{
            .name = "cmain_console",
            .root_module = cmain_mod,
        });
        cmain_console.subsystem = .console;
        const run_console = b.addRunArtifact(cmain_console);
        run_console.expectStdErrEqual(expected_console_subsystem);
        run_console.expectExitCode(0);
        test_step.dependOn(&run_console.step);

        const cmain_windows = b.addExecutable(.{
            .name = "cmain_windows",
            .root_module = cmain_mod,
        });
        cmain_windows.subsystem = .windows;
        const run_windows = b.addRunArtifact(cmain_windows);
        run_windows.expectStdErrEqual(expected_windows_subsystem);
        run_windows.expectExitCode(0);
        test_step.dependOn(&run_windows.step);
    }
}
