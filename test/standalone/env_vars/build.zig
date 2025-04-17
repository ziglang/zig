const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const main = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });

    const run = b.addRunArtifact(main);
    run.clearEnvironment();
    run.setEnvironmentVariable("FOO", "123");
    run.setEnvironmentVariable("EQUALS", "ABC=123");
    run.setEnvironmentVariable("NO_VALUE", "");
    run.setEnvironmentVariable("КИРиллИЦА", "non-ascii አማርኛ \u{10FFFF}");
    if (b.graph.host.result.os.tag == .windows) {
        run.setEnvironmentVariable("=Hidden", "hi");
        // \xed\xa0\x80 is a WTF-8 encoded unpaired surrogate code point
        run.setEnvironmentVariable("INVALID_UTF16_\xed\xa0\x80", "\xed\xa0\x80");
    }
    run.disable_zig_progress = true;

    test_step.dependOn(&run.step);
}
