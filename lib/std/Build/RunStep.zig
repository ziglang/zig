const std = @import("../std.zig");
const builtin = @import("builtin");
const Step = std.Build.Step;
const CompileStep = std.Build.CompileStep;
const WriteFileStep = std.Build.WriteFileStep;
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const ArrayList = std.ArrayList;
const EnvMap = process.EnvMap;
const Allocator = mem.Allocator;
const ExecError = std.Build.ExecError;
const assert = std.debug.assert;

const RunStep = @This();

pub const base_id: Step.Id = .run;

step: Step,

/// See also addArg and addArgs to modifying this directly
argv: ArrayList(Arg),

/// Set this to modify the current working directory
cwd: ?[]const u8,

/// Override this field to modify the environment, or use setEnvironmentVariable
env_map: ?*EnvMap,

/// Configures whether the RunStep is considered to have side-effects, and also
/// whether the RunStep will inherit stdio streams, forwarding them to the
/// parent process, in which case will require a global lock to prevent other
/// steps from interfering with stdio while the subprocess associated with this
/// RunStep is running.
/// If the RunStep is determined to not have side-effects, then execution will
/// be skipped if all output files are up-to-date and input files are
/// unchanged.
stdio: StdIo = .infer_from_args,

/// Additional file paths relative to build.zig that, when modified, indicate
/// that the RunStep should be re-executed.
/// If the RunStep is determined to have side-effects, this field is ignored
/// and the RunStep is always executed when it appears in the build graph.
extra_file_dependencies: []const []const u8 = &.{},

/// After adding an output argument, this step will by default rename itself
/// for a better display name in the build summary.
/// This can be disabled by setting this to false.
rename_step_with_output_arg: bool = true,

/// If this is true, a RunStep which is configured to check the output of the
/// executed binary will not fail the build if the binary cannot be executed
/// due to being for a foreign binary to the host system which is running the
/// build graph.
/// Command-line arguments such as -fqemu and -fwasmtime may affect whether a
/// binary is detected as foreign, as well as system configuration such as
/// Rosetta (macOS) and binfmt_misc (Linux).
/// If this RunStep is considered to have side-effects, then this flag does
/// nothing.
skip_foreign_checks: bool = false,

/// If stderr or stdout exceeds this amount, the child process is killed and
/// the step fails.
max_stdio_size: usize = 10 * 1024 * 1024,

pub const StdIo = union(enum) {
    /// Whether the RunStep has side-effects will be determined by whether or not one
    /// of the args is an output file (added with `addOutputFileArg`).
    /// If the RunStep is determined to have side-effects, this is the same as `inherit`.
    /// The step will fail if the subprocess crashes or returns a non-zero exit code.
    infer_from_args,
    /// Causes the RunStep to be considered to have side-effects, and therefore
    /// always execute when it appears in the build graph.
    /// It also means that this step will obtain a global lock to prevent other
    /// steps from running in the meantime.
    /// The step will fail if the subprocess crashes or returns a non-zero exit code.
    inherit,
    /// Causes the RunStep to be considered to *not* have side-effects. The
    /// process will be re-executed if any of the input dependencies are
    /// modified. The exit code and standard I/O streams will be checked for
    /// certain conditions, and the step will succeed or fail based on these
    /// conditions.
    /// Note that an explicit check for exit code 0 needs to be added to this
    /// list if such a check is desireable.
    check: std.ArrayList(Check),

    pub const Check = union(enum) {
        expect_stderr_exact: []const u8,
        expect_stderr_match: []const u8,
        expect_stdout_exact: []const u8,
        expect_stdout_match: []const u8,
        expect_term: std.ChildProcess.Term,
    };
};

pub const Arg = union(enum) {
    artifact: *CompileStep,
    file_source: std.Build.FileSource,
    bytes: []u8,
    output: Output,

    pub const Output = struct {
        generated_file: *std.Build.GeneratedFile,
        basename: []const u8,
    };
};

