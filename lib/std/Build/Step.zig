id: Id,
name: []const u8,
owner: *Build,
makeFn: MakeFn,

dependencies: std.ArrayList(*Step),
/// This field is empty during execution of the user's build script, and
/// then populated during dependency loop checking in the build runner.
dependants: std.ArrayListUnmanaged(*Step),
state: State,
/// Set this field to declare an upper bound on the amount of bytes of memory it will
/// take to run the step. Zero means no limit.
///
/// The idea to annotate steps that might use a high amount of RAM with an
/// upper bound. For example, perhaps a particular set of unit tests require 4
/// GiB of RAM, and those tests will be run under 4 different build
/// configurations at once. This would potentially require 16 GiB of memory on
/// the system if all 4 steps executed simultaneously, which could easily be
/// greater than what is actually available, potentially causing the system to
/// crash when using `zig build` at the default concurrency level.
///
/// This field causes the build runner to do two things:
/// 1. ulimit child processes, so that they will fail if it would exceed this
/// memory limit. This serves to enforce that this upper bound value is
/// correct.
/// 2. Ensure that the set of concurrent steps at any given time have a total
/// max_rss value that does not exceed the `max_total_rss` value of the build
/// runner. This value is configurable on the command line, and defaults to the
/// total system memory available.
max_rss: usize,

result_error_msgs: std.ArrayListUnmanaged([]const u8),
result_error_bundle: std.zig.ErrorBundle,
result_stderr: []const u8,
result_cached: bool,
result_duration_ns: ?u64,
/// 0 means unavailable or not reported.
result_peak_rss: usize,
test_results: TestResults,

/// The return address associated with creation of this step that can be useful
/// to print along with debugging messages.
debug_stack_trace: []usize,

pub const TestResults = struct {
    fail_count: u32 = 0,
    skip_count: u32 = 0,
    leak_count: u32 = 0,
    log_err_count: u32 = 0,
    test_count: u32 = 0,

    pub fn isSuccess(tr: TestResults) bool {
        return tr.fail_count == 0 and tr.leak_count == 0 and tr.log_err_count == 0;
    }

    pub fn passCount(tr: TestResults) u32 {
        return tr.test_count - tr.fail_count - tr.skip_count;
    }
};

pub const MakeFn = *const fn (step: *Step, prog_node: *std.Progress.Node) anyerror!void;

pub const State = enum {
    precheck_unstarted,
    precheck_started,
    precheck_done,
    running,
    dependency_failure,
    success,
    failure,
    /// This state indicates that the step did not complete, however, it also did not fail,
    /// and it is safe to continue executing its dependencies.
    skipped,
    /// This step was skipped because it specified a max_rss that exceeded the runner's maximum.
    /// It is not safe to run its dependencies.
    skipped_oom,
};

pub const Id = enum {
    top_level,
    compile,
    install_artifact,
    install_file,
    install_dir,
    remove_dir,
    fmt,
    translate_c,
    write_file,
    run,
    check_file,
    check_object,
    config_header,
    objcopy,
    options,
    custom,

    pub fn Type(comptime id: Id) type {
        return switch (id) {
            .top_level => Build.TopLevelStep,
            .compile => Compile,
            .install_artifact => InstallArtifact,
            .install_file => InstallFile,
            .install_dir => InstallDir,
            .remove_dir => RemoveDir,
            .fmt => Fmt,
            .translate_c => TranslateC,
            .write_file => WriteFile,
            .run => Run,
            .check_file => CheckFile,
            .check_object => CheckObject,
            .config_header => ConfigHeader,
            .objcopy => ObjCopy,
            .options => Options,
            .custom => @compileError("no type available for custom step"),
        };
    }
};

pub const CheckFile = @import("Step/CheckFile.zig");
pub const CheckObject = @import("Step/CheckObject.zig");
pub const ConfigHeader = @import("Step/ConfigHeader.zig");
pub const Fmt = @import("Step/Fmt.zig");
pub const InstallArtifact = @import("Step/InstallArtifact.zig");
pub const InstallDir = @import("Step/InstallDir.zig");
pub const InstallFile = @import("Step/InstallFile.zig");
pub const ObjCopy = @import("Step/ObjCopy.zig");
pub const Compile = @import("Step/Compile.zig");
pub const Options = @import("Step/Options.zig");
pub const RemoveDir = @import("Step/RemoveDir.zig");
pub const Run = @import("Step/Run.zig");
pub const TranslateC = @import("Step/TranslateC.zig");
pub const WriteFile = @import("Step/WriteFile.zig");

pub const StepOptions = struct {
    id: Id,
    name: []const u8,
    owner: *Build,
    makeFn: MakeFn = makeNoOp,
    first_ret_addr: ?usize = null,
    max_rss: usize = 0,
};

