//! Verify that Step.Compile.installHeader correctly declare a dependency on
//! the Step itself.
//!
//! Test for https://github.com/ziglang/zig/issues/17204.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const foo = b.addStaticLibrary(.{
        .name = "foo",
        .root_source_file = .{ .path = "foo.zig" },
        .optimize = .Debug,
        .target = target,
    });
    foo.installHeader("foo.h", "foo.h");

    const exists_in = b.addExecutable(.{
        .name = "exists_in",
        .root_source_file = .{ .path = "exists_in.zig" },
        .optimize = .Debug,
        .target = target,
    });

    const run = b.addRunArtifact(exists_in);
    run.addDirectoryArg(.{ .path = b.getInstallPath(.header, ".") });
    run.addArgs(&.{"foo.h"});
    run.expectExitCode(0);
    run.step.dependOn(&foo.step);

    const test_step = b.step("test", "Test it");
    b.default_step = test_step;
    test_step.dependOn(&run.step);
}