pub fn create(owner: *std.Build, name: []const u8) *RunStep {
    const self = owner.allocator.create(RunStep) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = name,
            .owner = owner,
            .makeFn = make,
        }),
        .argv = ArrayList(Arg).init(owner.allocator),
        .cwd = null,
        .env_map = null,
        .rename_step_with_output_arg = true,
        .max_stdio_size = 10 * 1024 * 1024,
    };
    return self;
}

pub fn addArtifactArg(self: *RunStep, artifact: *CompileStep) void {
    self.argv.append(Arg{ .artifact = artifact }) catch @panic("OOM");
    self.step.dependOn(&artifact.step);
}

/// This provides file path as a command line argument to the command being
/// run, and returns a FileSource which can be used as inputs to other APIs
/// throughout the build system.
pub fn addOutputFileArg(rs: *RunStep, basename: []const u8) std.Build.FileSource {
    const b = rs.step.owner;
    const generated_file = b.allocator.create(std.Build.GeneratedFile) catch @panic("OOM");
    generated_file.* = .{ .step = &rs.step };
    rs.argv.append(.{ .output = .{
        .generated_file = generated_file,
        .basename = b.dupe(basename),
    } }) catch @panic("OOM");

    if (rs.rename_step_with_output_arg) {
        rs.rename_step_with_output_arg = false;
        rs.step.name = b.fmt("{s} ({s})", .{ rs.step.name, basename });
    }

    return .{ .generated = generated_file };
}

pub fn addFileSourceArg(self: *RunStep, file_source: std.Build.FileSource) void {
    self.argv.append(Arg{
        .file_source = file_source.dupe(self.step.owner),
    }) catch @panic("OOM");
    file_source.addStepDependencies(&self.step);
}

pub fn addArg(self: *RunStep, arg: []const u8) void {
    self.argv.append(Arg{ .bytes = self.step.owner.dupe(arg) }) catch @panic("OOM");
}

pub fn addArgs(self: *RunStep, args: []const []const u8) void {
    for (args) |arg| {
        self.addArg(arg);
    }
}

pub fn clearEnvironment(self: *RunStep) void {
    const b = self.step.owner;
    const new_env_map = b.allocator.create(EnvMap) catch @panic("OOM");
    new_env_map.* = EnvMap.init(b.allocator);
    self.env_map = new_env_map;
}

pub fn addPathDir(self: *RunStep, search_path: []const u8) void {
    addPathDirInternal(&self.step, self.step.owner, search_path);
}

/// For internal use only, users of `RunStep` should use `addPathDir` directly.
pub fn addPathDirInternal(step: *Step, builder: *std.Build, search_path: []const u8) void {
    const env_map = getEnvMapInternal(step, builder.allocator);

    const key = "PATH";
    var prev_path = env_map.get(key);

    if (prev_path) |pp| {
        const new_path = builder.fmt("{s}" ++ [1]u8{fs.path.delimiter} ++ "{s}", .{ pp, search_path });
        env_map.put(key, new_path) catch @panic("OOM");
    } else {
        env_map.put(key, builder.dupePath(search_path)) catch @panic("OOM");
    }
}

pub fn getEnvMap(self: *RunStep) *EnvMap {
    return getEnvMapInternal(&self.step, self.step.owner.allocator);
}

fn getEnvMapInternal(step: *Step, allocator: Allocator) *EnvMap {
    const maybe_env_map = switch (step.id) {
        .run => step.cast(RunStep).?.env_map,
        else => unreachable,
    };
    return maybe_env_map orelse {
        const env_map = allocator.create(EnvMap) catch @panic("OOM");
        env_map.* = process.getEnvMap(allocator) catch @panic("unhandled error");
        switch (step.id) {
            .run => step.cast(RunStep).?.env_map = env_map,
            else => unreachable,
        }
        return env_map;
    };
}

