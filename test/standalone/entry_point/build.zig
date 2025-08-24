pub fn build(b: *std.Build) !void {
    const mod = b.createModule(.{
        // Setting the entry point doesn't work properly on all targets right now. Since we're
        // really just trying to make sure that the compiler *frontend* respects `-fentry` and
        // includes it in the cache manifest, just test for a target where it works.
        .target = b.resolveTargetQuery(try .parse(.{
            .arch_os_abi = "x86_64-linux",
        })),
        .optimize = .ReleaseFast, // non-Debug build for reproducible output
        .root_source_file = b.path("main.zig"),
    });

    const exe_foo = b.addExecutable(.{
        .name = "the_exe", // same name for reproducible output
        .root_module = mod,
    });
    exe_foo.entry = .{ .symbol_name = "foo" };
    const exe_bar = b.addExecutable(.{
        .name = "the_exe", // same name for reproducible output
        .root_module = mod,
    });
    exe_bar.entry = .{ .symbol_name = "bar" };

    // Despite the output binary being reproducible, the `entry` differed, so the emitted binaries
    // should be different. But the two compilations are otherwise identical, so if `entry` isn't
    // being respected properly, we will see identical binaries.

    const check_differ_exe = b.addExecutable(.{
        .name = "check_differ",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = .Debug,
            .root_source_file = b.path("check_differ.zig"),
        }),
    });

    const diff_cmd = b.addRunArtifact(check_differ_exe);
    diff_cmd.addFileArg(exe_foo.getEmittedBin());
    diff_cmd.addFileArg(exe_bar.getEmittedBin());
    diff_cmd.expectExitCode(0);

    const test_step = b.step("test", "Test it");
    b.default_step = test_step;
    test_step.dependOn(&diff_cmd.step);
}
const std = @import("std");
