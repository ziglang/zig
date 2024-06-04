const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const Step = Build.Step;
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const EnvMap = process.EnvMap;
const assert = std.debug.assert;

const Run = @This();

pub const base_id: Step.Id = .run;

step: Step,

/// See also addArg and addArgs to modifying this directly
argv: std.ArrayListUnmanaged(Arg),

/// Use `setCwd` to set the initial current working directory
cwd: ?Build.LazyPath,

/// Override this field to modify the environment, or use setEnvironmentVariable
env_map: ?*EnvMap,

/// When `true` prevents `ZIG_PROGRESS` environment variable from being passed
/// to the child process, which otherwise would be used for the child to send
/// progress updates to the parent.
disable_zig_progress: bool,

/// Configures whether the Run step is considered to have side-effects, and also
/// whether the Run step will inherit stdio streams, forwarding them to the
/// parent process, in which case will require a global lock to prevent other
/// steps from interfering with stdio while the subprocess associated with this
/// Run step is running.
/// If the Run step is determined to not have side-effects, then execution will
/// be skipped if all output files are up-to-date and input files are
/// unchanged.
stdio: StdIo,

/// This field must be `.none` if stdio is `inherit`.
/// It should be only set using `setStdIn`.
stdin: StdIn,

/// Deprecated: use `addFileInput`
extra_file_dependencies: []const []const u8,

/// Additional input files that, when modified, indicate that the Run step
/// should be re-executed.
/// If the Run step is determined to have side-effects, the Run step is always
/// executed when it appears in the build graph, regardless of whether these
/// files have been modified.
file_inputs: std.ArrayListUnmanaged(std.Build.LazyPath),

/// After adding an output argument, this step will by default rename itself
/// for a better display name in the build summary.
/// This can be disabled by setting this to false.
rename_step_with_output_arg: bool,

/// If this is true, a Run step which is configured to check the output of the
/// executed binary will not fail the build if the binary cannot be executed
/// due to being for a foreign binary to the host system which is running the
/// build graph.
/// Command-line arguments such as -fqemu and -fwasmtime may affect whether a
/// binary is detected as foreign, as well as system configuration such as
/// Rosetta (macOS) and binfmt_misc (Linux).
/// If this Run step is considered to have side-effects, then this flag does
/// nothing.
skip_foreign_checks: bool,

/// If this is true, failing to execute a foreign binary will be considered an
/// error. However if this is false, the step will be skipped on failure instead.
///
/// This allows for a Run step to attempt to execute a foreign binary using an
/// external executor (such as qemu) but not fail if the executor is unavailable.
failing_to_execute_foreign_is_an_error: bool,

/// If stderr or stdout exceeds this amount, the child process is killed and
/// the step fails.
max_stdio_size: usize,

captured_stdout: ?*Output,
captured_stderr: ?*Output,

dep_output_file: ?*Output,

has_side_effects: bool,

pub const StdIn = union(enum) {
    none,
    bytes: []const u8,
    lazy_path: std.Build.LazyPath,
};

pub const StdIo = union(enum) {
    /// Whether the Run step has side-effects will be determined by whether or not one
    /// of the args is an output file (added with `addOutputFileArg`).
    /// If the Run step is determined to have side-effects, this is the same as `inherit`.
    /// The step will fail if the subprocess crashes or returns a non-zero exit code.
    infer_from_args,
    /// Causes the Run step to be considered to have side-effects, and therefore
    /// always execute when it appears in the build graph.
    /// It also means that this step will obtain a global lock to prevent other
    /// steps from running in the meantime.
    /// The step will fail if the subprocess crashes or returns a non-zero exit code.
    inherit,
    /// Causes the Run step to be considered to *not* have side-effects. The
    /// process will be re-executed if any of the input dependencies are
    /// modified. The exit code and standard I/O streams will be checked for
    /// certain conditions, and the step will succeed or fail based on these
    /// conditions.
    /// Note that an explicit check for exit code 0 needs to be added to this
    /// list if such a check is desirable.
    check: std.ArrayListUnmanaged(Check),
    /// This Run step is running a zig unit test binary and will communicate
    /// extra metadata over the IPC protocol.
    zig_test,

    pub const Check = union(enum) {
        expect_stderr_exact: []const u8,
        expect_stderr_match: []const u8,
        expect_stdout_exact: []const u8,
        expect_stdout_match: []const u8,
        expect_term: std.process.Child.Term,
    };
};

pub const Arg = union(enum) {
    artifact: *Step.Compile,
    lazy_path: PrefixedLazyPath,
    directory_source: PrefixedLazyPath,
    bytes: []u8,
    output_file: *Output,
    output_directory: *Output,
};

pub const PrefixedLazyPath = struct {
    prefix: []const u8,
    lazy_path: std.Build.LazyPath,
};

pub const Output = struct {
    generated_file: std.Build.GeneratedFile,
    prefix: []const u8,
    basename: []const u8,
};

pub fn create(owner: *std.Build, name: []const u8) *Run {
    const run = owner.allocator.create(Run) catch @panic("OOM");
    run.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = name,
            .owner = owner,
            .makeFn = make,
        }),
        .argv = .{},
        .cwd = null,
        .env_map = null,
        .disable_zig_progress = false,
        .stdio = .infer_from_args,
        .stdin = .none,
        .extra_file_dependencies = &.{},
        .file_inputs = .{},
        .rename_step_with_output_arg = true,
        .skip_foreign_checks = false,
        .failing_to_execute_foreign_is_an_error = true,
        .max_stdio_size = 10 * 1024 * 1024,
        .captured_stdout = null,
        .captured_stderr = null,
        .dep_output_file = null,
        .has_side_effects = false,
    };
    return run;
}

pub fn setName(run: *Run, name: []const u8) void {
    run.step.name = name;
    run.rename_step_with_output_arg = false;
}

pub fn enableTestRunnerMode(run: *Run) void {
    run.stdio = .zig_test;
    run.addArgs(&.{"--listen=-"});
}

pub fn addArtifactArg(run: *Run, artifact: *Step.Compile) void {
    const b = run.step.owner;
    const bin_file = artifact.getEmittedBin();
    bin_file.addStepDependencies(&run.step);
    run.argv.append(b.allocator, Arg{ .artifact = artifact }) catch @panic("OOM");
}

/// Provides a file path as a command line argument to the command being run.
///
/// Returns a `std.Build.LazyPath` which can be used as inputs to other APIs
/// throughout the build system.
///
/// Related:
/// * `addPrefixedOutputFileArg` - same thing but prepends a string to the argument
/// * `addFileArg` - for input files given to the child process
pub fn addOutputFileArg(run: *Run, basename: []const u8) std.Build.LazyPath {
    return run.addPrefixedOutputFileArg("", basename);
}