pub fn setEnvironmentVariable(self: *RunStep, key: []const u8, value: []const u8) void {
    const b = self.step.owner;
    const env_map = self.getEnvMap();
    env_map.put(b.dupe(key), b.dupe(value)) catch @panic("unhandled error");
}

/// Adds a check for exact stderr match. Does not add any other checks.
pub fn expectStdErrEqual(self: *RunStep, bytes: []const u8) void {
    const new_check: StdIo.Check = .{ .expect_stderr_exact = self.step.owner.dupe(bytes) };
    self.addCheck(new_check);
}

/// Adds a check for exact stdout match as well as a check for exit code 0, if
/// there is not already an expected termination check.
pub fn expectStdOutEqual(self: *RunStep, bytes: []const u8) void {
    const new_check: StdIo.Check = .{ .expect_stdout_exact = self.step.owner.dupe(bytes) };
    self.addCheck(new_check);
    if (!self.hasTermCheck()) {
        self.expectExitCode(0);
    }
}

pub fn expectExitCode(self: *RunStep, code: u8) void {
    const new_check: StdIo.Check = .{ .expect_term = .{ .Exited = code } };
    self.addCheck(new_check);
}

pub fn hasTermCheck(self: RunStep) bool {
    for (self.stdio.check.items) |check| switch (check) {
        .expect_term => return true,
        else => continue,
    };
    return false;
}

pub fn addCheck(self: *RunStep, new_check: StdIo.Check) void {
    switch (self.stdio) {
        .infer_from_args => {
            self.stdio = .{ .check = std.ArrayList(StdIo.Check).init(self.step.owner.allocator) };
            self.stdio.check.append(new_check) catch @panic("OOM");
        },
        .check => |*checks| checks.append(new_check) catch @panic("OOM"),
        else => @panic("illegal call to addCheck: conflicting helper method calls. Suggest to directly set stdio field of RunStep instead"),
    }
}

/// Returns whether the RunStep has side effects *other than* updating the output arguments.
fn hasSideEffects(self: RunStep) bool {
    return switch (self.stdio) {
        .infer_from_args => !self.hasAnyOutputArgs(),
        .inherit => true,
        .check => false,
    };
}

fn hasAnyOutputArgs(self: RunStep) bool {
    for (self.argv.items) |arg| switch (arg) {
        .output => return true,
        else => continue,
    };
    return false;
}

fn checksContainStdout(checks: []const StdIo.Check) bool {
    for (checks) |check| switch (check) {
        .expect_stderr_exact,
        .expect_stderr_match,
        .expect_term,
        => continue,

        .expect_stdout_exact,
        .expect_stdout_match,
        => return true,
    };
    return false;
}

