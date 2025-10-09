b: *std.Build,
step: *Step,
test_filters: []const []const u8,
targets: []const std.Build.ResolvedTarget,
convert_exe: *std.Build.Step.Compile,

const Config = struct {
    name: []const u8,
    source: []const u8,
    /// Whether this test case expects to have unwind tables / frame pointers.
    unwind: enum {
        /// This case assumes that some unwind strategy, safe or unsafe, is available.
        any,
        /// This case assumes that no unwinding strategy is available.
        none,
        /// This case assumes that a safe unwind strategy, like DWARF unwinding, is available.
        safe,
        /// This case assumes that at most, unsafe FP unwinding is available.
        no_safe,
    },
    /// If `true`, the expected exit code is that of the default panic handler, rather than 0.
    expect_panic: bool,
    /// When debug info is not stripped, stdout is expected to **contain** (not equal!) this string.
    expect: []const u8,
    /// When debug info *is* stripped, stdout is expected to **contain** (not equal!) this string.
    expect_strip: []const u8,
};

pub fn addCase(self: *StackTrace, config: Config) void {
    for (self.targets) |*target| {
        addCaseTarget(
            self,
            config,
            target,
            if (target.query.isNative()) null else t: {
                break :t target.query.zigTriple(self.b.graph.arena) catch @panic("OOM");
            },
        );
    }
}
fn addCaseTarget(
    self: *StackTrace,
    config: Config,
    target: *const std.Build.ResolvedTarget,
    triple: ?[]const u8,
) void {
    const both_backends = switch (target.result.cpu.arch) {
        .x86_64 => switch (target.result.ofmt) {
            .elf => !target.result.os.tag.isBSD(),
            else => false,
        },
        else => false,
    };
    const both_pie = switch (target.result.os.tag) {
        .fuchsia, .openbsd => false,
        else => true,
    };
    const both_libc = switch (target.result.os.tag) {
        .freebsd, .netbsd => false,
        else => !target.result.requiresLibC(),
    };

    // On aarch64-macos, FP unwinding is blessed by Apple to always be reliable, and std.debug knows this.
    const fp_unwind_is_safe = target.result.cpu.arch == .aarch64 and target.result.os.tag.isDarwin();
    const supports_unwind_tables = switch (target.result.os.tag) {
        // x86-windows just has no way to do stack unwinding other then using frame pointers.
        .windows => target.result.cpu.arch != .x86,
        // We do not yet implement support for the AArch32 exception table section `.ARM.exidx`.
        else => !target.result.cpu.arch.isArm(),
    };

    const use_llvm_vals: []const bool = if (both_backends) &.{ true, false } else &.{true};
    const pie_vals: []const ?bool = if (both_pie) &.{ true, false } else &.{null};
    const link_libc_vals: []const ?bool = if (both_libc) &.{ true, false } else &.{null};
    const strip_debug_vals: []const bool = &.{ true, false };

    const UnwindInfo = packed struct(u2) {
        tables: bool,
        fp: bool,
        const none: @This() = .{ .tables = false, .fp = false };
        const both: @This() = .{ .tables = true, .fp = true };
        const only_tables: @This() = .{ .tables = true, .fp = false };
        const only_fp: @This() = .{ .tables = false, .fp = true };
    };
    const unwind_info_vals: []const UnwindInfo = switch (config.unwind) {
        .none => &.{.none},
        .any => &.{ .only_tables, .only_fp, .both },
        .safe => if (fp_unwind_is_safe) &.{ .only_tables, .only_fp, .both } else &.{ .only_tables, .both },
        .no_safe => if (fp_unwind_is_safe) &.{.none} else &.{ .none, .only_fp },
    };

    for (use_llvm_vals) |use_llvm| {
        for (pie_vals) |pie| {
            for (link_libc_vals) |link_libc| {
                for (strip_debug_vals) |strip_debug| {
                    for (unwind_info_vals) |unwind_info| {
                        if (unwind_info.tables and !supports_unwind_tables) continue;
                        self.addCaseInstance(
                            target,
                            triple,
                            config.name,
                            config.source,
                            use_llvm,
                            pie,
                            link_libc,
                            strip_debug,
                            !unwind_info.tables and supports_unwind_tables,
                            !unwind_info.fp,
                            config.expect_panic,
                            if (strip_debug) config.expect_strip else config.expect,
                        );
                    }
                }
            }
        }
    }
}