/// Provides a file path as a command line argument to the command being run.
/// Asserts `basename` is not empty.
///
/// For example, a prefix of "-o" and basename of "output.txt" will result in
/// the child process seeing something like this: "-ozig-cache/.../output.txt"
///
/// The child process will see a single argument, regardless of whether the
/// prefix or basename have spaces.
///
/// The returned `std.Build.LazyPath` can be used as inputs to other APIs
/// throughout the build system.
///
/// Related:
/// * `addOutputFileArg` - same thing but without the prefix
/// * `addFileArg` - for input files given to the child process
pub fn addPrefixedOutputFileArg(
    run: *Run,
    prefix: []const u8,
    basename: []const u8,
) std.Build.LazyPath {
    const b = run.step.owner;
    if (basename.len == 0) @panic("basename must not be empty");

    const output = b.allocator.create(Output) catch @panic("OOM");
    output.* = .{
        .prefix = b.dupe(prefix),
        .basename = b.dupe(basename),
        .generated_file = .{ .step = &run.step },
    };
    run.argv.append(b.allocator, .{ .output_file = output }) catch @panic("OOM");

    if (run.rename_step_with_output_arg) {
        run.setName(b.fmt("{s} ({s})", .{ run.step.name, basename }));
    }

    return .{ .generated = .{ .file = &output.generated_file } };
}

/// Appends an input file to the command line arguments.
///
/// The child process will see a file path. Modifications to this file will be
/// detected as a cache miss in subsequent builds, causing the child process to
/// be re-executed.
///
/// Related:
/// * `addPrefixedFileArg` - same thing but prepends a string to the argument
/// * `addOutputFileArg` - for files generated by the child process
pub fn addFileArg(run: *Run, lp: std.Build.LazyPath) void {
    run.addPrefixedFileArg("", lp);
}

/// Appends an input file to the command line arguments prepended with a string.
///
/// For example, a prefix of "-F" will result in the child process seeing something
/// like this: "-Fexample.txt"
///
/// The child process will see a single argument, even if the prefix has
/// spaces. Modifications to this file will be detected as a cache miss in
/// subsequent builds, causing the child process to be re-executed.
///
/// Related:
/// * `addFileArg` - same thing but without the prefix
/// * `addOutputFileArg` - for files generated by the child process
pub fn addPrefixedFileArg(run: *Run, prefix: []const u8, lp: std.Build.LazyPath) void {
    const b = run.step.owner;

    const prefixed_file_source: PrefixedLazyPath = .{
        .prefix = b.dupe(prefix),
        .lazy_path = lp.dupe(b),
    };
    run.argv.append(b.allocator, .{ .lazy_path = prefixed_file_source }) catch @panic("OOM");
    lp.addStepDependencies(&run.step);
}

/// Provides a directory path as a command line argument to the command being run.
///
/// Returns a `std.Build.LazyPath` which can be used as inputs to other APIs
/// throughout the build system.
///
/// Related:
/// * `addPrefixedOutputDirectoryArg` - same thing but prepends a string to the argument
/// * `addDirectoryArg` - for input directories given to the child process
pub fn addOutputDirectoryArg(run: *Run, basename: []const u8) std.Build.LazyPath {
    return run.addPrefixedOutputDirectoryArg("", basename);
}

/// Provides a directory path as a command line argument to the command being run.
/// Asserts `basename` is not empty.
///
/// For example, a prefix of "-o" and basename of "output_dir" will result in
/// the child process seeing something like this: "-ozig-cache/.../output_dir"
///
/// The child process will see a single argument, regardless of whether the
/// prefix or basename have spaces.
///
/// The returned `std.Build.LazyPath` can be used as inputs to other APIs
/// throughout the build system.
///
/// Related:
/// * `addOutputDirectoryArg` - same thing but without the prefix
/// * `addDirectoryArg` - for input directories given to the child process
pub fn addPrefixedOutputDirectoryArg(
    run: *Run,
    prefix: []const u8,
    basename: []const u8,
) std.Build.LazyPath {
    if (basename.len == 0) @panic("basename must not be empty");
    const b = run.step.owner;

    const output = b.allocator.create(Output) catch @panic("OOM");
    output.* = .{
        .prefix = b.dupe(prefix),
        .basename = b.dupe(basename),
        .generated_file = .{ .step = &run.step },
    };
    run.argv.append(b.allocator, .{ .output_directory = output }) catch @panic("OOM");

    if (run.rename_step_with_output_arg) {
        run.setName(b.fmt("{s} ({s})", .{ run.step.name, basename }));
    }

    return .{ .generated = .{ .file = &output.generated_file } };
}

/// deprecated: use `addDirectoryArg`
pub const addDirectorySourceArg = addDirectoryArg;

pub fn addDirectoryArg(run: *Run, directory_source: std.Build.LazyPath) void {
    run.addPrefixedDirectoryArg("", directory_source);
}

// deprecated: use `addPrefixedDirectoryArg`
pub const addPrefixedDirectorySourceArg = addPrefixedDirectoryArg;

pub fn addPrefixedDirectoryArg(run: *Run, prefix: []const u8, directory_source: std.Build.LazyPath) void {
    const b = run.step.owner;

    const prefixed_directory_source: PrefixedLazyPath = .{
        .prefix = b.dupe(prefix),
        .lazy_path = directory_source.dupe(b),
    };
    run.argv.append(b.allocator, .{ .directory_source = prefixed_directory_source }) catch @panic("OOM");
    directory_source.addStepDependencies(&run.step);
}

/// Add a path argument to a dep file (.d) for the child process to write its
/// discovered additional dependencies.
/// Only one dep file argument is allowed by instance.
pub fn addDepFileOutputArg(run: *Run, basename: []const u8) std.Build.LazyPath {
    return run.addPrefixedDepFileOutputArg("", basename);
}

/// Add a prefixed path argument to a dep file (.d) for the child process to
/// write its discovered additional dependencies.
/// Only one dep file argument is allowed by instance.
pub fn addPrefixedDepFileOutputArg(run: *Run, prefix: []const u8, basename: []const u8) std.Build.LazyPath {
    const b = run.step.owner;
    assert(run.dep_output_file == null);

    const dep_file = b.allocator.create(Output) catch @panic("OOM");
    dep_file.* = .{
        .prefix = b.dupe(prefix),
        .basename = b.dupe(basename),
        .generated_file = .{ .step = &run.step },
    };

    run.dep_output_file = dep_file;

    run.argv.append(b.allocator, .{ .output_file = dep_file }) catch @panic("OOM");

    return .{ .generated = .{ .file = &dep_file.generated_file } };
}

