//! Unlike `RunStep` this step will provide emulation, when enabled, to run foreign binaries.
//! When a binary is foreign, but emulation for the target is disabled, the specified binary
//! will not be run and therefore also not validated against its output.
//! This step can be useful when wishing to run a built binary on multiple platforms,
//! without having to verify if it's possible to be ran against.

const std = @import("../std.zig");
const build = std.build;
const Step = std.build.Step;
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

const fs = std.fs;
const process = std.process;
const EnvMap = process.EnvMap;

const EmulatableRunStep = @This();

pub const step_id = .emulatable_run;

const max_stdout_size = 1 * 1024 * 1024; // 1 MiB

step: Step,
builder: *Builder,

/// The artifact (executable) to be run by this step
exe: *LibExeObjStep,

/// Set this to `null` to ignore the exit code for the purpose of determining a successful execution
expected_exit_code: ?u8 = 0,

/// Override this field to modify the environment
env_map: ?*EnvMap,

/// Set this to modify the current working directory
cwd: ?[]const u8,

stdout_action: StdIoAction = .inherit,
stderr_action: StdIoAction = .inherit,

/// When set to true, hides the warning of skipping a foreign binary which cannot be run on the host
/// or through emulation.
hide_foreign_binaries_warning: bool,

pub const StdIoAction = union(enum) {
    inherit,
    ignore,
    expect_exact: []const u8,
    expect_matches: []const []const u8,
};

