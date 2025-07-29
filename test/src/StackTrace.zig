b: *std.Build,
step: *Step,
test_index: usize,
test_filters: []const []const u8,
optimize_modes: []const OptimizeMode,
check_exe: *std.Build.Step.Compile,

const Config = struct {
    name: []const u8,
    source: []const u8,
    Debug: ?PerMode = null,
    ReleaseSmall: ?PerMode = null,
    ReleaseSafe: ?PerMode = null,
    ReleaseFast: ?PerMode = null,

    const PerMode = struct {
        expect: []const u8,
        exclude_os: []const std.Target.Os.Tag = &.{},
        error_tracing: ?bool = null,
    };
};

pub fn addCase(self: *StackTrace, config: Config) void {
    self.addCaseInner(config, true);
    if (shouldTestNonLlvm(&self.b.graph.host.result)) {
        self.addCaseInner(config, false);
    }
}

fn addCaseInner(self: *StackTrace, config: Config, use_llvm: bool) void {
    if (config.Debug) |per_mode|
        self.addExpect(config.name, config.source, .Debug, use_llvm, per_mode);

    if (config.ReleaseSmall) |per_mode|
        self.addExpect(config.name, config.source, .ReleaseSmall, use_llvm, per_mode);

    if (config.ReleaseFast) |per_mode|
        self.addExpect(config.name, config.source, .ReleaseFast, use_llvm, per_mode);

    if (config.ReleaseSafe) |per_mode|
        self.addExpect(config.name, config.source, .ReleaseSafe, use_llvm, per_mode);
}

fn shouldTestNonLlvm(target: *const std.Target) bool {
    return switch (target.cpu.arch) {
        .x86_64 => switch (target.ofmt) {
            .elf => true,
            else => false,
        },
        else => false,
    };
}

fn addExpect(
    self: *StackTrace,
    name: []const u8,
    source: []const u8,
    optimize_mode: OptimizeMode,
    use_llvm: bool,
    mode_config: Config.PerMode,
) void {
    for (mode_config.exclude_os) |tag| if (tag == builtin.os.tag) return;

    const b = self.b;
    const annotated_case_name = b.fmt("check {s} ({s} {s})", .{
        name, @tagName(optimize_mode), if (use_llvm) "llvm" else "selfhosted",
    });
    for (self.test_filters) |test_filter| {
        if (mem.indexOf(u8, annotated_case_name, test_filter)) |_| break;
    } else if (self.test_filters.len > 0) return;

    const write_files = b.addWriteFiles();
    const source_zig = write_files.add("source.zig", source);
    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = source_zig,
            .optimize = optimize_mode,
            .target = b.graph.host,
            .error_tracing = mode_config.error_tracing,
        }),
        .use_llvm = use_llvm,
    });
    exe.bundle_ubsan_rt = false;

    const run = b.addRunArtifact(exe);
    run.removeEnvironmentVariable("CLICOLOR_FORCE");
    run.setEnvironmentVariable("NO_COLOR", "1");
    run.expectExitCode(1);
    run.expectStdOutEqual("");

    const check_run = b.addRunArtifact(self.check_exe);
    check_run.setName(annotated_case_name);
    check_run.addFileArg(run.captureStdErr());
    check_run.addArgs(&.{
        @tagName(optimize_mode),
    });
    check_run.expectStdOutEqual(mode_config.expect);

    self.step.dependOn(&check_run.step);
}

const StackTrace = @This();
const std = @import("std");
const builtin = @import("builtin");
const Step = std.Build.Step;
const OptimizeMode = std.builtin.OptimizeMode;
const mem = std.mem;