pub fn addArg(run: *Run, arg: []const u8) void {
    const b = run.step.owner;
    run.argv.append(b.allocator, .{ .bytes = b.dupe(arg) }) catch @panic("OOM");
}

pub fn addArgs(run: *Run, args: []const []const u8) void {
    for (args) |arg| run.addArg(arg);
}

pub fn setStdIn(run: *Run, stdin: StdIn) void {
    switch (stdin) {
        .lazy_path => |lazy_path| lazy_path.addStepDependencies(&run.step),
        .bytes, .none => {},
    }
    run.stdin = stdin;
}

pub fn setCwd(run: *Run, cwd: Build.LazyPath) void {
    cwd.addStepDependencies(&run.step);
    run.cwd = cwd.dupe(run.step.owner);
}

pub fn clearEnvironment(run: *Run) void {
    const b = run.step.owner;
    const new_env_map = b.allocator.create(EnvMap) catch @panic("OOM");
    new_env_map.* = EnvMap.init(b.allocator);
    run.env_map = new_env_map;
}

pub fn addPathDir(run: *Run, search_path: []const u8) void {
    const b = run.step.owner;
    const env_map = getEnvMapInternal(run);

    const key = "PATH";
    const prev_path = env_map.get(key);

    if (prev_path) |pp| {
        const new_path = b.fmt("{s}" ++ [1]u8{fs.path.delimiter} ++ "{s}", .{ pp, search_path });
        env_map.put(key, new_path) catch @panic("OOM");
    } else {
        env_map.put(key, b.dupePath(search_path)) catch @panic("OOM");
    }
}

pub fn getEnvMap(run: *Run) *EnvMap {
    return getEnvMapInternal(run);
}

fn getEnvMapInternal(run: *Run) *EnvMap {
    const arena = run.step.owner.allocator;
    return run.env_map orelse {
        const env_map = arena.create(EnvMap) catch @panic("OOM");
        env_map.* = process.getEnvMap(arena) catch @panic("unhandled error");
        run.env_map = env_map;
        return env_map;
    };
}

pub fn setEnvironmentVariable(run: *Run, key: []const u8, value: []const u8) void {
    const b = run.step.owner;
    const env_map = run.getEnvMap();
    env_map.put(b.dupe(key), b.dupe(value)) catch @panic("unhandled error");
}

pub fn removeEnvironmentVariable(run: *Run, key: []const u8) void {
    run.getEnvMap().remove(key);
}

/// Adds a check for exact stderr match. Does not add any other checks.
pub fn expectStdErrEqual(run: *Run, bytes: []const u8) void {
    const new_check: StdIo.Check = .{ .expect_stderr_exact = run.step.owner.dupe(bytes) };
    run.addCheck(new_check);
}

/// Adds a check for exact stdout match as well as a check for exit code 0, if
/// there is not already an expected termination check.
pub fn expectStdOutEqual(run: *Run, bytes: []const u8) void {
    const new_check: StdIo.Check = .{ .expect_stdout_exact = run.step.owner.dupe(bytes) };
    run.addCheck(new_check);
    if (!run.hasTermCheck()) {
        run.expectExitCode(0);
    }
}

pub fn expectExitCode(run: *Run, code: u8) void {
    const new_check: StdIo.Check = .{ .expect_term = .{ .Exited = code } };
    run.addCheck(new_check);
}

pub fn hasTermCheck(run: Run) bool {
    for (run.stdio.check.items) |check| switch (check) {
        .expect_term => return true,
        else => continue,
    };
    return false;
}

pub fn addCheck(run: *Run, new_check: StdIo.Check) void {
    const b = run.step.owner;

    switch (run.stdio) {
        .infer_from_args => {
            run.stdio = .{ .check = .{} };
            run.stdio.check.append(b.allocator, new_check) catch @panic("OOM");
        },
        .check => |*checks| checks.append(b.allocator, new_check) catch @panic("OOM"),
        else => @panic("illegal call to addCheck: conflicting helper method calls. Suggest to directly set stdio field of Run instead"),
    }
}

pub fn captureStdErr(run: *Run) std.Build.LazyPath {
    assert(run.stdio != .inherit);

    if (run.captured_stderr) |output| return .{ .generated = .{ .file = &output.generated_file } };

    const output = run.step.owner.allocator.create(Output) catch @panic("OOM");
    output.* = .{
        .prefix = "",
        .basename = "stderr",
        .generated_file = .{ .step = &run.step },
    };
    run.captured_stderr = output;
    return .{ .generated = .{ .file = &output.generated_file } };
}

pub fn captureStdOut(run: *Run) std.Build.LazyPath {
    assert(run.stdio != .inherit);

    if (run.captured_stdout) |output| return .{ .generated = .{ .file = &output.generated_file } };

    const output = run.step.owner.allocator.create(Output) catch @panic("OOM");
    output.* = .{
        .prefix = "",
        .basename = "stdout",
        .generated_file = .{ .step = &run.step },
    };
    run.captured_stdout = output;
    return .{ .generated = .{ .file = &output.generated_file } };
}

/// Adds an additional input files that, when modified, indicates that this Run
/// step should be re-executed.
/// If the Run step is determined to have side-effects, the Run step is always
/// executed when it appears in the build graph, regardless of whether this
/// file has been modified.
pub fn addFileInput(self: *Run, file_input: std.Build.LazyPath) void {
    file_input.addStepDependencies(&self.step);
    self.file_inputs.append(self.step.owner.allocator, file_input.dupe(self.step.owner)) catch @panic("OOM");
}

/// Returns whether the Run step has side effects *other than* updating the output arguments.
fn hasSideEffects(run: Run) bool {
    if (run.has_side_effects) return true;
    return switch (run.stdio) {
        .infer_from_args => !run.hasAnyOutputArgs(),
        .inherit => true,
        .check => false,
        .zig_test => false,
    };
}