fn addCaseInstance(
    self: *StackTrace,
    target: *const std.Build.ResolvedTarget,
    triple: ?[]const u8,
    name: []const u8,
    source: []const u8,
    use_llvm: bool,
    pie: ?bool,
    link_libc: ?bool,
    strip_debug: bool,
    strip_unwind: bool,
    omit_frame_pointer: bool,
    expect_panic: bool,
    expect_stderr: []const u8,
) void {
    const b = self.b;

    if (strip_debug) {
        // To enable this coverage, one of two things needs to happen:
        // * The compiler needs to gain the ability to strip only debug info (not symbols)
        // * `std.Build.Step.ObjCopy` needs to be un-regressed
        return;
    }

    if (strip_unwind) {
        // To enable this coverage, `std.Build.Step.ObjCopy` needs to be un-regressed and gain the
        // ability to remove individual sections. `-fno-unwind-tables` is insufficient because it
        // does not prevent `.debug_frame` from being emitted. If we could, we would remove the
        // following sections:
        // * `.eh_frame`, `.eh_frame_hdr`, `.debug_frame` (Linux)
        // * `__TEXT,__eh_frame`, `__TEXT,__unwind_info` (macOS)
        return;
    }

    const annotated_case_name = b.fmt("check {s} ({s}{s}{s}{s}{s}{s}{s}{s})", .{
        name,
        triple orelse "",
        if (triple != null) " " else "",
        if (use_llvm) "llvm" else "selfhosted",
        if (pie == true) " pie" else "",
        if (link_libc == true) " libc" else "",
        if (strip_debug) " strip" else "",
        if (strip_unwind) " no_unwind" else "",
        if (omit_frame_pointer) " no_fp" else "",
    });
    if (self.test_filters.len > 0) {
        for (self.test_filters) |test_filter| {
            if (mem.indexOf(u8, annotated_case_name, test_filter)) |_| break;
        } else return;
    }

    const write_files = b.addWriteFiles();
    const source_zig = write_files.add("source.zig", source);
    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = source_zig,
            .optimize = .Debug,
            .target = target.*,
            .omit_frame_pointer = omit_frame_pointer,
            .link_libc = link_libc,
            .unwind_tables = if (strip_unwind) .none else null,
            // make panics single-threaded so that they don't include a thread ID
            .single_threaded = expect_panic,
        }),
        .use_llvm = use_llvm,
    });
    exe.pie = pie;
    exe.bundle_ubsan_rt = false;

    const run = b.addRunArtifact(exe);
    run.removeEnvironmentVariable("CLICOLOR_FORCE");
    run.setEnvironmentVariable("NO_COLOR", "1");
    run.addCheck(.{ .expect_term = term: {
        if (!expect_panic) break :term .{ .Exited = 0 };
        if (target.result.os.tag == .windows) break :term .{ .Exited = 3 };
        break :term .{ .Signal = 6 };
    } });
    run.expectStdOutEqual("");

    const check_run = b.addRunArtifact(self.convert_exe);
    check_run.setName(annotated_case_name);
    check_run.addFileArg(run.captureStdErr(.{}));
    check_run.expectExitCode(0);
    check_run.addCheck(.{ .expect_stdout_match = expect_stderr });

    self.step.dependOn(&check_run.step);
}

const StackTrace = @This();
const std = @import("std");
const builtin = @import("builtin");
const Step = std.Build.Step;
const OptimizeMode = std.builtin.OptimizeMode;
const mem = std.mem;
