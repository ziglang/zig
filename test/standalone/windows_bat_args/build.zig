const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    if (builtin.os.tag != .windows) return;

    const echo_args = b.addExecutable2(.{
        .name = "echo-args",
        .root_module = b.createModule(.{
            .root_source_file = b.path("echo-args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_exe = b.addExecutable2(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run = b.addRunArtifact(test_exe);
    run.addArtifactArg(echo_args);
    run.expectExitCode(0);
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);

    const fuzz = b.addExecutable2(.{
        .name = "fuzz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fuzz.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const fuzz_max_iterations = b.option(u64, "iterations", "The max fuzz iterations (default: 100)") orelse 100;
    const fuzz_iterations_arg = b.fmt("{}", .{fuzz_max_iterations});

    const fuzz_seed = b.option(u64, "seed", "Seed to use for the PRNG (default: random)") orelse seed: {
        var buf: [8]u8 = undefined;
        try std.posix.getrandom(&buf);
        break :seed std.mem.readInt(u64, &buf, builtin.cpu.arch.endian());
    };
    const fuzz_seed_arg = b.fmt("{}", .{fuzz_seed});

    const fuzz_run = b.addRunArtifact(fuzz);
    fuzz_run.addArtifactArg(echo_args);
    fuzz_run.addArgs(&.{ fuzz_iterations_arg, fuzz_seed_arg });
    fuzz_run.expectExitCode(0);
    fuzz_run.skip_foreign_checks = true;

    test_step.dependOn(&fuzz_run.step);
}