pub fn init(options: StepOptions) Step {
    const arena = options.owner.allocator;

    return .{
        .id = options.id,
        .name = arena.dupe(u8, options.name) catch @panic("OOM"),
        .owner = options.owner,
        .makeFn = options.makeFn,
        .dependencies = std.ArrayList(*Step).init(arena),
        .dependants = .{},
        .state = .precheck_unstarted,
        .max_rss = options.max_rss,
        .debug_stack_trace = blk: {
            const addresses = arena.alloc(usize, options.owner.debug_stack_frames_count) catch @panic("OOM");
            @memset(addresses, 0);
            const first_ret_addr = options.first_ret_addr orelse @returnAddress();
            var stack_trace = std.builtin.StackTrace{
                .instruction_addresses = addresses,
                .index = 0,
            };
            std.debug.captureStackTrace(first_ret_addr, &stack_trace);
            break :blk addresses;
        },
        .result_error_msgs = .{},
        .result_error_bundle = std.zig.ErrorBundle.empty,
        .result_stderr = "",
        .result_cached = false,
        .result_duration_ns = null,
        .result_peak_rss = 0,
        .test_results = .{},
    };
}

/// If the Step's `make` function reports `error.MakeFailed`, it indicates they
/// have already reported the error. Otherwise, we add a simple error report
/// here.
pub fn make(s: *Step, prog_node: *std.Progress.Node) error{ MakeFailed, MakeSkipped }!void {
    const arena = s.owner.allocator;

    s.makeFn(s, prog_node) catch |err| switch (err) {
        error.MakeFailed => return error.MakeFailed,
        error.MakeSkipped => return error.MakeSkipped,
        else => {
            s.result_error_msgs.append(arena, @errorName(err)) catch @panic("OOM");
            return error.MakeFailed;
        },
    };

    if (!s.test_results.isSuccess()) {
        return error.MakeFailed;
    }

    if (s.max_rss != 0 and s.result_peak_rss > s.max_rss) {
        const msg = std.fmt.allocPrint(arena, "memory usage peaked at {d} bytes, exceeding the declared upper bound of {d}", .{
            s.result_peak_rss, s.max_rss,
        }) catch @panic("OOM");
        s.result_error_msgs.append(arena, msg) catch @panic("OOM");
        return error.MakeFailed;
    }
}

pub fn dependOn(step: *Step, other: *Step) void {
    step.dependencies.append(other) catch @panic("OOM");
}

pub fn getStackTrace(s: *Step) ?std.builtin.StackTrace {
    var len: usize = 0;
    while (len < s.debug_stack_trace.len and s.debug_stack_trace[len] != 0) {
        len += 1;
    }

    return if (len == 0) null else .{
        .instruction_addresses = s.debug_stack_trace,
        .index = len,
    };
}

fn makeNoOp(step: *Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;

    var all_cached = true;

    for (step.dependencies.items) |dep| {
        all_cached = all_cached and dep.result_cached;
    }

    step.result_cached = all_cached;
}

pub fn cast(step: *Step, comptime T: type) ?*T {
    if (step.id == T.base_id) {
        return @fieldParentPtr("step", step);
    }
    return null;
}

/// For debugging purposes, prints identifying information about this Step.
pub fn dump(step: *Step, file: std.fs.File) void {
    const w = file.writer();
    const tty_config = std.io.tty.detectConfig(file);
    const debug_info = std.debug.getSelfDebugInfo() catch |err| {
        w.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{
            @errorName(err),
        }) catch {};
        return;
    };
    const ally = debug_info.allocator;
    if (step.getStackTrace()) |stack_trace| {
        w.print("name: '{s}'. creation stack trace:\n", .{step.name}) catch {};
        std.debug.writeStackTrace(stack_trace, w, ally, debug_info, tty_config) catch |err| {
            w.print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch {};
            return;
        };
    } else {
        const field = "debug_stack_frames_count";
        comptime assert(@hasField(Build, field));
        tty_config.setColor(w, .yellow) catch {};
        w.print("name: '{s}'. no stack trace collected for this step, see std.Build." ++ field ++ "\n", .{step.name}) catch {};
        tty_config.setColor(w, .reset) catch {};
    }
}

const Step = @This();
const std = @import("../std.zig");
const Build = std.Build;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const builtin = @import("builtin");

pub fn evalChildProcess(s: *Step, argv: []const []const u8) !void {
    const arena = s.owner.allocator;

    try handleChildProcUnsupported(s, null, argv);
    try handleVerbose(s.owner, null, argv);

    const result = std.ChildProcess.run(.{
        .allocator = arena,
        .argv = argv,
    }) catch |err| return s.fail("unable to spawn {s}: {s}", .{ argv[0], @errorName(err) });

    if (result.stderr.len > 0) {
        try s.result_error_msgs.append(arena, result.stderr);
    }

    try handleChildProcessTerm(s, result.term, null, argv);
}