fn hasAnyOutputArgs(run: Run) bool {
    if (run.captured_stdout != null) return true;
    if (run.captured_stderr != null) return true;
    for (run.argv.items) |arg| switch (arg) {
        .output_file, .output_directory => return true,
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

const IndexedOutput = struct {
    index: usize,
    tag: @typeInfo(Arg).Union.tag_type.?,
    output: *Output,
};
fn make(step: *Step, prog_node: std.Progress.Node) !void {
    const b = step.owner;
    const arena = b.allocator;
    const run: *Run = @fieldParentPtr("step", step);
    const has_side_effects = run.hasSideEffects();

    var argv_list = std.ArrayList([]const u8).init(arena);
    var output_placeholders = std.ArrayList(IndexedOutput).init(arena);

    var man = b.graph.cache.obtain();
    defer man.deinit();

    for (run.argv.items) |arg| {
        switch (arg) {
            .bytes => |bytes| {
                try argv_list.append(bytes);
                man.hash.addBytes(bytes);
            },
            .lazy_path => |file| {
                const file_path = file.lazy_path.getPath2(b, step);
                try argv_list.append(b.fmt("{s}{s}", .{ file.prefix, file_path }));
                man.hash.addBytes(file.prefix);
                _ = try man.addFile(file_path, null);
            },
            .directory_source => |file| {
                const file_path = file.lazy_path.getPath2(b, step);
                try argv_list.append(b.fmt("{s}{s}", .{ file.prefix, file_path }));
                man.hash.addBytes(file.prefix);
                man.hash.addBytes(file_path);
            },
            .artifact => |artifact| {
                if (artifact.rootModuleTarget().os.tag == .windows) {
                    // On Windows we don't have rpaths so we have to add .dll search paths to PATH
                    run.addPathForDynLibs(artifact);
                }
                const file_path = artifact.installed_path orelse artifact.generated_bin.?.path.?; // the path is guaranteed to be set

                try argv_list.append(file_path);

                _ = try man.addFile(file_path, null);
            },
            .output_file, .output_directory => |output| {
                man.hash.addBytes(output.prefix);
                man.hash.addBytes(output.basename);
                // Add a placeholder into the argument list because we need the
                // manifest hash to be updated with all arguments before the
                // object directory is computed.
                try output_placeholders.append(.{
                    .index = argv_list.items.len,
                    .tag = arg,
                    .output = output,
                });
                _ = try argv_list.addOne();
            },
        }
    }

    switch (run.stdin) {
        .bytes => |bytes| {
            man.hash.addBytes(bytes);
        },
        .lazy_path => |lazy_path| {
            const file_path = lazy_path.getPath2(b, step);
            _ = try man.addFile(file_path, null);
        },
        .none => {},
    }

    if (run.captured_stdout) |output| {
        man.hash.addBytes(output.basename);
    }

    if (run.captured_stderr) |output| {
        man.hash.addBytes(output.basename);
    }

    hashStdIo(&man.hash, run.stdio);

    for (run.extra_file_dependencies) |file_path| {
        _ = try man.addFile(b.pathFromRoot(file_path), null);
    }
    for (run.file_inputs.items) |lazy_path| {
        _ = try man.addFile(lazy_path.getPath2(b, step), null);
    }

    if (!has_side_effects and try step.cacheHit(&man)) {
        // cache hit, skip running command
        const digest = man.final();

        try populateGeneratedPaths(
            arena,
            output_placeholders.items,
            run.captured_stdout,
            run.captured_stderr,
            b.cache_root,
            &digest,
        );

        step.result_cached = true;
        return;
    }

    const dep_output_file = run.dep_output_file orelse {
        // We already know the final output paths, use them directly.
        const digest = if (has_side_effects)
            man.hash.final()
        else
            man.final();

        try populateGeneratedPaths(
            arena,
            output_placeholders.items,
            run.captured_stdout,
            run.captured_stderr,
            b.cache_root,
            &digest,
        );

        const output_dir_path = "o" ++ fs.path.sep_str ++ &digest;
        for (output_placeholders.items) |placeholder| {
            const output_sub_path = b.pathJoin(&.{ output_dir_path, placeholder.output.basename });
            const output_sub_dir_path = switch (placeholder.tag) {
                .output_file => fs.path.dirname(output_sub_path).?,
                .output_directory => output_sub_path,
                else => unreachable,
            };
            b.cache_root.handle.makePath(output_sub_dir_path) catch |err| {
                return step.fail("unable to make path '{}{s}': {s}", .{
                    b.cache_root, output_sub_dir_path, @errorName(err),
                });
            };
            const output_path = placeholder.output.generated_file.path.?;
            argv_list.items[placeholder.index] = if (placeholder.output.prefix.len == 0)
                output_path
            else
                b.fmt("{s}{s}", .{ placeholder.output.prefix, output_path });
        }

        try runCommand(run, argv_list.items, has_side_effects, output_dir_path, prog_node);
        if (!has_side_effects) try step.writeManifest(&man);
        return;
    };

    // We do not know the final output paths yet, use temp paths to run the command.
    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_path = "tmp" ++ fs.path.sep_str ++ std.Build.hex64(rand_int);

    for (output_placeholders.items) |placeholder| {
        const output_components = .{ tmp_dir_path, placeholder.output.basename };
        const output_sub_path = b.pathJoin(&output_components);
        const output_sub_dir_path = switch (placeholder.tag) {
            .output_file => fs.path.dirname(output_sub_path).?,
            .output_directory => output_sub_path,
            else => unreachable,
        };
        b.cache_root.handle.makePath(output_sub_dir_path) catch |err| {
            return step.fail("unable to make path '{}{s}': {s}", .{
                b.cache_root, output_sub_dir_path, @errorName(err),
            });
        };
        const output_path = try b.cache_root.join(arena, &output_components);
        placeholder.output.generated_file.path = output_path;
        argv_list.items[placeholder.index] = if (placeholder.output.prefix.len == 0)
            output_path
        else
            b.fmt("{s}{s}", .{ placeholder.output.prefix, output_path });
    }

    try runCommand(run, argv_list.items, has_side_effects, tmp_dir_path, prog_node);

    const dep_file_dir = std.fs.cwd();
    const dep_file_basename = dep_output_file.generated_file.getPath();
    if (has_side_effects)
        try man.addDepFile(dep_file_dir, dep_file_basename)
    else
        try man.addDepFilePost(dep_file_dir, dep_file_basename);

    const digest = if (has_side_effects)
        man.hash.final()
    else
        man.final();

    const any_output = output_placeholders.items.len > 0 or
        run.captured_stdout != null or run.captured_stderr != null;

    // Rename into place
    if (any_output) {
        const o_sub_path = "o" ++ fs.path.sep_str ++ &digest;

        b.cache_root.handle.rename(tmp_dir_path, o_sub_path) catch |err| {
            if (err == error.PathAlreadyExists) {
                b.cache_root.handle.deleteTree(o_sub_path) catch |del_err| {
                    return step.fail("unable to remove dir '{}'{s}: {s}", .{
                        b.cache_root,
                        tmp_dir_path,
                        @errorName(del_err),
                    });
                };
                b.cache_root.handle.rename(tmp_dir_path, o_sub_path) catch |retry_err| {
                    return step.fail("unable to rename dir '{}{s}' to '{}{s}': {s}", .{
                        b.cache_root,          tmp_dir_path,
                        b.cache_root,          o_sub_path,
                        @errorName(retry_err),
                    });
                };
            } else {
                return step.fail("unable to rename dir '{}{s}' to '{}{s}': {s}", .{
                    b.cache_root,    tmp_dir_path,
                    b.cache_root,    o_sub_path,
                    @errorName(err),
                });
            }
        };
    }

    if (!has_side_effects) try step.writeManifest(&man);

    try populateGeneratedPaths(
        arena,
        output_placeholders.items,
        run.captured_stdout,
        run.captured_stderr,
        b.cache_root,
        &digest,
    );
}

fn populateGeneratedPaths(
    arena: std.mem.Allocator,
    output_placeholders: []const IndexedOutput,
    captured_stdout: ?*Output,
    captured_stderr: ?*Output,
    cache_root: Build.Cache.Directory,
    digest: *const Build.Cache.HexDigest,
) !void {
    for (output_placeholders) |placeholder| {
        placeholder.output.generated_file.path = try cache_root.join(arena, &.{
            "o", digest, placeholder.output.basename,
        });
    }

    if (captured_stdout) |output| {
        output.generated_file.path = try cache_root.join(arena, &.{
            "o", digest, output.basename,
        });
    }

    if (captured_stderr) |output| {
        output.generated_file.path = try cache_root.join(arena, &.{
            "o", digest, output.basename,
        });
    }
}

fn formatTerm(
    term: ?std.process.Child.Term,
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
fn fmtTerm(term: ?std.process.Child.Term) std.fmt.Formatter(formatTerm) {
    return .{ .data = term };
}

fn termMatches(expected: ?std.process.Child.Term, actual: std.process.Child.Term) bool {
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

fn runCommand(
    run: *Run,
    argv: []const []const u8,
    has_side_effects: bool,
    output_dir_path: []const u8,
    prog_node: std.Progress.Node,
) !void {
    const step = &run.step;
    const b = step.owner;
    const arena = b.allocator;

    const cwd: ?[]const u8 = if (run.cwd) |lazy_cwd| lazy_cwd.getPath2(b, step) else null;

    try step.handleChildProcUnsupported(cwd, argv);
    try Step.handleVerbose2(step.owner, cwd, run.env_map, argv);

    const allow_skip = switch (run.stdio) {
        .check, .zig_test => run.skip_foreign_checks,
        else => false,
    };

    var interp_argv = std.ArrayList([]const u8).init(b.allocator);
    defer interp_argv.deinit();

    const result = spawnChildAndCollect(run, argv, has_side_effects, prog_node) catch |err| term: {
        // InvalidExe: cpu arch mismatch
        // FileNotFound: can happen with a wrong dynamic linker path
        if (err == error.InvalidExe or err == error.FileNotFound) interpret: {
            // TODO: learn the target from the binary directly rather than from
            // relying on it being a Compile step. This will make this logic
            // work even for the edge case that the binary was produced by a
            // third party.
            const exe = switch (run.argv.items[0]) {
                .artifact => |exe| exe,
                else => break :interpret,
            };
            switch (exe.kind) {
                .exe, .@"test" => {},
                else => break :interpret,
            }

            const need_cross_glibc = exe.rootModuleTarget().isGnuLibC() and
                exe.is_linking_libc;
            const other_target = exe.root_module.resolved_target.?.result;
            switch (std.zig.system.getExternalExecutor(b.host.result, &other_target, .{
                .qemu_fixes_dl = need_cross_glibc and b.glibc_runtimes_dir != null,
                .link_libc = exe.is_linking_libc,
            })) {
                .native, .rosetta => {
                    if (allow_skip) return error.MakeSkipped;
                    break :interpret;
                },
                .wine => |bin_name| {
                    if (b.enable_wine) {
                        try interp_argv.append(bin_name);
                        try interp_argv.appendSlice(argv);
                    } else {
                        return failForeign(run, "-fwine", argv[0], exe);
                    }
                },
                .qemu => |bin_name| {
                    if (b.enable_qemu) {
                        const glibc_dir_arg = if (need_cross_glibc)
                            b.glibc_runtimes_dir orelse
                                return failForeign(run, "--glibc-runtimes", argv[0], exe)
                        else
                            null;

                        try interp_argv.append(bin_name);

                        if (glibc_dir_arg) |dir| {
                            // TODO look into making this a call to `linuxTriple`. This
                            // needs the directory to be called "i686" rather than
                            // "x86" which is why we do it manually here.
                            const fmt_str = "{s}" ++ fs.path.sep_str ++ "{s}-{s}-{s}";
                            const cpu_arch = exe.rootModuleTarget().cpu.arch;
                            const os_tag = exe.rootModuleTarget().os.tag;
                            const abi = exe.rootModuleTarget().abi;
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

                        try interp_argv.appendSlice(argv);
                    } else {
                        return failForeign(run, "-fqemu", argv[0], exe);
                    }
                },
                .darling => |bin_name| {
                    if (b.enable_darling) {
                        try interp_argv.append(bin_name);
                        try interp_argv.appendSlice(argv);
                    } else {
                        return failForeign(run, "-fdarling", argv[0], exe);
                    }
                },
                .wasmtime => |bin_name| {
                    if (b.enable_wasmtime) {
                        try interp_argv.append(bin_name);
                        try interp_argv.append("--dir=.");
                        try interp_argv.append(argv[0]);
                        try interp_argv.append("--");
                        try interp_argv.appendSlice(argv[1..]);
                    } else {
                        return failForeign(run, "-fwasmtime", argv[0], exe);
                    }
                },
                .bad_dl => |foreign_dl| {
                    if (allow_skip) return error.MakeSkipped;

                    const host_dl = b.host.result.dynamic_linker.get() orelse "(none)";

                    return step.fail(
                        \\the host system is unable to execute binaries from the target
                        \\  because the host dynamic linker is '{s}',
                        \\  while the target dynamic linker is '{s}'.
                        \\  consider setting the dynamic linker or enabling skip_foreign_checks in the Run step
                    , .{ host_dl, foreign_dl });
                },
                .bad_os_or_cpu => {
                    if (allow_skip) return error.MakeSkipped;

                    const host_name = try b.host.result.zigTriple(b.allocator);
                    const foreign_name = try exe.rootModuleTarget().zigTriple(b.allocator);

                    return step.fail("the host system ({s}) is unable to execute binaries from the target ({s})", .{
                        host_name, foreign_name,
                    });
                },
            }

            if (exe.rootModuleTarget().os.tag == .windows) {
                // On Windows we don't have rpaths so we have to add .dll search paths to PATH
                run.addPathForDynLibs(exe);
            }

            try Step.handleVerbose2(step.owner, cwd, run.env_map, interp_argv.items);

            break :term spawnChildAndCollect(run, interp_argv.items, has_side_effects, prog_node) catch |e| {
                if (!run.failing_to_execute_foreign_is_an_error) return error.MakeSkipped;

                return step.fail("unable to spawn interpreter {s}: {s}", .{
                    interp_argv.items[0], @errorName(e),
                });
            };
        }

        return step.fail("unable to spawn {s}: {s}", .{ argv[0], @errorName(err) });
    };

    step.result_duration_ns = result.elapsed_ns;
    step.result_peak_rss = result.peak_rss;
    step.test_results = result.stdio.test_results;

    // Capture stdout and stderr to GeneratedFile objects.
    const Stream = struct {
        captured: ?*Output,
        bytes: ?[]const u8,
    };
    for ([_]Stream{
        .{
            .captured = run.captured_stdout,
            .bytes = result.stdio.stdout,
        },
        .{
            .captured = run.captured_stderr,
            .bytes = result.stdio.stderr,
        },
    }) |stream| {
        if (stream.captured) |output| {
            const output_components = .{ output_dir_path, output.basename };
            const output_path = try b.cache_root.join(arena, &output_components);
            output.generated_file.path = output_path;

            const sub_path = b.pathJoin(&output_components);
            const sub_path_dirname = fs.path.dirname(sub_path).?;
            b.cache_root.handle.makePath(sub_path_dirname) catch |err| {
                return step.fail("unable to make path '{}{s}': {s}", .{
                    b.cache_root, sub_path_dirname, @errorName(err),
                });
            };
            b.cache_root.handle.writeFile(.{ .sub_path = sub_path, .data = stream.bytes.? }) catch |err| {
                return step.fail("unable to write file '{}{s}': {s}", .{
                    b.cache_root, sub_path, @errorName(err),
                });
            };
        }
    }

    const final_argv = if (interp_argv.items.len == 0) argv else interp_argv.items;

    switch (run.stdio) {
        .check => |checks| for (checks.items) |check| switch (check) {
            .expect_stderr_exact => |expected_bytes| {
                if (!mem.eql(u8, expected_bytes, result.stdio.stderr.?)) {
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
                        result.stdio.stderr.?,
                        try Step.allocPrintCmd(arena, cwd, final_argv),
                    });
                }
            },
            .expect_stderr_match => |match| {
                if (mem.indexOf(u8, result.stdio.stderr.?, match) == null) {
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
                        result.stdio.stderr.?,
                        try Step.allocPrintCmd(arena, cwd, final_argv),
                    });
                }
            },
            .expect_stdout_exact => |expected_bytes| {
                if (!mem.eql(u8, expected_bytes, result.stdio.stdout.?)) {
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
                        result.stdio.stdout.?,
                        try Step.allocPrintCmd(arena, cwd, final_argv),
                    });
                }
            },
            .expect_stdout_match => |match| {
                if (mem.indexOf(u8, result.stdio.stdout.?, match) == null) {
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
                        result.stdio.stdout.?,
                        try Step.allocPrintCmd(arena, cwd, final_argv),
                    });
                }
            },
            .expect_term => |expected_term| {
                if (!termMatches(expected_term, result.term)) {
                    return step.fail("the following command {} (expected {}):\n{s}", .{
                        fmtTerm(result.term),
                        fmtTerm(expected_term),
                        try Step.allocPrintCmd(arena, cwd, final_argv),
                    });
                }
            },
        },
        .zig_test => {
            const prefix: []const u8 = p: {
                if (result.stdio.test_metadata) |tm| {
                    if (tm.next_index > 0 and tm.next_index <= tm.names.len) {
                        const name = tm.testName(tm.next_index - 1);
                        break :p b.fmt("while executing test '{s}', ", .{name});
                    }
                }
                break :p "";
            };
            const expected_term: std.process.Child.Term = .{ .Exited = 0 };
            if (!termMatches(expected_term, result.term)) {
                return step.fail("{s}the following command {} (expected {}):\n{s}", .{
                    prefix,
                    fmtTerm(result.term),
                    fmtTerm(expected_term),
                    try Step.allocPrintCmd(arena, cwd, final_argv),
                });
            }
            if (!result.stdio.test_results.isSuccess()) {
                return step.fail(
                    "{s}the following test command failed:\n{s}",
                    .{ prefix, try Step.allocPrintCmd(arena, cwd, final_argv) },
                );
            }
        },
        else => {
            try step.handleChildProcessTerm(result.term, cwd, final_argv);
        },
    }
}

