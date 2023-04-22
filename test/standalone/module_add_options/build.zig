const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const test_opt = b.option(bool, "option", "test option") orelse true;
    const opts = b.addOptions();
    opts.addOption(bool, "option", test_opt);

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });

    var module = b.addModule("test_module", .{
        .source_file = .{
            .path = "test_module.zig",
        },
        .dependencies = &.{},
    });
    module.addOptions("test_options", opts);

    exe.addModule("test_module", module);

    const run = b.addRunArtifact(exe);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
    b.default_step = test_step;
}
