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

const max_stdout_size = 1 * 1024 * 1024; // 1 MiB

const RunStep = @This();

pub const base_id: Step.Id = .run;

step: Step,
builder: *std.Build,

/// See also addArg and addArgs to modifying this directly
argv: ArrayList(Arg),

/// Set this to modify the current working directory
cwd: ?[]const u8,

/// Override this field to modify the environment, or use setEnvironmentVariable
env_map: ?*EnvMap,

stdout_action: StdIoAction = .inherit,
stderr_action: StdIoAction = .inherit,

stdin_behavior: std.ChildProcess.StdIo = .Inherit,

/// Set this to `null` to ignore the exit code for the purpose of determining a successful execution
expected_exit_code: ?u8 = 0,

/// Print the command before running it
print: bool,
/// Controls whether execution is skipped if the output file is up-to-date.
/// The default is to always run if there is no output file, and to skip
/// running if all output files are up-to-date.
condition: enum { output_outdated, always } = .output_outdated,

/// Additional file paths relative to build.zig that, when modified, indicate
/// that the RunStep should be re-executed.
extra_file_dependencies: []const []const u8 = &.{},

pub const StdIoAction = union(enum) {
    inherit,
    ignore,
    expect_exact: []const u8,
    expect_matches: []const []const u8,
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

pub fn create(builder: *std.Build, name: []const u8) *RunStep {
    const self = builder.allocator.create(RunStep) catch @panic("OOM");
    self.* = RunStep{
        .builder = builder,
        .step = Step.init(base_id, name, builder.allocator, make),
        .argv = ArrayList(Arg).init(builder.allocator),
        .cwd = null,
        .env_map = null,
        .print = builder.verbose,
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
    const generated_file = rs.builder.allocator.create(std.Build.GeneratedFile) catch @panic("OOM");
    generated_file.* = .{ .step = &rs.step };
    rs.argv.append(.{ .output = .{
        .generated_file = generated_file,
        .basename = rs.builder.dupe(basename),
    } }) catch @panic("OOM");

    return .{ .generated = generated_file };
}

pub fn addFileSourceArg(self: *RunStep, file_source: std.Build.FileSource) void {
    self.argv.append(Arg{
        .file_source = file_source.dupe(self.builder),
    }) catch @panic("OOM");
    file_source.addStepDependencies(&self.step);
}

pub fn addArg(self: *RunStep, arg: []const u8) void {
    self.argv.append(Arg{ .bytes = self.builder.dupe(arg) }) catch @panic("OOM");
}

pub fn addArgs(self: *RunStep, args: []const []const u8) void {
    for (args) |arg| {
        self.addArg(arg);
    }
}

pub fn clearEnvironment(self: *RunStep) void {
    const new_env_map = self.builder.allocator.create(EnvMap) catch @panic("OOM");
    new_env_map.* = EnvMap.init(self.builder.allocator);
    self.env_map = new_env_map;
}

pub fn addPathDir(self: *RunStep, search_path: []const u8) void {
    addPathDirInternal(&self.step, self.builder, search_path);
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
    return getEnvMapInternal(&self.step, self.builder.allocator);
}

fn getEnvMapInternal(step: *Step, allocator: Allocator) *EnvMap {
    const maybe_env_map = switch (step.id) {
        .run => step.cast(RunStep).?.env_map,
        .emulatable_run => step.cast(std.Build.EmulatableRunStep).?.env_map,
        else => unreachable,
    };
    return maybe_env_map orelse {
        const env_map = allocator.create(EnvMap) catch @panic("OOM");
        env_map.* = process.getEnvMap(allocator) catch @panic("unhandled error");
        switch (step.id) {
            .run => step.cast(RunStep).?.env_map = env_map,
            .emulatable_run => step.cast(RunStep).?.env_map = env_map,
            else => unreachable,
        }
        return env_map;
    };
}

pub fn setEnvironmentVariable(self: *RunStep, key: []const u8, value: []const u8) void {
    const env_map = self.getEnvMap();
    env_map.put(
        self.builder.dupe(key),
        self.builder.dupe(value),
    ) catch @panic("unhandled error");
}

pub fn expectStdErrEqual(self: *RunStep, bytes: []const u8) void {
    self.stderr_action = .{ .expect_exact = self.builder.dupe(bytes) };
}

pub fn expectStdOutEqual(self: *RunStep, bytes: []const u8) void {
    self.stdout_action = .{ .expect_exact = self.builder.dupe(bytes) };
}

fn stdIoActionToBehavior(action: StdIoAction) std.ChildProcess.StdIo {
    return switch (action) {
        .ignore => .Ignore,
        .inherit => .Inherit,
        .expect_exact, .expect_matches => .Pipe,
    };
}

fn needOutputCheck(self: RunStep) bool {
    if (self.extra_file_dependencies.len > 0) return true;

    for (self.argv.items) |arg| switch (arg) {
        .output => return true,
        else => continue,
    };

    return switch (self.condition) {
        .always => false,
        .output_outdated => true,
    };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(RunStep, "step", step);
    const need_output_check = self.needOutputCheck();

    var argv_list = ArrayList([]const u8).init(self.builder.allocator);
    var output_placeholders = ArrayList(struct {
        index: usize,
        output: Arg.Output,
    }).init(self.builder.allocator);

    var man = self.builder.cache.obtain();
    defer man.deinit();

    for (self.argv.items) |arg| {
        switch (arg) {
            .bytes => |bytes| {
                try argv_list.append(bytes);
                man.hash.addBytes(bytes);
            },
            .file_source => |file| {
                const file_path = file.getPath(self.builder);
                try argv_list.append(file_path);
                _ = try man.addFile(file_path, null);
            },
            .artifact => |artifact| {
                if (artifact.target.isWindows()) {
                    // On Windows we don't have rpaths so we have to add .dll search paths to PATH
                    self.addPathForDynLibs(artifact);
                }
                const file_path = artifact.installed_path orelse
                    artifact.getOutputSource().getPath(self.builder);

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

    if (need_output_check) {
        for (self.extra_file_dependencies) |file_path| {
            _ = try man.addFile(self.builder.pathFromRoot(file_path), null);
        }

        if (man.hit() catch |err| failWithCacheError(man, err)) {
            // cache hit, skip running command
            const digest = man.final();
            for (output_placeholders.items) |placeholder| {
                placeholder.output.generated_file.path = try self.builder.cache_root.join(
                    self.builder.allocator,
                    &.{ "o", &digest, placeholder.output.basename },
                );
            }
            return;
        }

        const digest = man.final();

        for (output_placeholders.items) |placeholder| {
            const output_path = try self.builder.cache_root.join(
                self.builder.allocator,
                &.{ "o", &digest, placeholder.output.basename },
            );
            const output_dir = fs.path.dirname(output_path).?;
            fs.cwd().makePath(output_dir) catch |err| {
                std.debug.print("unable to make path {s}: {s}\n", .{ output_dir, @errorName(err) });
                return err;
            };

            placeholder.output.generated_file.path = output_path;
            argv_list.items[placeholder.index] = output_path;
        }
    }

    try runCommand(
        argv_list.items,
        self.builder,
        self.expected_exit_code,
        self.stdout_action,
        self.stderr_action,
        self.stdin_behavior,
        self.env_map,
        self.cwd,
        self.print,
    );

    if (need_output_check) {
        try man.writeManifest();
    }
}

pub fn runCommand(
    argv: []const []const u8,
    builder: *std.Build,
    expected_exit_code: ?u8,
    stdout_action: StdIoAction,
    stderr_action: StdIoAction,
    stdin_behavior: std.ChildProcess.StdIo,
    env_map: ?*EnvMap,
    maybe_cwd: ?[]const u8,
    print: bool,
) !void {
    const cwd = if (maybe_cwd) |cwd| builder.pathFromRoot(cwd) else builder.build_root.path;

    if (!std.process.can_spawn) {
        const cmd = try std.mem.join(builder.allocator, " ", argv);
        std.debug.print("the following command cannot be executed ({s} does not support spawning a child process):\n{s}", .{
            @tagName(builtin.os.tag), cmd,
        });
        builder.allocator.free(cmd);
        return ExecError.ExecNotSupported;
    }

    var child = std.ChildProcess.init(argv, builder.allocator);
    child.cwd = cwd;
    child.env_map = env_map orelse builder.env_map;

    child.stdin_behavior = stdin_behavior;
    child.stdout_behavior = stdIoActionToBehavior(stdout_action);
    child.stderr_behavior = stdIoActionToBehavior(stderr_action);

    if (print)
        printCmd(cwd, argv);

    child.spawn() catch |err| {
        std.debug.print("Unable to spawn {s}: {s}\n", .{ argv[0], @errorName(err) });
        return err;
    };

    // TODO need to poll to read these streams to prevent a deadlock (or rely on evented I/O).

    var stdout: ?[]const u8 = null;
    defer if (stdout) |s| builder.allocator.free(s);

    switch (stdout_action) {
        .expect_exact, .expect_matches => {
            stdout = try child.stdout.?.reader().readAllAlloc(builder.allocator, max_stdout_size);
        },
        .inherit, .ignore => {},
    }

    var stderr: ?[]const u8 = null;
    defer if (stderr) |s| builder.allocator.free(s);

    switch (stderr_action) {
        .expect_exact, .expect_matches => {
            stderr = try child.stderr.?.reader().readAllAlloc(builder.allocator, max_stdout_size);
        },
        .inherit, .ignore => {},
    }

    const term = child.wait() catch |err| {
        std.debug.print("Unable to spawn {s}: {s}\n", .{ argv[0], @errorName(err) });
        return err;
    };

    switch (term) {
        .Exited => |code| blk: {
            const expected_code = expected_exit_code orelse break :blk;

            if (code != expected_code) {
                if (builder.prominent_compile_errors) {
                    std.debug.print("Run step exited with error code {} (expected {})\n", .{
                        code,
                        expected_code,
                    });
                } else {
                    std.debug.print("The following command exited with error code {} (expected {}):\n", .{
                        code,
                        expected_code,
                    });
                    printCmd(cwd, argv);
                }

                return error.UnexpectedExitCode;
            }
        },
        else => {
            std.debug.print("The following command terminated unexpectedly:\n", .{});
            printCmd(cwd, argv);
            return error.UncleanExit;
        },
    }

    switch (stderr_action) {
        .inherit, .ignore => {},
        .expect_exact => |expected_bytes| {
            if (!mem.eql(u8, expected_bytes, stderr.?)) {
                std.debug.print(
                    \\
                    \\========= Expected this stderr: =========
                    \\{s}
                    \\========= But found: ====================
                    \\{s}
                    \\
                , .{ expected_bytes, stderr.? });
                printCmd(cwd, argv);
                return error.TestFailed;
            }
        },
        .expect_matches => |matches| for (matches) |match| {
            if (mem.indexOf(u8, stderr.?, match) == null) {
                std.debug.print(
                    \\
                    \\========= Expected to find in stderr: =========
                    \\{s}
                    \\========= But stderr does not contain it: =====
                    \\{s}
                    \\
                , .{ match, stderr.? });
                printCmd(cwd, argv);
                return error.TestFailed;
            }
        },
    }

    switch (stdout_action) {
        .inherit, .ignore => {},
        .expect_exact => |expected_bytes| {
            if (!mem.eql(u8, expected_bytes, stdout.?)) {
                std.debug.print(
                    \\
                    \\========= Expected this stdout: =========
                    \\{s}
                    \\========= But found: ====================
                    \\{s}
                    \\
                , .{ expected_bytes, stdout.? });
                printCmd(cwd, argv);
                return error.TestFailed;
            }
        },
        .expect_matches => |matches| for (matches) |match| {
            if (mem.indexOf(u8, stdout.?, match) == null) {
                std.debug.print(
                    \\
                    \\========= Expected to find in stdout: =========
                    \\{s}
                    \\========= But stdout does not contain it: =====
                    \\{s}
                    \\
                , .{ match, stdout.? });
                printCmd(cwd, argv);
                return error.TestFailed;
            }
        },
    }
}

fn failWithCacheError(man: std.Build.Cache.Manifest, err: anyerror) noreturn {
    const i = man.failed_file_index orelse failWithSimpleError(err);
    const pp = man.files.items[i].prefixed_path orelse failWithSimpleError(err);
    const prefix = man.cache.prefixes()[pp.prefix].path orelse "";
    std.debug.print("{s}: {s}/{s}\n", .{ @errorName(err), prefix, pp.sub_path });
    std.process.exit(1);
}

fn failWithSimpleError(err: anyerror) noreturn {
    std.debug.print("{s}\n", .{@errorName(err)});
    std.process.exit(1);
}

fn printCmd(cwd: ?[]const u8, argv: []const []const u8) void {
    if (cwd) |yes_cwd| std.debug.print("cd {s} && ", .{yes_cwd});
    for (argv) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
}

fn addPathForDynLibs(self: *RunStep, artifact: *CompileStep) void {
    addPathForDynLibsInternal(&self.step, self.builder, artifact);
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