/// Creates a step that will execute the given artifact. This step will allow running the
/// binary through emulation when any of the emulation options such as `enable_rosetta` are set to true.
/// When set to false, and the binary is foreign, running the executable is skipped.
/// Asserts given artifact is an executable.
pub fn create(builder: *Builder, name: []const u8, artifact: *LibExeObjStep) *EmulatableRunStep {
    std.debug.assert(artifact.kind == .exe or artifact.kind == .test_exe);
    const self = builder.allocator.create(EmulatableRunStep) catch unreachable;
    const hide_warnings = builder.option(bool, "hide-foreign-warnings", "Hide the warning when a foreign binary which is incompatible is skipped") orelse false;
    self.* = .{
        .builder = builder,
        .step = Step.init(.emulatable_run, name, builder.allocator, make),
        .exe = artifact,
        .env_map = null,
        .cwd = null,
        .hide_foreign_binaries_warning = hide_warnings,
    };
    self.step.dependOn(&artifact.step);

    return self;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(EmulatableRunStep, "step", step);
    const host_info = self.builder.host;
    const cwd = if (self.cwd) |cwd| self.builder.pathFromRoot(cwd) else self.builder.build_root;

    var argv_list = std.ArrayList([]const u8).init(self.builder.allocator);
    defer argv_list.deinit();

    const need_cross_glibc = self.exe.target.isGnuLibC() and self.exe.is_linking_libc;
    switch (host_info.getExternalExecutor(self.exe.target_info, .{
        .qemu_fixes_dl = need_cross_glibc and self.builder.glibc_runtimes_dir != null,
        .link_libc = self.exe.is_linking_libc,
    })) {
        .native => {},
        .rosetta => if (!self.builder.enable_rosetta) return warnAboutForeignBinaries(self),
        .wine => |bin_name| if (self.builder.enable_wine) {
            try argv_list.append(bin_name);
        } else return,
        .qemu => |bin_name| if (self.builder.enable_qemu) {
            const glibc_dir_arg = if (need_cross_glibc)
                self.builder.glibc_runtimes_dir orelse return
            else
                null;
            try argv_list.append(bin_name);
            if (glibc_dir_arg) |dir| {
                // TODO look into making this a call to `linuxTriple`. This
                // needs the directory to be called "i686" rather than
                // "i386" which is why we do it manually here.
                const fmt_str = "{s}" ++ fs.path.sep_str ++ "{s}-{s}-{s}";
                const cpu_arch = self.exe.target.getCpuArch();
                const os_tag = self.exe.target.getOsTag();
                const abi = self.exe.target.getAbi();
                const cpu_arch_name: []const u8 = if (cpu_arch == .i386)
                    "i686"
                else
                    @tagName(cpu_arch);
                const full_dir = try std.fmt.allocPrint(self.builder.allocator, fmt_str, .{
                    dir, cpu_arch_name, @tagName(os_tag), @tagName(abi),
                });

                try argv_list.append("-L");
                try argv_list.append(full_dir);
            }
        } else return warnAboutForeignBinaries(self),
        .darling => |bin_name| if (self.builder.enable_darling) {
            try argv_list.append(bin_name);
        } else return warnAboutForeignBinaries(self),
        .wasmtime => |bin_name| if (self.builder.enable_wasmtime) {
            try argv_list.append(bin_name);
            try argv_list.append("--dir=.");
        } else return warnAboutForeignBinaries(self),
        else => return warnAboutForeignBinaries(self),
    }

    if (self.exe.target.isWindows()) {
        // On Windows we don't have rpaths so we have to add .dll search paths to PATH
        self.addPathForDynLibs(self.exe);
    }

    const executable_path = self.exe.installed_path orelse self.exe.getOutputSource().getPath(self.builder);
    try argv_list.append(executable_path);

    if (!std.process.can_spawn) {
        const cmd = try std.mem.join(self.builder.allocator, " ", argv_list.items);
        std.debug.print("the following command cannot be executed ({s} does not support spawning a child process):\n{s}", .{ @tagName(@import("builtin").os.tag), cmd });
        self.builder.allocator.free(cmd);
        return error.ExecNotSupported;
    }

    var child = std.ChildProcess.init(argv_list.items, self.builder.allocator);
    child.cwd = cwd;
    child.env_map = self.env_map orelse self.builder.env_map;

    child.stdin_behavior = .Inherit;
    child.stdout_behavior = stdIoActionToBehavior(self.stdout_action);
    child.stderr_behavior = stdIoActionToBehavior(self.stderr_action);

    child.spawn() catch |err| {
        std.debug.print("Unable to spawn {s}: {s}\n", .{ argv_list.items[0], @errorName(err) });
        return err;
    };

    var stdout: ?[]const u8 = null;
    defer if (stdout) |s| self.builder.allocator.free(s);

    switch (self.stdout_action) {
        .expect_exact, .expect_matches => {
            stdout = child.stdout.?.reader().readAllAlloc(self.builder.allocator, max_stdout_size) catch unreachable;
        },
        .inherit, .ignore => {},
    }

    var stderr: ?[]const u8 = null;
    defer if (stderr) |s| self.builder.allocator.free(s);

    switch (self.stderr_action) {
        .expect_exact, .expect_matches => {
            stderr = child.stderr.?.reader().readAllAlloc(self.builder.allocator, max_stdout_size) catch unreachable;
        },
        .inherit, .ignore => {},
    }

    const term = child.wait() catch |err| {
        std.debug.print("Unable to spawn {s}: {s}\n", .{ argv_list.items[0], @errorName(err) });
        return err;
    };

    switch (term) {
        .Exited => |code| blk: {
            const expected_exit_code = self.expected_exit_code orelse break :blk;

            if (code != expected_exit_code) {
                if (self.builder.prominent_compile_errors) {
                    std.debug.print("Run step exited with error code {} (expected {})\n", .{
                        code,
                        expected_exit_code,
                    });
                } else {
                    std.debug.print("The following command exited with error code {} (expected {}):\n", .{
                        code,
                        expected_exit_code,
                    });
                    printCmd(cwd, argv_list.items);
                }

                return error.UnexpectedExitCode;
            }
        },
        else => {
            std.debug.print("The following command terminated unexpectedly:\n", .{});
            printCmd(cwd, argv_list.items);
            return error.UncleanExit;
        },
    }

    switch (self.stderr_action) {
        .inherit, .ignore => {},
        .expect_exact => |expected_bytes| {
            if (!std.mem.eql(u8, expected_bytes, stderr.?)) {
                std.debug.print(
                    \\
                    \\========= Expected this stderr: =========
                    \\{s}
                    \\========= But found: ====================
                    \\{s}
                    \\
                , .{ expected_bytes, stderr.? });
                printCmd(cwd, argv_list.items);
                return error.TestFailed;
            }
        },
        .expect_matches => |matches| for (matches) |match| {
            if (std.mem.indexOf(u8, stderr.?, match) == null) {
                std.debug.print(
                    \\
                    \\========= Expected to find in stderr: =========
                    \\{s}
                    \\========= But stderr does not contain it: =====
                    \\{s}
                    \\
                , .{ match, stderr.? });
                printCmd(cwd, argv_list.items);
                return error.TestFailed;
            }
        },
    }

    switch (self.stdout_action) {
        .inherit, .ignore => {},
        .expect_exact => |expected_bytes| {
            if (!std.mem.eql(u8, expected_bytes, stdout.?)) {
                std.debug.print(
                    \\
                    \\========= Expected this stdout: =========
                    \\{s}
                    \\========= But found: ====================
                    \\{s}
                    \\
                , .{ expected_bytes, stdout.? });
                printCmd(cwd, argv_list.items);
                return error.TestFailed;
            }
        },
        .expect_matches => |matches| for (matches) |match| {
            if (std.mem.indexOf(u8, stdout.?, match) == null) {
                std.debug.print(
                    \\
                    \\========= Expected to find in stdout: =========
                    \\{s}
                    \\========= But stdout does not contain it: =====
                    \\{s}
                    \\
                , .{ match, stdout.? });
                printCmd(cwd, argv_list.items);
                return error.TestFailed;
            }
        },
    }
}