pub fn fail(step: *Step, comptime fmt: []const u8, args: anytype) error{ OutOfMemory, MakeFailed } {
    try step.addError(fmt, args);
    return error.MakeFailed;
}

pub fn addError(step: *Step, comptime fmt: []const u8, args: anytype) error{OutOfMemory}!void {
    const arena = step.owner.allocator;
    const msg = try std.fmt.allocPrint(arena, fmt, args);
    try step.result_error_msgs.append(arena, msg);
}

/// Assumes that argv contains `--listen=-` and that the process being spawned
/// is the zig compiler - the same version that compiled the build runner.
pub fn evalZigProcess(
    s: *Step,
    argv: []const []const u8,
    prog_node: *std.Progress.Node,
) !?[]const u8 {
    assert(argv.len != 0);
    const b = s.owner;
    const arena = b.allocator;
    const gpa = arena;

    try handleChildProcUnsupported(s, null, argv);
    try handleVerbose(s.owner, null, argv);

    var child = std.ChildProcess.init(argv, arena);
    child.env_map = &b.graph.env_map;
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.request_resource_usage_statistics = true;

    child.spawn() catch |err| return s.fail("unable to spawn {s}: {s}", .{
        argv[0], @errorName(err),
    });
    var timer = try std.time.Timer.start();

    var poller = std.io.poll(gpa, enum { stdout, stderr }, .{
        .stdout = child.stdout.?,
        .stderr = child.stderr.?,
    });
    defer poller.deinit();

    try sendMessage(child.stdin.?, .update);
    try sendMessage(child.stdin.?, .exit);

    const Header = std.zig.Server.Message.Header;
    var result: ?[]const u8 = null;

    var node_name: std.ArrayListUnmanaged(u8) = .{};
    defer node_name.deinit(gpa);
    var sub_prog_node = prog_node.start("", 0);
    defer sub_prog_node.end();

    const stdout = poller.fifo(.stdout);

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
                    return s.fail(
                        "zig version mismatch build runner vs compiler: '{s}' vs '{s}'",
                        .{ builtin.zig_version_string, body },
                    );
                }
            },
            .error_bundle => {
                const EbHdr = std.zig.Server.Message.ErrorBundle;
                const eb_hdr = @as(*align(1) const EbHdr, @ptrCast(body));
                const extra_bytes =
                    body[@sizeOf(EbHdr)..][0 .. @sizeOf(u32) * eb_hdr.extra_len];
                const string_bytes =
                    body[@sizeOf(EbHdr) + extra_bytes.len ..][0..eb_hdr.string_bytes_len];
                // TODO: use @ptrCast when the compiler supports it
                const unaligned_extra = std.mem.bytesAsSlice(u32, extra_bytes);
                const extra_array = try arena.alloc(u32, unaligned_extra.len);
                @memcpy(extra_array, unaligned_extra);
                s.result_error_bundle = .{
                    .string_bytes = try arena.dupe(u8, string_bytes),
                    .extra = extra_array,
                };
            },
            .progress => {
                node_name.clearRetainingCapacity();
                try node_name.appendSlice(gpa, body);
                sub_prog_node.setName(node_name.items);
            },
            .emit_bin_path => {
                const EbpHdr = std.zig.Server.Message.EmitBinPath;
                const ebp_hdr = @as(*align(1) const EbpHdr, @ptrCast(body));
                s.result_cached = ebp_hdr.flags.cache_hit;
                result = try arena.dupe(u8, body[@sizeOf(EbpHdr)..]);
            },
            else => {}, // ignore other messages
        }

        stdout.discard(body.len);
    }

    const stderr = poller.fifo(.stderr);
    if (stderr.readableLength() > 0) {
        try s.result_error_msgs.append(arena, try stderr.toOwnedSlice());
    }

    // Send EOF to stdin.
    child.stdin.?.close();
    child.stdin = null;

    const term = child.wait() catch |err| {
        return s.fail("unable to wait for {s}: {s}", .{ argv[0], @errorName(err) });
    };
    s.result_duration_ns = timer.read();
    s.result_peak_rss = child.resource_usage_statistics.getMaxRss() orelse 0;

    // Special handling for Compile step that is expecting compile errors.
    if (s.cast(Compile)) |compile| switch (term) {
        .Exited => {
            // Note that the exit code may be 0 in this case due to the
            // compiler server protocol.
            if (compile.expect_errors != null) {
                return error.NeedCompileErrorCheck;
            }
        },
        else => {},
    };

    try handleChildProcessTerm(s, term, null, argv);

    if (s.result_error_bundle.errorMessageCount() > 0) {
        return s.fail("the following command failed with {d} compilation errors:\n{s}", .{
            s.result_error_bundle.errorMessageCount(),
            try allocPrintCmd(arena, null, argv),
        });
    }

    return result;
}