const ChildProcResult = struct {
    term: std.process.Child.Term,
    elapsed_ns: u64,
    peak_rss: usize,

    stdio: StdIoResult,
};

fn spawnChildAndCollect(
    run: *Run,
    argv: []const []const u8,
    has_side_effects: bool,
    prog_node: std.Progress.Node,
) !ChildProcResult {
    const b = run.step.owner;
    const arena = b.allocator;

    var child = std.process.Child.init(argv, arena);
    if (run.cwd) |lazy_cwd| {
        child.cwd = lazy_cwd.getPath2(b, &run.step);
    } else {
        child.cwd = b.build_root.path;
        child.cwd_dir = b.build_root.handle;
    }
    child.env_map = run.env_map orelse &b.graph.env_map;
    child.request_resource_usage_statistics = true;

    child.stdin_behavior = switch (run.stdio) {
        .infer_from_args => if (has_side_effects) .Inherit else .Ignore,
        .inherit => .Inherit,
        .check => .Ignore,
        .zig_test => .Pipe,
    };
    child.stdout_behavior = switch (run.stdio) {
        .infer_from_args => if (has_side_effects) .Inherit else .Ignore,
        .inherit => .Inherit,
        .check => |checks| if (checksContainStdout(checks.items)) .Pipe else .Ignore,
        .zig_test => .Pipe,
    };
    child.stderr_behavior = switch (run.stdio) {
        .infer_from_args => if (has_side_effects) .Inherit else .Pipe,
        .inherit => .Inherit,
        .check => .Pipe,
        .zig_test => .Pipe,
    };
    if (run.captured_stdout != null) child.stdout_behavior = .Pipe;
    if (run.captured_stderr != null) child.stderr_behavior = .Pipe;
    if (run.stdin != .none) {
        assert(run.stdio != .inherit);
        child.stdin_behavior = .Pipe;
    }

    const inherit = child.stdout_behavior == .Inherit or child.stderr_behavior == .Inherit;

    if (run.stdio != .zig_test and !run.disable_zig_progress and !inherit) {
        child.progress_node = prog_node;
    }

    const term, const result, const elapsed_ns = t: {
        if (inherit) std.debug.lockStdErr();
        defer if (inherit) std.debug.unlockStdErr();

        try child.spawn();
        var timer = try std.time.Timer.start();

        const result = if (run.stdio == .zig_test)
            evalZigTest(run, &child, prog_node)
        else
            evalGeneric(run, &child);

        break :t .{ try child.wait(), result, timer.read() };
    };

    return .{
        .stdio = try result,
        .term = term,
        .elapsed_ns = elapsed_ns,
        .peak_rss = child.resource_usage_statistics.getMaxRss() orelse 0,
    };
}