fn checksContainStderr(checks: []const StdIo.Check) bool {
    for (checks) |check| switch (check) {
        .expect_stdout_exact,
        .expect_stdout_match,
        .expect_term,
        => continue,

        .expect_stderr_exact,
        .expect_stderr_match,
        => return true,
    };
    return false;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    // Unfortunately we have no way to collect progress from arbitrary programs.
    // Perhaps in the future Zig could offer some kind of opt-in IPC mechanism that
    // processes could use to supply progress updates.
    _ = prog_node;

    const b = step.owner;
    const arena = b.allocator;
    const self = @fieldParentPtr(RunStep, "step", step);
    const has_side_effects = self.hasSideEffects();

    var argv_list = ArrayList([]const u8).init(arena);
    var output_placeholders = ArrayList(struct {
        index: usize,
        output: Arg.Output,
    }).init(arena);

    var man = b.cache.obtain();
    defer man.deinit();

    for (self.argv.items) |arg| {
        switch (arg) {
            .bytes => |bytes| {
                try argv_list.append(bytes);
                man.hash.addBytes(bytes);
            },
            .file_source => |file| {
                const file_path = file.getPath(b);
                try argv_list.append(file_path);
                _ = try man.addFile(file_path, null);
            },
            .artifact => |artifact| {
                if (artifact.target.isWindows()) {
                    // On Windows we don't have rpaths so we have to add .dll search paths to PATH
                    self.addPathForDynLibs(artifact);
                }
                const file_path = artifact.installed_path orelse
                    artifact.getOutputSource().getPath(b);

                try argv_list.append(file_path);

                _ = try man.addFile(file_path, null);
            },
            .output => |output| {
                man.hash.addBytes(output.basename);
                // Add a placeholder into the argument list because we need the
                // manifest hash to be updated with all arguments before the
                // object directory is computed.
                try argv_list.append("");
                try output_placeholders.append(.{
                    .index = argv_list.items.len - 1,
                    .output = output,
                });
            },
        }
    }

    if (!has_side_effects) {
        for (self.extra_file_dependencies) |file_path| {
            _ = try man.addFile(b.pathFromRoot(file_path), null);
        }

        if (try step.cacheHit(&man)) {
            // cache hit, skip running command
            const digest = man.final();
            for (output_placeholders.items) |placeholder| {
                placeholder.output.generated_file.path = try b.cache_root.join(
                    arena,
                    &.{ "o", &digest, placeholder.output.basename },
                );
            }
            return;
        }

        const digest = man.final();

        for (output_placeholders.items) |placeholder| {
            const output_components = .{ "o", &digest, placeholder.output.basename };
            const output_sub_path = try fs.path.join(arena, &output_components);
            const output_sub_dir_path = fs.path.dirname(output_sub_path).?;
            b.cache_root.handle.makePath(output_sub_dir_path) catch |err| {
                return step.fail("unable to make path '{}{s}': {s}", .{
                    b.cache_root, output_sub_dir_path, @errorName(err),
                });
            };
            const output_path = try b.cache_root.join(arena, &output_components);
            placeholder.output.generated_file.path = output_path;
            argv_list.items[placeholder.index] = output_path;
        }
    }

    try runCommand(self, argv_list.items, has_side_effects);

    if (!has_side_effects) {
        try man.writeManifest();
    }
}

fn formatTerm(
    term: ?std.ChildProcess.Term,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    if (term) |t| switch (t) {
        .Exited => |code| try writer.print("exited with code {}", .{code}),
        .Signal => |sig| try writer.print("terminated with signal {}", .{sig}),
        .Stopped => |sig| try writer.print("stopped with signal {}", .{sig}),
        .Unknown => |code| try writer.print("terminated for unknown reason with code {}", .{code}),
    } else {
        try writer.writeAll("exited with any code");
    }
}
fn fmtTerm(term: ?std.ChildProcess.Term) std.fmt.Formatter(formatTerm) {
    return .{ .data = term };
}

fn termMatches(expected: ?std.ChildProcess.Term, actual: std.ChildProcess.Term) bool {
    return if (expected) |e| switch (e) {
        .Exited => |expected_code| switch (actual) {
            .Exited => |actual_code| expected_code == actual_code,
            else => false,
        },
        .Signal => |expected_sig| switch (actual) {
            .Signal => |actual_sig| expected_sig == actual_sig,
            else => false,
        },
        .Stopped => |expected_sig| switch (actual) {
            .Stopped => |actual_sig| expected_sig == actual_sig,
            else => false,
        },
        .Unknown => |expected_code| switch (actual) {
            .Unknown => |actual_code| expected_code == actual_code,
            else => false,
        },
    } else switch (actual) {
        .Exited => true,
        else => false,
    };
}

