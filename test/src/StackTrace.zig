b: *std.Build,
step: *Step,
test_index: usize,
test_filter: ?[]const u8,
optimize_modes: []const OptimizeMode,
check_exe: *std.Build.Step.Compile,

const Expect = [@typeInfo(OptimizeMode).Enum.fields.len][]const u8;

pub fn addCase(self: *StackTrace, config: anytype) void {
    if (@hasField(@TypeOf(config), "exclude")) {
        if (config.exclude.exclude()) return;
    }
    if (@hasField(@TypeOf(config), "exclude_arch")) {
        const exclude_arch: []const std.Target.Cpu.Arch = &config.exclude_arch;
        for (exclude_arch) |arch| if (arch == builtin.cpu.arch) return;
    }
    if (@hasField(@TypeOf(config), "exclude_os")) {
        const exclude_os: []const std.Target.Os.Tag = &config.exclude_os;
        for (exclude_os) |os| if (os == builtin.os.tag) return;
    }
    for (self.optimize_modes) |optimize_mode| {
        switch (optimize_mode) {
            .Debug => {
                if (@hasField(@TypeOf(config), "Debug")) {
                    self.addExpect(config.name, config.source, optimize_mode, config.Debug);
                }
            },
            .ReleaseSafe => {
                if (@hasField(@TypeOf(config), "ReleaseSafe")) {
                    self.addExpect(config.name, config.source, optimize_mode, config.ReleaseSafe);
                }
            },
            .ReleaseFast => {
                if (@hasField(@TypeOf(config), "ReleaseFast")) {
                    self.addExpect(config.name, config.source, optimize_mode, config.ReleaseFast);
                }
            },
            .ReleaseSmall => {
                if (@hasField(@TypeOf(config), "ReleaseSmall")) {
                    self.addExpect(config.name, config.source, optimize_mode, config.ReleaseSmall);
                }
            },
        }
    }
}

fn addExpect(
    self: *StackTrace,
    name: []const u8,
    source: []const u8,
    optimize_mode: OptimizeMode,
    mode_config: anytype,
) void {
    if (@hasField(@TypeOf(mode_config), "exclude")) {
        if (mode_config.exclude.exclude()) return;
    }
    if (@hasField(@TypeOf(mode_config), "exclude_arch")) {
        const exclude_arch: []const std.Target.Cpu.Arch = &mode_config.exclude_arch;
        for (exclude_arch) |arch| if (arch == builtin.cpu.arch) return;
    }
    if (@hasField(@TypeOf(mode_config), "exclude_os")) {
        const exclude_os: []const std.Target.Os.Tag = &mode_config.exclude_os;
        for (exclude_os) |os| if (os == builtin.os.tag) return;
    }

    const b = self.b;
    const annotated_case_name = fmt.allocPrint(b.allocator, "check {s} ({s})", .{
        name, @tagName(optimize_mode),
    }) catch @panic("OOM");
    if (self.test_filter) |filter| {
        if (mem.indexOf(u8, annotated_case_name, filter) == null) return;
    }

    const src_basename = "source.zig";
    const write_src = b.addWriteFile(src_basename, source);
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = write_src.getFileSource(src_basename).?,
        .optimize = optimize_mode,
        .target = .{},
    });

    const run = b.addRunArtifact(exe);
    run.removeEnvironmentVariable("ZIG_DEBUG_COLOR");
    run.setEnvironmentVariable("NO_COLOR", "1");
    run.expectExitCode(1);
    run.expectStdOutEqual("");

    const check_run = b.addRunArtifact(self.check_exe);
    check_run.setName(annotated_case_name);
    check_run.addFileSourceArg(run.captureStdErr());
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
const fmt = std.fmt;
const mem = std.mem;