fn addPathForDynLibs(self: *EmulatableRunStep, artifact: *LibExeObjStep) void {
    for (artifact.link_objects.items) |link_object| {
        switch (link_object) {
            .other_step => |other| {
                if (other.target.isWindows() and other.isDynamicLibrary()) {
                    self.addPathDir(fs.path.dirname(other.getOutputSource().getPath(self.builder)).?);
                    self.addPathForDynLibs(other);
                }
            },
            else => {},
        }
    }
}

pub fn addPathDir(self: *EmulatableRunStep, search_path: []const u8) void {
    const env_map = self.getEnvMap();

    const key = "PATH";
    var prev_path = env_map.get(key);

    if (prev_path) |pp| {
        const new_path = self.builder.fmt("{s}" ++ [1]u8{fs.path.delimiter} ++ "{s}", .{ pp, search_path });
        env_map.put(key, new_path) catch unreachable;
    } else {
        env_map.put(key, self.builder.dupePath(search_path)) catch unreachable;
    }
}

pub fn getEnvMap(self: *EmulatableRunStep) *EnvMap {
    return self.env_map orelse {
        const env_map = self.builder.allocator.create(EnvMap) catch unreachable;
        env_map.* = process.getEnvMap(self.builder.allocator) catch unreachable;
        self.env_map = env_map;
        return env_map;
    };
}

pub fn expectStdErrEqual(self: *EmulatableRunStep, bytes: []const u8) void {
    self.stderr_action = .{ .expect_exact = self.builder.dupe(bytes) };
}

pub fn expectStdOutEqual(self: *EmulatableRunStep, bytes: []const u8) void {
    self.stdout_action = .{ .expect_exact = self.builder.dupe(bytes) };
}

fn stdIoActionToBehavior(action: StdIoAction) std.ChildProcess.StdIo {
    return switch (action) {
        .ignore => .Ignore,
        .inherit => .Inherit,
        .expect_exact, .expect_matches => .Pipe,
    };
}

fn printCmd(cwd: ?[]const u8, argv: []const []const u8) void {
    if (cwd) |yes_cwd| std.debug.print("cd {s} && ", .{yes_cwd});
    for (argv) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
}

fn warnAboutForeignBinaries(step: *EmulatableRunStep) void {
    if (step.hide_foreign_binaries_warning) return;
    const builder = step.builder;
    const artifact = step.exe;

    const host_name = builder.host.target.zigTriple(builder.allocator) catch unreachable;
    const foreign_name = artifact.target.zigTriple(builder.allocator) catch unreachable;
    const target_info = std.zig.system.NativeTargetInfo.detect(builder.allocator, artifact.target) catch unreachable;
    const need_cross_glibc = artifact.target.isGnuLibC() and artifact.is_linking_libc;
    switch (builder.host.getExternalExecutor(target_info, .{
        .qemu_fixes_dl = need_cross_glibc and builder.glibc_runtimes_dir != null,
        .link_libc = artifact.is_linking_libc,
    })) {
        .native => unreachable,
        .bad_dl => |foreign_dl| {
            const host_dl = builder.host.dynamic_linker.get() orelse "(none)";
            std.debug.print("the host system does not appear to be capable of executing binaries from the target because the host dynamic linker is '{s}', while the target dynamic linker is '{s}'. Consider setting the dynamic linker as '{s}'.\n", .{
                host_dl, foreign_dl, host_dl,
            });
        },
        .bad_os_or_cpu => {
            std.debug.print("the host system ({s}) does not appear to be capable of executing binaries from the target ({s}).\n", .{
                host_name, foreign_name,
            });
        },
        .darling => if (!builder.enable_darling) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling darling.\n",
                .{ host_name, foreign_name },
            );
        },
        .rosetta => if (!builder.enable_rosetta) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling rosetta.\n",
                .{ host_name, foreign_name },
            );
        },
        .wine => if (!builder.enable_wine) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling wine.\n",
                .{ host_name, foreign_name },
            );
        },
        .qemu => if (!builder.enable_qemu) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling qemu.\n",
                .{ host_name, foreign_name },
            );
        },
        .wasmtime => {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling wasmtime.\n",
                .{ host_name, foreign_name },
            );
        },
    }
}
