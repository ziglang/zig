const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    if (builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12419
        return;
    }

    const main_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    main_mod.addCSourceFile(.{
        .file = b.path("test.c"),
    });

    for (0..1000) |_| {
        main_mod.addCMacro("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
    }

    main_mod.addCMacro("FOO", "42");
    main_mod.addCMacro("BAR", "\"BAR\"");
    main_mod.addCMacro("BAZ",
        \\"\"BAZ\""
    );
    main_mod.addCMacro("QUX", "\"Q\" \"UX\"");
    main_mod.addCMacro("QUUX", "\"QU\\\"UX\"");

    const exe = b.addExecutable2(.{
        .name = "zigtest",
        .root_module = main_mod,
    });
    b.installArtifact(exe);

    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.skip_foreign_checks = true;
    run_cmd.expectExitCode(0);

    test_step.dependOn(&run_cmd.step);
}