fn sendMessage(file: std.fs.File, tag: std.zig.Client.Message.Tag) !void {
    const header: std.zig.Client.Message.Header = .{
        .tag = tag,
        .bytes_len = 0,
    };
    try file.writeAll(std.mem.asBytes(&header));
}

pub fn handleVerbose(
    b: *Build,
    opt_cwd: ?[]const u8,
    argv: []const []const u8,
) error{OutOfMemory}!void {
    return handleVerbose2(b, opt_cwd, null, argv);
}

pub fn handleVerbose2(
    b: *Build,
    opt_cwd: ?[]const u8,
    opt_env: ?*const std.process.EnvMap,
    argv: []const []const u8,
) error{OutOfMemory}!void {
    if (b.verbose) {
        // Intention of verbose is to print all sub-process command lines to
        // stderr before spawning them.
        const text = try allocPrintCmd2(b.allocator, opt_cwd, opt_env, argv);
        std.debug.print("{s}\n", .{text});
    }
}

pub inline fn handleChildProcUnsupported(
    s: *Step,
    opt_cwd: ?[]const u8,
    argv: []const []const u8,
) error{ OutOfMemory, MakeFailed }!void {
    if (!std.process.can_spawn) {
        return s.fail(
            "unable to execute the following command: host cannot spawn child processes\n{s}",
            .{try allocPrintCmd(s.owner.allocator, opt_cwd, argv)},
        );
    }
}

pub fn handleChildProcessTerm(
    s: *Step,
    term: std.ChildProcess.Term,
    opt_cwd: ?[]const u8,
    argv: []const []const u8,
) error{ MakeFailed, OutOfMemory }!void {
    const arena = s.owner.allocator;
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                return s.fail(
                    "the following command exited with error code {d}:\n{s}",
                    .{ code, try allocPrintCmd(arena, opt_cwd, argv) },
                );
            }
        },
        .Signal, .Stopped, .Unknown => {
            return s.fail(
                "the following command terminated unexpectedly:\n{s}",
                .{try allocPrintCmd(arena, opt_cwd, argv)},
            );
        },
    }
}

pub fn allocPrintCmd(
    arena: Allocator,
    opt_cwd: ?[]const u8,
    argv: []const []const u8,
) Allocator.Error![]u8 {
    return allocPrintCmd2(arena, opt_cwd, null, argv);
}

pub fn allocPrintCmd2(
    arena: Allocator,
    opt_cwd: ?[]const u8,
    opt_env: ?*const std.process.EnvMap,
    argv: []const []const u8,
) Allocator.Error![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    if (opt_cwd) |cwd| try buf.writer(arena).print("cd {s} && ", .{cwd});
    if (opt_env) |env| {
        const process_env_map = std.process.getEnvMap(arena) catch std.process.EnvMap.init(arena);
        var it = env.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            if (process_env_map.get(key)) |process_value| {
                if (std.mem.eql(u8, value, process_value)) continue;
            }
            try buf.writer(arena).print("{s}={s} ", .{ key, value });
        }
    }
    for (argv) |arg| {
        try buf.writer(arena).print("{s} ", .{arg});
    }
    return buf.toOwnedSlice(arena);
}

pub fn cacheHit(s: *Step, man: *std.Build.Cache.Manifest) !bool {
    s.result_cached = man.hit() catch |err| return failWithCacheError(s, man, err);
    return s.result_cached;
}

fn failWithCacheError(s: *Step, man: *const std.Build.Cache.Manifest, err: anyerror) anyerror {
    const i = man.failed_file_index orelse return err;
    const pp = man.files.keys()[i].prefixed_path;
    const prefix = man.cache.prefixes()[pp.prefix].path orelse "";
    return s.fail("{s}: {s}/{s}", .{ @errorName(err), prefix, pp.sub_path });
}

pub fn writeManifest(s: *Step, man: *std.Build.Cache.Manifest) !void {
    if (s.test_results.isSuccess()) {
        man.writeManifest() catch |err| {
            try s.addError("unable to write cache manifest: {s}", .{@errorName(err)});
        };
    }
}

test {
    _ = CheckFile;
    _ = CheckObject;
    _ = Fmt;
    _ = InstallArtifact;
    _ = InstallDir;
    _ = InstallFile;
    _ = ObjCopy;
    _ = Compile;
    _ = Options;
    _ = RemoveDir;
    _ = Run;
    _ = TranslateC;
    _ = WriteFile;
}
