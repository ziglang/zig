const std = @import("std");

pub fn build(b: *std.Build) void {
    const main = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
        .optimize = .Debug,
    });

    const options = b.addOptions();
    main.addOptions("build_options", options);
    options.addOption(bool, "bool_true", b.option(bool, "bool_true", "t").?);
    options.addOption(bool, "bool_false", b.option(bool, "bool_false", "f").?);
    options.addOption(u32, "int", b.option(u32, "int", "i").?);
    const E = enum { one, two, three };
    options.addOption(E, "e", b.option(E, "e", "e").?);
    options.addOption([]const u8, "string", b.option([]const u8, "string", "s").?);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(main).step);
}
