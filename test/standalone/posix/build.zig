const std = @import("std");
const builtin = @import("builtin");

const Case = struct {
    src_path: []const u8,
    set_env_vars: bool = false,
};

const cases = [_]Case{
    .{
        .src_path = "cwd.zig",
    },
    .{
        .src_path = "getenv.zig",
        .set_env_vars = true,
    },
    .{
        .src_path = "sigaction.zig",
    },
    .{
        .src_path = "relpaths.zig",
    },
};

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Run POSIX standalone test cases");
    b.default_step = test_step;

    const optimize = b.standardOptimizeOption(.{});

    const default_target = b.resolveTargetQuery(.{});

    // Run each test case built against libc-less, glibc, and musl.
    for (cases) |case| {
        const run_def = run_exe(b, optimize, &case, default_target, false);
        test_step.dependOn(&run_def.step);

        if (default_target.result.os.tag == .linux) {
            const gnu_target = b.resolveTargetQuery(.{ .abi = .gnu });
            const musl_target = b.resolveTargetQuery(.{ .abi = .musl });

            const run_gnu = run_exe(b, optimize, &case, gnu_target, true);
            const run_musl = run_exe(b, optimize, &case, musl_target, true);

            test_step.dependOn(&run_gnu.step);
            test_step.dependOn(&run_musl.step);
        } else {
            const run_libc = run_exe(b, optimize, &case, default_target, true);
            test_step.dependOn(&run_libc.step);
        }
    }
}

fn run_exe(b: *std.Build, optimize: std.builtin.OptimizeMode, case: *const Case, target: std.Build.ResolvedTarget, link_libc: bool) *std.Build.Step.Run {
    const exe_name = b.fmt("test-posix-{s}{s}{s}", .{
        std.fs.path.stem(case.src_path),
        if (link_libc) "-libc" else "",
        if (link_libc and target.result.isGnuLibC()) "-gnu" else if (link_libc and target.result.isMuslLibC()) "-musl" else "",
    });

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(case.src_path),
            .link_libc = link_libc,
            .optimize = optimize,
            .target = target,
        }),
    });

    const run_cmd = b.addRunArtifact(exe);

    if (case.set_env_vars) {
        run_cmd.setEnvironmentVariable("ZIG_TEST_POSIX_1EQ", "test=variable");
        run_cmd.setEnvironmentVariable("ZIG_TEST_POSIX_3EQ", "=test=variable=");
        run_cmd.setEnvironmentVariable("ZIG_TEST_POSIX_EMPTY", "");
    }

    return run_cmd;
}
