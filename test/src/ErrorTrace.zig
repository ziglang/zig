b: *std.Build,
step: *Step,
test_filters: []const []const u8,
targets: []const std.Build.ResolvedTarget,
optimize_modes: []const OptimizeMode,
convert_exe: *std.Build.Step.Compile,

pub const Case = struct {
    name: []const u8,
    source: []const u8,
    expect_error: []const u8,
    expect_trace: []const u8,
    /// On these arch/OS pairs we will not test the error trace on optimized LLVM builds because the
    /// optimizations break the error trace. We will test the binary with error tracing disabled,
    /// just to ensure that the expected error is still returned from `main`.
    ///
    /// LLVM ReleaseSmall builds always have the trace disabled regardless of this field, because it
    /// seems that LLVM is particularly good at optimizing traces away in those.
    disable_trace_optimized: []const DisableConfig = &.{},

    pub const DisableConfig = struct { std.Target.Cpu.Arch, std.Target.Os.Tag };
    pub const Backend = enum { llvm, selfhosted };
};

pub fn addCase(self: *ErrorTrace, case: Case) void {
    for (self.targets) |*target| {
        const triple: ?[]const u8 = if (target.query.isNative()) null else t: {
            break :t target.query.zigTriple(self.b.graph.arena) catch @panic("OOM");
        };
        for (self.optimize_modes) |optimize| {
            self.addCaseConfig(case, target, triple, optimize, .llvm);
        }
        if (shouldTestNonLlvm(&target.result)) {
            for (self.optimize_modes) |optimize| {
                self.addCaseConfig(case, target, triple, optimize, .selfhosted);
            }
        }
    }
}

fn shouldTestNonLlvm(target: *const std.Target) bool {
    return switch (target.cpu.arch) {
        .x86_64 => switch (target.ofmt) {
            .elf => !target.os.tag.isBSD() and target.os.tag != .illumos,
            else => false,
        },
        else => false,
    };
}

fn addCaseConfig(
    self: *ErrorTrace,
    case: Case,
    target: *const std.Build.ResolvedTarget,
    triple: ?[]const u8,
    optimize: OptimizeMode,
    backend: Case.Backend,
) void {
    const b = self.b;

    const error_tracing: bool = tracing: {
        if (optimize == .Debug) break :tracing true;
        if (backend != .llvm) break :tracing true;
        if (optimize == .ReleaseSmall) break :tracing false;
        for (case.disable_trace_optimized) |disable| {
            const d_arch, const d_os = disable;
            if (target.result.cpu.arch == d_arch and target.result.os.tag == d_os) {
                // This particular configuration cannot do error tracing in optimized LLVM builds.
                break :tracing false;
            }
        }
        break :tracing true;
    };

    const annotated_case_name = b.fmt("check {s} ({s}{s}{s} {s})", .{
        case.name,
        triple orelse "",
        if (triple != null) " " else "",
        @tagName(optimize),
        @tagName(backend),
    });
    if (self.test_filters.len > 0) {
        for (self.test_filters) |test_filter| {
            if (mem.indexOf(u8, annotated_case_name, test_filter)) |_| break;
        } else return;
    }

    const write_files = b.addWriteFiles();
    const source_zig = write_files.add("source.zig", case.source);
    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = source_zig,
            .optimize = optimize,
            .target = target.*,
            .error_tracing = error_tracing,
            .strip = false,
        }),
        .use_llvm = switch (backend) {
            .llvm => true,
            .selfhosted => false,
        },
    });
    exe.bundle_ubsan_rt = false;

    const run = b.addRunArtifact(exe);
    run.removeEnvironmentVariable("CLICOLOR_FORCE");
    run.setEnvironmentVariable("NO_COLOR", "1");
    run.expectExitCode(1);
    run.expectStdOutEqual("");

    const expected_stderr = switch (error_tracing) {
        true => b.fmt("error: {s}\n{s}\n", .{ case.expect_error, case.expect_trace }),
        false => b.fmt("error: {s}\n", .{case.expect_error}),
    };

    const check_run = b.addRunArtifact(self.convert_exe);
    check_run.setName(annotated_case_name);
    check_run.addFileArg(run.captureStdErr(.{}));
    check_run.expectStdOutEqual(expected_stderr);

    self.step.dependOn(&check_run.step);
}

const ErrorTrace = @This();
const std = @import("std");
const builtin = @import("builtin");
const Step = std.Build.Step;
const OptimizeMode = std.builtin.OptimizeMode;
const mem = std.mem;
