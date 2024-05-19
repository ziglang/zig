const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const create_file_exe = b.addExecutable(.{
        .name = "create_file",
        .root_source_file = b.path("create_file.zig"),
        .target = target,
        .optimize = optimize,
    });

    const create_first = b.addRunArtifact(create_file_exe);
    const first_dir = create_first.addOutputDirectoryArg("first");
    create_first.addArg("hello1.txt");
    test_step.dependOn(&b.addCheckFile(first_dir.path(b, "hello1.txt"), .{ .expected_matches = &.{
        std.fs.path.sep_str ++
            \\first
            \\hello1.txt
            \\Hello, world!
            \\
        ,
    } }).step);

    const create_second = b.addRunArtifact(create_file_exe);
    const second_dir = create_second.addPrefixedOutputDirectoryArg("--dir=", "second");
    create_second.addArg("hello2.txt");
    test_step.dependOn(&b.addCheckFile(second_dir.path(b, "hello2.txt"), .{ .expected_matches = &.{
        std.fs.path.sep_str ++
            \\second
            \\hello2.txt
            \\Hello, world!
            \\
        ,
    } }).step);
}