fn runCommand(self: *RunStep, argv: []const []const u8, has_side_effects: bool) !void {
    const step = &self.step;
    const b = step.owner;
    const arena = b.allocator;

    try step.handleChildProcUnsupported(self.cwd, argv);
    try Step.handleVerbose(step.owner, self.cwd, argv);

    var stdout_bytes: ?[]const u8 = null;
    var stderr_bytes: ?[]const u8 = null;

    const term = spawnChildAndCollect(self, argv, &stdout_bytes, &stderr_bytes, has_side_effects) catch |err| term: {
        if (err == error.InvalidExe) interpret: {
            // TODO: learn the target from the binary directly rather than from
            // relying on it being a CompileStep. This will make this logic
            // work even for the edge case that the binary was produced by a
            // third party.
            const exe = switch (self.argv.items[0]) {
                .artifact => |exe| exe,
                else => break :interpret,
            };
            if (exe.kind != .exe) break :interpret;

            var interp_argv = std.ArrayList([]const u8).init(b.allocator);
            defer interp_argv.deinit();

            const need_cross_glibc = exe.target.isGnuLibC() and exe.is_linking_libc;
            switch (b.host.getExternalExecutor(exe.target_info, .{
                .qemu_fixes_dl = need_cross_glibc and b.glibc_runtimes_dir != null,
                .link_libc = exe.is_linking_libc,
            })) {
                .native, .rosetta => {
                    if (self.stdio == .check and self.skip_foreign_checks)
                        return error.MakeSkipped;

                    break :interpret;
                },
                .wine => |bin_name| {
                    if (b.enable_wine) {
                        try interp_argv.append(bin_name);
                    } else {
                        return failForeign(self, "-fwine", argv[0], exe);
                    }
                },
                .qemu => |bin_name| {
                    if (b.enable_qemu) {
                        const glibc_dir_arg = if (need_cross_glibc)
                            b.glibc_runtimes_dir orelse return
                        else
                            null;

                        try interp_argv.append(bin_name);

                        if (glibc_dir_arg) |dir| {
                            // TODO look into making this a call to `linuxTriple`. This
                            // needs the directory to be called "i686" rather than
                            // "x86" which is why we do it manually here.
                            const fmt_str = "{s}" ++ fs.path.sep_str ++ "{s}-{s}-{s}";
                            const cpu_arch = exe.target.getCpuArch();
                            const os_tag = exe.target.getOsTag();
                            const abi = exe.target.getAbi();
                            const cpu_arch_name: []const u8 = if (cpu_arch == .x86)
                                "i686"
                            else
                                @tagName(cpu_arch);
                            const full_dir = try std.fmt.allocPrint(b.allocator, fmt_str, .{
                                dir, cpu_arch_name, @tagName(os_tag), @tagName(abi),
                            });

                            try interp_argv.append("-L");
                            try interp_argv.append(full_dir);
                        }
                    } else {
                        return failForeign(self, "-fqemu", argv[0], exe);
                    }
                },
                .darling => |bin_name| {
                    if (b.enable_darling) {
                        try interp_argv.append(bin_name);
                    } else {
                        return failForeign(self, "-fdarling", argv[0], exe);
                    }
                },
                .wasmtime => |bin_name| {
                    if (b.enable_wasmtime) {
                        try interp_argv.append(bin_name);
                        try interp_argv.append("--dir=.");
                    } else {
                        return failForeign(self, "-fwasmtime", argv[0], exe);
                    }
                },
                .bad_dl => |foreign_dl| {
                    if (self.stdio == .check and self.skip_foreign_checks)
                        return error.MakeSkipped;

                    const host_dl = b.host.dynamic_linker.get() orelse "(none)";

                    return step.fail(
                        \\the host system is unable to execute binaries from the target
                        \\  because the host dynamic linker is '{s}',
                        \\  while the target dynamic linker is '{s}'.
                        \\  consider setting the dynamic linker or enabling skip_foreign_checks in the Run step
                    , .{ host_dl, foreign_dl });
                },
                .bad_os_or_cpu => {
                    if (self.stdio == .check and self.skip_foreign_checks)
                        return error.MakeSkipped;

                    const host_name = try b.host.target.zigTriple(b.allocator);
                    const foreign_name = try exe.target.zigTriple(b.allocator);

                    return step.fail("the host system ({s}) is unable to execute binaries from the target ({s})", .{
                        host_name, foreign_name,
                    });
                },
            }

            if (exe.target.isWindows()) {
                // On Windows we don't have rpaths so we have to add .dll search paths to PATH
                RunStep.addPathForDynLibsInternal(&self.step, b, exe);
            }

            try interp_argv.append(argv[0]);

            try Step.handleVerbose(step.owner, self.cwd, interp_argv.items);

            assert(stdout_bytes == null);
            assert(stderr_bytes == null);
            break :term spawnChildAndCollect(self, interp_argv.items, &stdout_bytes, &stderr_bytes, has_side_effects) catch |inner_err| {
                return step.fail("unable to spawn {s}: {s}", .{
                    interp_argv.items[0], @errorName(inner_err),
                });
            };
        }

        return step.fail("unable to spawn {s}: {s}", .{ argv[0], @errorName(err) });
    };

    switch (self.stdio) {
        .check => |checks| for (checks.items) |check| switch (check) {
            .expect_stderr_exact => |expected_bytes| {
                if (!mem.eql(u8, expected_bytes, stderr_bytes.?)) {
                    return step.fail(
                        \\
                        \\========= expected this stderr: =========
                        \\{s}
                        \\========= but found: ====================
                        \\{s}
                        \\========= from the following command: ===
                        \\{s}
                    , .{
                        expected_bytes,
                        stderr_bytes.?,
                        try Step.allocPrintCmd(arena, self.cwd, argv),
                    });
                }
            },
            .expect_stderr_match => |match| {
                if (mem.indexOf(u8, stderr_bytes.?, match) == null) {
                    return step.fail(
                        \\
                        \\========= expected to find in stderr: =========
                        \\{s}
                        \\========= but stderr does not contain it: =====
                        \\{s}
                        \\========= from the following command: =========
                        \\{s}
                    , .{
                        match,
                        stderr_bytes.?,
                        try Step.allocPrintCmd(arena, self.cwd, argv),
                    });
                }
            },
            .expect_stdout_exact => |expected_bytes| {
                if (!mem.eql(u8, expected_bytes, stdout_bytes.?)) {
                    return step.fail(
                        \\
                        \\========= expected this stdout: =========
                        \\{s}
                        \\========= but found: ====================
                        \\{s}
                        \\========= from the following command: ===
                        \\{s}
                    , .{
                        expected_bytes,
                        stdout_bytes.?,
                        try Step.allocPrintCmd(arena, self.cwd, argv),
                    });
                }
            },
            .expect_stdout_match => |match| {
                if (mem.indexOf(u8, stdout_bytes.?, match) == null) {
                    return step.fail(
                        \\
                        \\========= expected to find in stdout: =========
                        \\{s}
                        \\========= but stdout does not contain it: =====
                        \\{s}
                        \\========= from the following command: =========
                        \\{s}
                    , .{
                        match,
                        stdout_bytes.?,
                        try Step.allocPrintCmd(arena, self.cwd, argv),
                    });
                }
            },
            .expect_term => |expected_term| {
                if (!termMatches(expected_term, term)) {
                    return step.fail("the following command {} (expected {}):\n{s}", .{
                        fmtTerm(term),
                        fmtTerm(expected_term),
                        try Step.allocPrintCmd(arena, self.cwd, argv),
                    });
                }
            },
        },
        else => {
            try step.handleChildProcessTerm(term, self.cwd, argv);
        },
    }
}