const StdIoResult = struct {
    stdout: ?[]const u8,
    stderr: ?[]const u8,
    test_results: Step.TestResults,
    test_metadata: ?TestMetadata,
};

fn evalZigTest(
    run: *Run,
    child: *std.process.Child,
    prog_node: std.Progress.Node,
) !StdIoResult {
    const gpa = run.step.owner.allocator;
    const arena = run.step.owner.allocator;

    var poller = std.io.poll(gpa, enum { stdout, stderr }, .{
        .stdout = child.stdout.?,
        .stderr = child.stderr.?,
    });
    defer poller.deinit();

    try sendMessage(child.stdin.?, .query_test_metadata);

    const Header = std.zig.Server.Message.Header;

    const stdout = poller.fifo(.stdout);
    const stderr = poller.fifo(.stderr);

    var fail_count: u32 = 0;
    var skip_count: u32 = 0;
    var leak_count: u32 = 0;
    var test_count: u32 = 0;
    var log_err_count: u32 = 0;

    var metadata: ?TestMetadata = null;

    var sub_prog_node: ?std.Progress.Node = null;
    defer if (sub_prog_node) |n| n.end();

    poll: while (true) {
        while (stdout.readableLength() < @sizeOf(Header)) {
            if (!(try poller.poll())) break :poll;
        }
        const header = stdout.reader().readStruct(Header) catch unreachable;
        while (stdout.readableLength() < header.bytes_len) {
            if (!(try poller.poll())) break :poll;
        }
        const body = stdout.readableSliceOfLen(header.bytes_len);

        switch (header.tag) {
            .zig_version => {
                if (!std.mem.eql(u8, builtin.zig_version_string, body)) {
                    return run.step.fail(
                        "zig version mismatch build runner vs compiler: '{s}' vs '{s}'",
                        .{ builtin.zig_version_string, body },
                    );
                }
            },
            .test_metadata => {
                const TmHdr = std.zig.Server.Message.TestMetadata;
                const tm_hdr = @as(*align(1) const TmHdr, @ptrCast(body));
                test_count = tm_hdr.tests_len;

                const names_bytes = body[@sizeOf(TmHdr)..][0 .. test_count * @sizeOf(u32)];
                const expected_panic_msgs_bytes = body[@sizeOf(TmHdr) + names_bytes.len ..][0 .. test_count * @sizeOf(u32)];
                const string_bytes = body[@sizeOf(TmHdr) + names_bytes.len + expected_panic_msgs_bytes.len ..][0..tm_hdr.string_bytes_len];

                const names = std.mem.bytesAsSlice(u32, names_bytes);
                const expected_panic_msgs = std.mem.bytesAsSlice(u32, expected_panic_msgs_bytes);
                const names_aligned = try arena.alloc(u32, names.len);
                for (names_aligned, names) |*dest, src| dest.* = src;

                const expected_panic_msgs_aligned = try arena.alloc(u32, expected_panic_msgs.len);
                for (expected_panic_msgs_aligned, expected_panic_msgs) |*dest, src| dest.* = src;

                prog_node.setEstimatedTotalItems(names.len);
                metadata = .{
                    .string_bytes = try arena.dupe(u8, string_bytes),
                    .names = names_aligned,
                    .expected_panic_msgs = expected_panic_msgs_aligned,
                    .next_index = 0,
                    .prog_node = prog_node,
                };

                try requestNextTest(child.stdin.?, &metadata.?, &sub_prog_node);
            },
            .test_results => {
                const md = metadata.?;

                const TrHdr = std.zig.Server.Message.TestResults;
                const tr_hdr = @as(*align(1) const TrHdr, @ptrCast(body));
                fail_count +|= @intFromBool(tr_hdr.flags.fail);
                skip_count +|= @intFromBool(tr_hdr.flags.skip);
                leak_count +|= @intFromBool(tr_hdr.flags.leak);
                log_err_count +|= tr_hdr.flags.log_err_count;

                if (tr_hdr.flags.fail or tr_hdr.flags.leak or tr_hdr.flags.log_err_count > 0) {
                    const name = std.mem.sliceTo(md.string_bytes[md.names[tr_hdr.index]..], 0);
                    const orig_msg = stderr.readableSlice(0);
                    defer stderr.discard(orig_msg.len);
                    const msg = std.mem.trim(u8, orig_msg, "\n");
                    const label = if (tr_hdr.flags.fail)
                        "failed"
                    else if (tr_hdr.flags.leak)
                        "leaked"
                    else if (tr_hdr.flags.log_err_count > 0)
                        "logged errors"
                    else
                        unreachable;
                    if (msg.len > 0) {
                        try run.step.addError("'{s}' {s}: {s}", .{ name, label, msg });
                    } else {
                        try run.step.addError("'{s}' {s}", .{ name, label });
                    }
                }

                try requestNextTest(child.stdin.?, &metadata.?, &sub_prog_node);
            },
            else => {}, // ignore other messages
        }

        stdout.discard(body.len);
    }

    if (stderr.readableLength() > 0) {
        const msg = std.mem.trim(u8, try stderr.toOwnedSlice(), "\n");
        if (msg.len > 0) run.step.result_stderr = msg;
    }

    // Send EOF to stdin.
    child.stdin.?.close();
    child.stdin = null;

    return .{
        .stdout = null,
        .stderr = null,
        .test_results = .{
            .test_count = test_count,
            .fail_count = fail_count,
            .skip_count = skip_count,
            .leak_count = leak_count,
            .log_err_count = log_err_count,
        },
        .test_metadata = metadata,
    };
}

