const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    if (builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12419
        return;
    }

    const exe = b.addExecutable(.{
        .name = "zigtest",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const c_sources = [_][]const u8{
        "test.c",
    };

    exe.addCSourceFiles(.{ .files = &c_sources });
    exe.linkLibC();

    var i: i32 = 0;
    while (i < 1000) : (i += 1) {
        exe.defineCMacro("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
    }

    exe.defineCMacro("FOO", "42");
    exe.defineCMacro("BAR", "\"BAR\"");
    exe.defineCMacro("BAZ",
        \\"\"BAZ\""
    );
    exe.defineCMacro("QUX", "\"Q\" \"UX\"");
    exe.defineCMacro("QUUX", "\"QU\\\"UX\"");

    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.skip_foreign_checks = true;
    run_cmd.expectExitCode(0);

    test_step.dependOn(&run_cmd.step);
}
