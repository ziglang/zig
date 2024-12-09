b: *std.Build,
step: *Step,
test_index: usize,
targets: []const Target,
check_exe: *std.Build.Step.Compile,

pub const Target = struct {
    target: std.Target.Query,
    optimize_mode: OptimizeMode,
};

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
    debug_format: std.builtin.DebugFormat,
    mode_config: Config.PerFormat,
) void {
    const b = this.b;
    const write_files = b.addWriteFiles();
    const source_zig = write_files.add("source.zig", source);

    add_target_loop: for (this.targets) |target| {
        if (mem.indexOfScalar(std.builtin.OptimizeMode, mode_config.exclude_optimize_mode, target.optimize_mode)) |_| continue :add_target_loop;

        const resolved_target = b.resolveTargetQuery(target.target);
        for (mode_config.exclude_os) |tag| if (tag == resolved_target.result.os.tag) continue :add_target_loop;

        const annotated_case_name = fmt.allocPrint(b.allocator, "check {s}-{s}-{s}-{s}", .{
            name,
            @tagName(debug_format),
            @tagName(target.optimize_mode),
            resolved_target.result.linuxTriple(b.allocator) catch @panic("OOM"),
        }) catch @panic("OOM");

        const exe = b.addExecutable(.{
            .name = "test",
            .root_source_file = source_zig,
            .target = resolved_target,
            .optimize = target.optimize_mode,
            .debuginfo = debug_format,
        });

        const run = b.addRunArtifact(exe);
        run.removeEnvironmentVariable("CLICOLOR_FORCE");
        run.setEnvironmentVariable("NO_COLOR", "1");

        // make sure to add term check fist, as `expectStdOutEqual` will detect no expectation for term and make it check for exit code 0
        if (mode_config.expect_panic) {
            switch (resolved_target.result.os.tag) {
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
const OptimizeMode = std.builtin.OptimizeMode;
const Step = std.Build.Step;
const fmt = std.fmt;
const mem = std.mem;
