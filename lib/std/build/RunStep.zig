const std = @import("../std.zig");
const builtin = @import("builtin");
const build = std.build;
const Step = build.Step;
const Builder = build.Builder;
const LibExeObjStep = build.LibExeObjStep;
const WriteFileStep = build.WriteFileStep;
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const ArrayList = std.ArrayList;
const EnvMap = process.EnvMap;
const Allocator = mem.Allocator;
const ExecError = build.Builder.ExecError;

const max_stdout_size = 1 * 1024 * 1024; // 1 MiB

const RunStep = @This();

pub const base_id = .run;

step: Step,
builder: *Builder,

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

pub const StdIoAction = union(enum) {
    inherit,
    ignore,
    expect_exact: []const u8,
    expect_matches: []const []const u8,
};

pub const Arg = union(enum) {
    artifact: *LibExeObjStep,
    file_source: build.FileSource,
    bytes: []u8,
};

pub fn create(builder: *Builder, name: []const u8) *RunStep {
    const self = builder.allocator.create(RunStep) catch unreachable;
    self.* = RunStep{
        .builder = builder,
        .step = Step.init(.run, name, builder.allocator, make),
        .argv = ArrayList(Arg).init(builder.allocator),
        .cwd = null,
        .env_map = null,
        .print = builder.verbose,
    };
    return self;
}

pub fn addArtifactArg(self: *RunStep, artifact: *LibExeObjStep) void {
    self.argv.append(Arg{ .artifact = artifact }) catch unreachable;
    self.step.dependOn(&artifact.step);
}

pub fn addFileSourceArg(self: *RunStep, file_source: build.FileSource) void {
    self.argv.append(Arg{
        .file_source = file_source.dupe(self.builder),
    }) catch unreachable;
    file_source.addStepDependencies(&self.step);
}

pub fn addArg(self: *RunStep, arg: []const u8) void {
    self.argv.append(Arg{ .bytes = self.builder.dupe(arg) }) catch unreachable;
}

pub fn addArgs(self: *RunStep, args: []const []const u8) void {
    for (args) |arg| {
        self.addArg(arg);
    }
}

pub fn clearEnvironment(self: *RunStep) void {
    const new_env_map = self.builder.allocator.create(EnvMap) catch unreachable;
    new_env_map.* = EnvMap.init(self.builder.allocator);
    self.env_map = new_env_map;
}

pub fn addPathDir(self: *RunStep, search_path: []const u8) void {
    addPathDirInternal(&self.step, self.builder, search_path);
}

/// For internal use only, users of `RunStep` should use `addPathDir` directly.
pub fn addPathDirInternal(step: *Step, builder: *Builder, search_path: []const u8) void {
    const env_map = getEnvMapInternal(step, builder.allocator);

    const key = "PATH";
    var prev_path = env_map.get(key);

    if (prev_path) |pp| {
        const new_path = builder.fmt("{s}" ++ [1]u8{fs.path.delimiter} ++ "{s}", .{ pp, search_path });
        env_map.put(key, new_path) catch unreachable;
    } else {
        env_map.put(key, builder.dupePath(search_path)) catch unreachable;
    }
}

pub fn getEnvMap(self: *RunStep) *EnvMap {
    return getEnvMapInternal(&self.step, self.builder.allocator);
}

fn getEnvMapInternal(step: *Step, allocator: Allocator) *EnvMap {
    const maybe_env_map = switch (step.id) {
        .run => step.cast(RunStep).?.env_map,
        .emulatable_run => step.cast(build.EmulatableRunStep).?.env_map,
        else => unreachable,
    };
    return maybe_env_map orelse {
        const env_map = allocator.create(EnvMap) catch unreachable;
        env_map.* = process.getEnvMap(allocator) catch unreachable;
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
    ) catch unreachable;
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

fn make(step: *Step) !void {
    const self = @fieldParentPtr(RunStep, "step", step);

    var argv_list = ArrayList([]const u8).init(self.builder.allocator);
    for (self.argv.items) |arg| {
        switch (arg) {
            .bytes => |bytes| try argv_list.append(bytes),
            .file_source => |file| try argv_list.append(file.getPath(self.builder)),
            .artifact => |artifact| {
                if (artifact.target.isWindows()) {
                    // On Windows we don't have rpaths so we have to add .dll search paths to PATH
                    self.addPathForDynLibs(artifact);
                }
                const executable_path = artifact.installed_path orelse artifact.getOutputSource().getPath(self.builder);
                try argv_list.append(executable_path);
            },
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
}

pub fn runCommand(
    argv: []const []const u8,
    builder: *Builder,
    expected_exit_code: ?u8,
    stdout_action: StdIoAction,
    stderr_action: StdIoAction,
    stdin_behavior: std.ChildProcess.StdIo,
    env_map: ?*EnvMap,
    maybe_cwd: ?[]const u8,
    print: bool,
) !void {
    const cwd = if (maybe_cwd) |cwd| builder.pathFromRoot(cwd) else builder.build_root;

    if (!std.process.can_spawn) {
        const cmd = try std.mem.join(builder.addInstallDirectory, " ", argv);
        std.debug.print("the following command cannot be executed ({s} does not support spawning a child process):\n{s}", .{ @tagName(builtin.os.tag), cmd });
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
            stdout = child.stdout.?.reader().readAllAlloc(builder.allocator, max_stdout_size) catch unreachable;
        },
        .inherit, .ignore => {},
    }

    var stderr: ?[]const u8 = null;
    defer if (stderr) |s| builder.allocator.free(s);

    switch (stderr_action) {
        .expect_exact, .expect_matches => {
            stderr = child.stderr.?.reader().readAllAlloc(builder.allocator, max_stdout_size) catch unreachable;
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

fn printCmd(cwd: ?[]const u8, argv: []const []const u8) void {
    if (cwd) |yes_cwd| std.debug.print("cd {s} && ", .{yes_cwd});
    for (argv) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
}

fn addPathForDynLibs(self: *RunStep, artifact: *LibExeObjStep) void {
    addPathForDynLibsInternal(&self.step, self.builder, artifact);
}

/// This should only be used for internal usage, this is called automatically
/// for the user.
pub fn addPathForDynLibsInternal(step: *Step, builder: *Builder, artifact: *LibExeObjStep) void {
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
