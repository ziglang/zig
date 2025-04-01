b: *std.Build,
step: *Step,
test_index: usize,
optimize_modes: []const OptimizeMode,
check_exe: *std.Build.Step.Compile,

const Config = struct {
    name: []const u8,
    source: []const u8,
    symbols: ?PerFormat = null,
    dwarf32: ?PerFormat = null,

    const PerFormat = struct {
        expect_panic: bool = false,
        expect: []const u8,
        exclude_os: []const std.Target.Os.Tag = &.{},
        exclude_optimize_mode: []const std.builtin.OptimizeMode = &.{},
    };
};

const DebugFormat = enum {
    symbols,
    dwarf32,
};

pub fn addCase(this: *@This(), config: Config) void {
    if (config.symbols) |per_format|
        this.addExpect(config.name, config.source, .symbols, per_format);

    if (config.dwarf32) |per_format|
        this.addExpect(config.name, config.source, .dwarf32, per_format);
}

fn addExpect(
    this: *@This(),
    name: []const u8,
    source: []const u8,
    debug_format: DebugFormat,
    mode_config: Config.PerFormat,
) void {
    for (mode_config.exclude_os) |tag| if (tag == builtin.os.tag) return;

    const b = this.b;
    const write_files = b.addWriteFiles();
    const source_zig = write_files.add("source.zig", source);

    for (this.optimize_modes) |mode| {
        if (mem.indexOfScalar(std.builtin.OptimizeMode, mode_config.exclude_optimize_mode, mode)) |_| continue;

        const annotated_case_name = fmt.allocPrint(b.allocator, "check {s} ({s},{s})", .{
            name, @tagName(debug_format), @tagName(mode),
        }) catch @panic("OOM");

        const exe = b.addExecutable(.{
            .name = "test",
            .root_source_file = source_zig,
            .target = b.graph.host,
            .optimize = mode,
        });
        exe.root_module.strip = false;

        const exe_path_to_run: std.Build.LazyPath = switch (debug_format) {
            .symbols => blk: {
                const debug_stripped_exe = exe.addObjCopy(.{
                    .strip = .debug,
                });
                break :blk debug_stripped_exe.getOutput();
            },
            .dwarf32 => exe.getEmittedBin(),
        };

        const run = std.Build.Step.Run.create(b, "test");
        run.addFileArg(exe_path_to_run);
        run.removeEnvironmentVariable("CLICOLOR_FORCE");
        run.setEnvironmentVariable("NO_COLOR", "1");

        // make sure to add term check fist, as `expectStdOutEqual` will detect no expectation for term and make it check for exit code 0
        if (mode_config.expect_panic) {
            switch (builtin.os.tag) {
                // Expect exit code 3 on abort: https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/abort?view=msvc-170
                .windows => run.addCheck(.{ .expect_term = .{ .Exited = 3 } }),
                else => run.addCheck(.{ .expect_term = .{ .Signal = 6 } }),
            }
        }
        run.expectStdOutEqual("");

        const check_run = b.addRunArtifact(this.check_exe);
        check_run.setName(annotated_case_name);
        check_run.addFileArg(run.captureStdErr());
        check_run.addArgs(&.{
            @tagName(debug_format),
        });
        check_run.expectStdOutEqual(mode_config.expect);

        this.step.dependOn(&check_run.step);
    }
}

const std = @import("std");
const builtin = @import("builtin");
const OptimizeMode = std.builtin.OptimizeMode;
const Step = std.Build.Step;
const fmt = std.fmt;
const mem = std.mem;
