const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const step = b.step("test", "Run simple standalone test cases");
    b.default_step = step;

    const skip_debug = b.option(bool, "skip_debug", "Skip debug builds") orelse false;
    const skip_release_safe = b.option(bool, "skip_release_safe", "Skip release-safe builds") orelse false;
    const skip_release_fast = b.option(bool, "skip_release_fast", "Skip release-fast builds") orelse false;
    const skip_release_small = b.option(bool, "skip_release_small", "Skip release-small builds") orelse false;

    var optimize_modes_buf: [4]std.builtin.OptimizeMode = undefined;
    var optimize_modes_len: usize = 0;
    if (!skip_debug) {
        optimize_modes_buf[optimize_modes_len] = .Debug;
        optimize_modes_len += 1;
    }
    if (!skip_release_safe) {
        optimize_modes_buf[optimize_modes_len] = .ReleaseSafe;
        optimize_modes_len += 1;
    }
    if (!skip_release_fast) {
        optimize_modes_buf[optimize_modes_len] = .ReleaseFast;
        optimize_modes_len += 1;
    }
    if (!skip_release_small) {
        optimize_modes_buf[optimize_modes_len] = .ReleaseSmall;
        optimize_modes_len += 1;
    }
    const optimize_modes = optimize_modes_buf[0..optimize_modes_len];

    for (cases) |case| {
        for (optimize_modes) |optimize| {
            if (!case.all_modes and optimize != .Debug) continue;
            if (case.os_filter) |os_tag| {
                if (os_tag != builtin.os.tag) continue;
            }

            const resolved_target = b.resolveTargetQuery(case.target);

            if (case.is_exe) {
                const exe = b.addExecutable(.{
                    .name = std.fs.path.stem(case.src_path),
                    .root_source_file = b.path(case.src_path),
                    .optimize = optimize,
                    .target = resolved_target,
                });
                if (case.link_libc) exe.linkLibC();

                _ = exe.getEmittedBin();

                step.dependOn(&exe.step);
            }

            if (case.is_test) {
                const exe = b.addTest(.{
                    .name = std.fs.path.stem(case.src_path),
                    .root_source_file = b.path(case.src_path),
                    .optimize = optimize,
                    .target = resolved_target,
                });
                if (case.link_libc) exe.linkLibC();

                const run = b.addRunArtifact(exe);
                step.dependOn(&run.step);
            }
        }
    }
}

const Case = struct {
    src_path: []const u8,
    link_libc: bool = false,
    all_modes: bool = false,
    target: std.Target.Query = .{},
    is_test: bool = false,
    is_exe: bool = true,
    /// Run only on this OS.
    os_filter: ?std.Target.Os.Tag = null,
};

const cases = [_]Case{
    .{
        .src_path = "hello_world/hello.zig",
        .all_modes = true,
    },
    .{
        .src_path = "hello_world/hello_libc.zig",
        .link_libc = true,
        .all_modes = true,
    },
    .{
        .src_path = "cat/main.zig",
    },
    // https://github.com/ziglang/zig/issues/6025
    //.{
    //    .src_path = "issue_9693/main.zig",
    //},
    .{
        .src_path = "brace_expansion.zig",
        .is_test = true,
    },
    .{
        .src_path = "issue_7030.zig",
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    },
    .{ .src_path = "issue_12471/main.zig" },
    .{ .src_path = "guess_number/main.zig" },
    .{ .src_path = "main_return_error/error_u8.zig" },
    .{ .src_path = "main_return_error/error_u8_non_zero.zig" },
    .{ .src_path = "noreturn_call/inline.zig" },
    .{ .src_path = "noreturn_call/as_arg.zig" },
    .{ .src_path = "std_enums_big_enums.zig" },
    .{
        .src_path = "issue_9402/main.zig",
        .os_filter = .windows,
        .link_libc = true,
    },
};