const TestMetadata = struct {
    names: []const u32,
    expected_panic_msgs: []const u32,
    string_bytes: []const u8,
    next_index: u32,
    prog_node: std.Progress.Node,

    fn testName(tm: TestMetadata, index: u32) []const u8 {
        return std.mem.sliceTo(tm.string_bytes[tm.names[index]..], 0);
    }
};

fn requestNextTest(in: fs.File, metadata: *TestMetadata, sub_prog_node: *?std.Progress.Node) !void {
    while (metadata.next_index < metadata.names.len) {
        const i = metadata.next_index;
        metadata.next_index += 1;

        if (metadata.expected_panic_msgs[i] != 0) continue;

        const name = metadata.testName(i);
        if (sub_prog_node.*) |n| n.end();
        sub_prog_node.* = metadata.prog_node.start(name, 0);

        try sendRunTestMessage(in, i);
        return;
    } else {
        try sendMessage(in, .exit);
    }
}

fn sendMessage(file: std.fs.File, tag: std.zig.Client.Message.Tag) !void {
    const header: std.zig.Client.Message.Header = .{
        .tag = tag,
        .bytes_len = 0,
    };
    try file.writeAll(std.mem.asBytes(&header));
}

fn sendRunTestMessage(file: std.fs.File, index: u32) !void {
    const header: std.zig.Client.Message.Header = .{
        .tag = .run_test,
        .bytes_len = 4,
    };
    const full_msg = std.mem.asBytes(&header) ++ std.mem.asBytes(&index);
    try file.writeAll(full_msg);
}