fn spawnChildAndCollect(
    self: *RunStep,
    argv: []const []const u8,
    stdout_bytes: *?[]const u8,
    stderr_bytes: *?[]const u8,
    has_side_effects: bool,
) !std.ChildProcess.Term {
    const b = self.step.owner;
    const arena = b.allocator;
    const cwd = if (self.cwd) |cwd| b.pathFromRoot(cwd) else b.build_root.path;

    var child = std.ChildProcess.init(argv, arena);
    child.cwd = cwd;
    child.env_map = self.env_map orelse b.env_map;

    child.stdin_behavior = switch (self.stdio) {
        .infer_from_args => if (has_side_effects) .Inherit else .Ignore,
        .inherit => .Inherit,
        .check => .Close,
    };
    child.stdout_behavior = switch (self.stdio) {
        .infer_from_args => if (has_side_effects) .Inherit else .Ignore,
        .inherit => .Inherit,
        .check => |checks| if (checksContainStdout(checks.items)) .Pipe else .Ignore,
    };
    child.stderr_behavior = switch (self.stdio) {
        .infer_from_args => if (has_side_effects) .Inherit else .Pipe,
        .inherit => .Inherit,
        .check => .Pipe,
    };

    child.spawn() catch |err| return self.step.fail("unable to spawn {s}: {s}", .{
        argv[0], @errorName(err),
    });

    if (child.stdout) |stdout| {
        if (child.stderr) |stderr| {
            var poller = std.io.poll(arena, enum { stdout, stderr }, .{
                .stdout = stdout,
                .stderr = stderr,
            });
            defer poller.deinit();

            while (try poller.poll()) {
                if (poller.fifo(.stdout).count > self.max_stdio_size)
                    return error.StdoutStreamTooLong;
                if (poller.fifo(.stderr).count > self.max_stdio_size)
                    return error.StderrStreamTooLong;
            }

            stdout_bytes.* = try poller.fifo(.stdout).toOwnedSlice();
            stderr_bytes.* = try poller.fifo(.stderr).toOwnedSlice();
        } else {
            stdout_bytes.* = try stdout.reader().readAllAlloc(arena, self.max_stdio_size);
        }
    } else if (child.stderr) |stderr| {
        stderr_bytes.* = try stderr.reader().readAllAlloc(arena, self.max_stdio_size);
    }

    if (stderr_bytes.*) |stderr| if (stderr.len > 0) {
        const stderr_is_diagnostic = switch (self.stdio) {
            .check => |checks| !checksContainStderr(checks.items),
            else => true,
        };
        if (stderr_is_diagnostic) {
            try self.step.result_error_msgs.append(arena, stderr);
        }
    };

    return child.wait();
}