fn evalGeneric(run: *Run, child: *std.process.Child) !StdIoResult {
    const b = run.step.owner;
    const arena = b.allocator;

    switch (run.stdin) {
        .bytes => |bytes| {
            child.stdin.?.writeAll(bytes) catch |err| {
                return run.step.fail("unable to write stdin: {s}", .{@errorName(err)});
            };
            child.stdin.?.close();
            child.stdin = null;
        },
        .lazy_path => |lazy_path| {
            const path = lazy_path.getPath2(b, &run.step);
            const file = b.build_root.handle.openFile(path, .{}) catch |err| {
                return run.step.fail("unable to open stdin file: {s}", .{@errorName(err)});
            };
            defer file.close();
            child.stdin.?.writeFileAll(file, .{}) catch |err| {
                return run.step.fail("unable to write file to stdin: {s}", .{@errorName(err)});
            };
            child.stdin.?.close();
            child.stdin = null;
        },
        .none => {},
    }

    var stdout_bytes: ?[]const u8 = null;
    var stderr_bytes: ?[]const u8 = null;

    if (child.stdout) |stdout| {
        if (child.stderr) |stderr| {
            var poller = std.io.poll(arena, enum { stdout, stderr }, .{
                .stdout = stdout,
                .stderr = stderr,
            });
            defer poller.deinit();

            while (try poller.poll()) {
                if (poller.fifo(.stdout).count > run.max_stdio_size)
                    return error.StdoutStreamTooLong;
                if (poller.fifo(.stderr).count > run.max_stdio_size)
                    return error.StderrStreamTooLong;
            }

            stdout_bytes = try poller.fifo(.stdout).toOwnedSlice();
            stderr_bytes = try poller.fifo(.stderr).toOwnedSlice();
        } else {
            stdout_bytes = try stdout.reader().readAllAlloc(arena, run.max_stdio_size);
        }
    } else if (child.stderr) |stderr| {
        stderr_bytes = try stderr.reader().readAllAlloc(arena, run.max_stdio_size);
    }

    if (stderr_bytes) |bytes| if (bytes.len > 0) {
        // Treat stderr as an error message.
        const stderr_is_diagnostic = run.captured_stderr == null and switch (run.stdio) {
            .check => |checks| !checksContainStderr(checks.items),
            else => true,
        };
        if (stderr_is_diagnostic) {
            run.step.result_stderr = bytes;
        }
    };

    return .{
        .stdout = stdout_bytes,
        .stderr = stderr_bytes,
        .test_results = .{},
        .test_metadata = null,
    };
}

fn addPathForDynLibs(run: *Run, artifact: *Step.Compile) void {
    const b = run.step.owner;
    var it = artifact.root_module.iterateDependencies(artifact, true);
    while (it.next()) |item| {
        const other = item.compile.?;
        if (item.module == &other.root_module) {
            if (item.module.resolved_target.?.result.os.tag == .windows and
                other.isDynamicLibrary())
            {
                addPathDir(run, fs.path.dirname(other.getEmittedBin().getPath2(b, &run.step)).?);
            }
        }
    }
}

fn failForeign(
    run: *Run,
    suggested_flag: []const u8,
    argv0: []const u8,
    exe: *Step.Compile,
) error{ MakeFailed, MakeSkipped, OutOfMemory } {
    switch (run.stdio) {
        .check, .zig_test => {
            if (run.skip_foreign_checks)
                return error.MakeSkipped;

            const b = run.step.owner;
            const host_name = try b.host.result.zigTriple(b.allocator);
            const foreign_name = try exe.rootModuleTarget().zigTriple(b.allocator);

            return run.step.fail(
                \\unable to spawn foreign binary '{s}' ({s}) on host system ({s})
                \\  consider using {s} or enabling skip_foreign_checks in the Run step
            , .{ argv0, foreign_name, host_name, suggested_flag });
        },
        else => {
            return run.step.fail("unable to spawn foreign binary '{s}'", .{argv0});
        },
    }
}

fn hashStdIo(hh: *std.Build.Cache.HashHelper, stdio: StdIo) void {
    switch (stdio) {
        .infer_from_args, .inherit, .zig_test => {},
        .check => |checks| for (checks.items) |check| {
            hh.add(@as(std.meta.Tag(StdIo.Check), check));
            switch (check) {
                .expect_stderr_exact,
                .expect_stderr_match,
                .expect_stdout_exact,
                .expect_stdout_match,
                => |s| hh.addBytes(s),

                .expect_term => |term| {
                    hh.add(@as(std.meta.Tag(std.process.Child.Term), term));
                    switch (term) {
                        .Exited => |x| hh.add(x),
                        .Signal, .Stopped, .Unknown => |x| hh.add(x),
                    }
                },
            }
        },
    }
}