fn addPathForDynLibs(self: *RunStep, artifact: *CompileStep) void {
    addPathForDynLibsInternal(&self.step, self.step.owner, artifact);
}

/// This should only be used for internal usage, this is called automatically
/// for the user.
pub fn addPathForDynLibsInternal(step: *Step, builder: *std.Build, artifact: *CompileStep) void {
    for (artifact.link_objects.items) |link_object| {
        switch (link_object) {
            .other_step => |other| {
                if (other.target.isWindows() and other.isDynamicLibrary()) {
                    addPathDirInternal(step, builder, fs.path.dirname(other.getOutputSource().getPath(builder)).?);
                    addPathForDynLibsInternal(step, builder, other);
                }
            },
            else => {},
        }
    }
}

fn failForeign(
    self: *RunStep,
    suggested_flag: []const u8,
    argv0: []const u8,
    exe: *CompileStep,
) error{ MakeFailed, MakeSkipped, OutOfMemory } {
    switch (self.stdio) {
        .check => {
            if (self.skip_foreign_checks)
                return error.MakeSkipped;

            const b = self.step.owner;
            const host_name = try b.host.target.zigTriple(b.allocator);
            const foreign_name = try exe.target.zigTriple(b.allocator);

            return self.step.fail(
                \\unable to spawn foreign binary '{s}' ({s}) on host system ({s})
                \\  consider using {s} or enabling skip_foreign_checks in the Run step
            , .{ argv0, foreign_name, host_name, suggested_flag });
        },
        else => {
            return self.step.fail("unable to spawn foreign binary '{s}'", .{argv0});
        },
    }
}
