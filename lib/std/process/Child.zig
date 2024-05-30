const std = @import("../std.zig");
const builtin = @import("builtin");
const unicode = std.unicode;
const fs = std.fs;
const process = std.process;
const File = std.fs.File;
const windows = std.os.windows;
const linux = std.os.linux;
const posix = std.posix;
const mem = std.mem;
const EnvMap = std.process.EnvMap;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const native_os = builtin.os.tag;
const Allocator = std.mem.Allocator;
const Child = @This();

pub const Id = switch (native_os) {
    .windows => windows.HANDLE,
    .wasi => void,
    else => posix.pid_t,
};

/// Available after calling `spawn()`. This becomes `undefined` after calling `wait()`.
/// On Windows this is the hProcess.
/// On POSIX this is the pid.
id: Id,
thread_handle: if (native_os == .windows) windows.HANDLE else void,

allocator: mem.Allocator,

/// The writing end of the child process's standard input pipe.
/// Usage requires `stdin_behavior == StdIo.Pipe`.
/// Available after calling `spawn()`.
stdin: ?File,

/// The reading end of the child process's standard output pipe.
/// Usage requires `stdout_behavior == StdIo.Pipe`.
/// Available after calling `spawn()`.
stdout: ?File,

/// The reading end of the child process's standard error pipe.
/// Usage requires `stderr_behavior == StdIo.Pipe`.
/// Available after calling `spawn()`.
stderr: ?File,

/// Terminated state of the child process.
/// Available after calling `wait()`.
term: ?(SpawnError!Term),

argv: []const []const u8,

/// Leave as null to use the current env map using the supplied allocator.
env_map: ?*const EnvMap,

stdin_behavior: StdIo,
stdout_behavior: StdIo,
stderr_behavior: StdIo,

/// Set to change the user id when spawning the child process.
uid: if (native_os == .windows or native_os == .wasi) void else ?posix.uid_t,

/// Set to change the group id when spawning the child process.
gid: if (native_os == .windows or native_os == .wasi) void else ?posix.gid_t,

/// Set to change the current working directory when spawning the child process.
cwd: ?[]const u8,
/// Set to change the current working directory when spawning the child process.
/// This is not yet implemented for Windows. See https://github.com/ziglang/zig/issues/5190
/// Once that is done, `cwd` will be deprecated in favor of this field.
cwd_dir: ?fs.Dir = null,

err_pipe: ?if (native_os == .windows) void else [2]posix.fd_t,

expand_arg0: Arg0Expand,

/// Darwin-only. Disable ASLR for the child process.
disable_aslr: bool = false,

/// Darwin-only. Start child process in suspended state as if SIGSTOP was sent.
start_suspended: bool = false,

/// Set to true to obtain rusage information for the child process.
/// Depending on the target platform and implementation status, the
/// requested statistics may or may not be available. If they are
/// available, then the `resource_usage_statistics` field will be populated
/// after calling `wait`.
/// On Linux and Darwin, this obtains rusage statistics from wait4().
request_resource_usage_statistics: bool = false,

/// This is available after calling wait if
/// `request_resource_usage_statistics` was set to `true` before calling
/// `spawn`.
resource_usage_statistics: ResourceUsageStatistics = .{},

/// When populated, a pipe will be created for the child process to
/// communicate progress back to the parent. The file descriptor of the
/// write end of the pipe will be specified in the `ZIG_PROGRESS`
/// environment variable inside the child process. The progress reported by
/// the child will be attached to this progress node in the parent process.
///
/// The child's progress tree will be grafted into the parent's progress tree,
/// by substituting this node with the child's root node.
progress_node: std.Progress.Node = .{ .index = .none },

pub const ResourceUsageStatistics = struct {
    rusage: @TypeOf(rusage_init) = rusage_init,

    /// Returns the peak resident set size of the child process, in bytes,
    /// if available.
    pub inline fn getMaxRss(rus: ResourceUsageStatistics) ?usize {
        switch (native_os) {
            .linux => {
                if (rus.rusage) |ru| {
                    return @as(usize, @intCast(ru.maxrss)) * 1024;
                } else {
                    return null;
                }
            },
            .windows => {
                if (rus.rusage) |ru| {
                    return ru.PeakWorkingSetSize;
                } else {
                    return null;
                }
            },
            .macos, .ios => {
                if (rus.rusage) |ru| {
                    // Darwin oddly reports in bytes instead of kilobytes.
                    return @as(usize, @intCast(ru.maxrss));
                } else {
                    return null;
                }
            },
            else => return null,
        }
    }

    const rusage_init = switch (native_os) {
        .linux, .macos, .ios => @as(?posix.rusage, null),
        .windows => @as(?windows.VM_COUNTERS, null),
        else => {},
    };
};

pub const Arg0Expand = posix.Arg0Expand;

pub const SpawnError = error{
    OutOfMemory,

    /// POSIX-only. `StdIo.Ignore` was selected and opening `/dev/null` returned ENODEV.
    NoDevice,

    /// Windows-only. `cwd` or `argv` was provided and it was invalid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,

    /// Windows-only. `cwd` was provided, but the path did not exist when spawning the child process.
    CurrentWorkingDirectoryUnlinked,

    /// Windows-only. NUL (U+0000), LF (U+000A), CR (U+000D) are not allowed
    /// within arguments when executing a `.bat`/`.cmd` script.
    /// - NUL/LF signifiies end of arguments, so anything afterwards
    ///   would be lost after execution.
    /// - CR is stripped by `cmd.exe`, so any CR codepoints
    ///   would be lost after execution.
    InvalidBatchScriptArg,
} ||
    posix.ExecveError ||
    posix.SetIdError ||
    posix.ChangeCurDirError ||
    windows.GetFinalPathNameByHandleError ||
    windows.CreateProcessError ||
    windows.GetProcessMemoryInfoError ||
    windows.WaitForSingleObjectError;

pub const Term = union(enum) {
    Exited: u8,
    Signal: u32,
    Stopped: u32,
    Unknown: u32,
};

/// Behavior of the child process's standard input, output, and error
/// streams.
pub const StdIo = enum {
    /// Inherit the stream from the parent process.
    Inherit,

    /// Pass a null stream to the child process.
    /// This is /dev/null on POSIX and NUL on Windows.
    Ignore,

    /// Create a pipe for the stream.
    /// The corresponding field (`stdout`, `stderr`, or `stdin`)
    /// will be assigned a `File` object that can be used
    /// to read from or write to the pipe.
    Pipe,

    /// Close the stream after the child process spawns.
    Close,
};

/// First argument in argv is the executable.
pub fn init(argv: []const []const u8, allocator: mem.Allocator) Child {
    return .{
        .allocator = allocator,
        .argv = argv,
        .id = undefined,
        .thread_handle = undefined,
        .err_pipe = null,
        .term = null,
        .env_map = null,
        .cwd = null,
        .uid = if (native_os == .windows or native_os == .wasi) {} else null,
        .gid = if (native_os == .windows or native_os == .wasi) {} else null,
        .stdin = null,
        .stdout = null,
        .stderr = null,
        .stdin_behavior = .Inherit,
        .stdout_behavior = .Inherit,
        .stderr_behavior = .Inherit,
        .expand_arg0 = .no_expand,
    };
}

pub fn setUserName(child: *Child, name: []const u8) !void {
    const user_info = try process.getUserInfo(name);
    child.uid = user_info.uid;
    child.gid = user_info.gid;
}

/// On success must call `kill` or `wait`.
/// After spawning the `id` is available.
pub fn spawn(child: *Child) SpawnError!void {
    if (!process.can_spawn) {
        @compileError("the target operating system cannot spawn processes");
    }

    if (native_os == .windows) {
        return child.spawnWindows();
    } else {
        return child.spawnPosix();
    }
}

pub fn spawnAndWait(child: *Child) SpawnError!Term {
    try child.spawn();
    return child.wait();
}

/// Forcibly terminates child process and then cleans up all resources.
pub fn kill(child: *Child) !Term {
    if (native_os == .windows) {
        return child.killWindows(1);
    } else {
        return child.killPosix();
    }
}

pub fn killWindows(child: *Child, exit_code: windows.UINT) !Term {
    if (child.term) |term| {
        child.cleanupStreams();
        return term;
    }

    windows.TerminateProcess(child.id, exit_code) catch |err| switch (err) {
        error.PermissionDenied => {
            // Usually when TerminateProcess triggers a ACCESS_DENIED error, it
            // indicates that the process has already exited, but there may be
            // some rare edge cases where our process handle no longer has the
            // PROCESS_TERMINATE access right, so let's do another check to make
            // sure the process is really no longer running:
            windows.WaitForSingleObjectEx(child.id, 0, false) catch return err;
            return error.AlreadyTerminated;
        },
        else => return err,
    };
    try child.waitUnwrappedWindows();
    return child.term.?;
}

pub fn killPosix(child: *Child) !Term {
    if (child.term) |term| {
        child.cleanupStreams();
        return term;
    }
    posix.kill(child.id, posix.SIG.TERM) catch |err| switch (err) {
        error.ProcessNotFound => return error.AlreadyTerminated,
        else => return err,
    };
    try child.waitUnwrapped();
    return child.term.?;
}

/// Blocks until child process terminates and then cleans up all resources.
pub fn wait(child: *Child) !Term {
    const term = if (native_os == .windows)
        try child.waitWindows()
    else
        try child.waitPosix();

    child.id = undefined;

    return term;
}

pub const RunResult = struct {
    term: Term,
    stdout: []u8,
    stderr: []u8,
};

fn fifoToOwnedArrayList(fifo: *std.io.PollFifo) std.ArrayList(u8) {
    if (fifo.head > 0) {
        @memcpy(fifo.buf[0..fifo.count], fifo.buf[fifo.head..][0..fifo.count]);
    }
    const result = std.ArrayList(u8){
        .items = fifo.buf[0..fifo.count],
        .capacity = fifo.buf.len,
        .allocator = fifo.allocator,
    };
    fifo.* = std.io.PollFifo.init(fifo.allocator);
    return result;
}

/// Collect the output from the process's stdout and stderr. Will return once all output
/// has been collected. This does not mean that the process has ended. `wait` should still
/// be called to wait for and clean up the process.
///
/// The process must be started with stdout_behavior and stderr_behavior == .Pipe
pub fn collectOutput(
    child: Child,
    stdout: *std.ArrayList(u8),
    stderr: *std.ArrayList(u8),
    max_output_bytes: usize,
) !void {
    assert(child.stdout_behavior == .Pipe);
    assert(child.stderr_behavior == .Pipe);

    // we could make this work with multiple allocators but YAGNI
    if (stdout.allocator.ptr != stderr.allocator.ptr or
        stdout.allocator.vtable != stderr.allocator.vtable)
    {
        unreachable; // Child.collectOutput only supports 1 allocator
    }

    var poller = std.io.poll(stdout.allocator, enum { stdout, stderr }, .{
        .stdout = child.stdout.?,
        .stderr = child.stderr.?,
    });
    defer poller.deinit();

    while (try poller.poll()) {
        if (poller.fifo(.stdout).count > max_output_bytes)
            return error.StdoutStreamTooLong;
        if (poller.fifo(.stderr).count > max_output_bytes)
            return error.StderrStreamTooLong;
    }

    stdout.* = fifoToOwnedArrayList(poller.fifo(.stdout));
    stderr.* = fifoToOwnedArrayList(poller.fifo(.stderr));
}

pub const RunError = posix.GetCwdError || posix.ReadError || SpawnError || posix.PollError || error{
    StdoutStreamTooLong,
    StderrStreamTooLong,
};

/// Spawns a child process, waits for it, collecting stdout and stderr, and then returns.
/// If it succeeds, the caller owns result.stdout and result.stderr memory.
pub fn run(args: struct {
    allocator: mem.Allocator,
    argv: []const []const u8,
    cwd: ?[]const u8 = null,
    cwd_dir: ?fs.Dir = null,
    env_map: ?*const EnvMap = null,
    max_output_bytes: usize = 50 * 1024,
    expand_arg0: Arg0Expand = .no_expand,
}) RunError!RunResult {
    var child = Child.init(args.argv, args.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.cwd = args.cwd;
    child.cwd_dir = args.cwd_dir;
    child.env_map = args.env_map;
    child.expand_arg0 = args.expand_arg0;

    var stdout = std.ArrayList(u8).init(args.allocator);
    var stderr = std.ArrayList(u8).init(args.allocator);
    errdefer {
        stdout.deinit();
        stderr.deinit();
    }

    try child.spawn();
    try child.collectOutput(&stdout, &stderr, args.max_output_bytes);

    return RunResult{
        .term = try child.wait(),
        .stdout = try stdout.toOwnedSlice(),
        .stderr = try stderr.toOwnedSlice(),
    };
}

fn waitWindows(child: *Child) !Term {
    if (child.term) |term| {
        child.cleanupStreams();
        return term;
    }

    try child.waitUnwrappedWindows();
    return child.term.?;
}

fn waitPosix(child: *Child) !Term {
    if (child.term) |term| {
        child.cleanupStreams();
        return term;
    }

    try child.waitUnwrapped();
    return child.term.?;
}

fn waitUnwrappedWindows(child: *Child) !void {
    const result = windows.WaitForSingleObjectEx(child.id, windows.INFINITE, false);

    child.term = @as(SpawnError!Term, x: {
        var exit_code: windows.DWORD = undefined;
        if (windows.kernel32.GetExitCodeProcess(child.id, &exit_code) == 0) {
            break :x Term{ .Unknown = 0 };
        } else {
            break :x Term{ .Exited = @as(u8, @truncate(exit_code)) };
        }
    });

    if (child.request_resource_usage_statistics) {
        child.resource_usage_statistics.rusage = try windows.GetProcessMemoryInfo(child.id);
    }

    posix.close(child.id);
    posix.close(child.thread_handle);
    child.cleanupStreams();
    return result;
}

fn waitUnwrapped(child: *Child) !void {
    const res: posix.WaitPidResult = res: {
        if (child.request_resource_usage_statistics) {
            switch (native_os) {
                .linux, .macos, .ios => {
                    var ru: posix.rusage = undefined;
                    const res = posix.wait4(child.id, 0, &ru);
                    child.resource_usage_statistics.rusage = ru;
                    break :res res;
                },
                else => {},
            }
        }

        break :res posix.waitpid(child.id, 0);
    };
    const status = res.status;
    child.cleanupStreams();
    child.handleWaitResult(status);
}

fn handleWaitResult(child: *Child, status: u32) void {
    child.term = child.cleanupAfterWait(status);
}

fn cleanupStreams(child: *Child) void {
    if (child.stdin) |*stdin| {
        stdin.close();
        child.stdin = null;
    }
    if (child.stdout) |*stdout| {
        stdout.close();
        child.stdout = null;
    }
    if (child.stderr) |*stderr| {
        stderr.close();
        child.stderr = null;
    }
}

fn cleanupAfterWait(child: *Child, status: u32) !Term {
    if (child.err_pipe) |err_pipe| {
        defer destroyPipe(err_pipe);

        if (native_os == .linux) {
            var fd = [1]posix.pollfd{posix.pollfd{
                .fd = err_pipe[0],
                .events = posix.POLL.IN,
                .revents = undefined,
            }};

            // Check if the eventfd buffer stores a non-zero value by polling
            // it, that's the error code returned by the child process.
            _ = posix.poll(&fd, 0) catch unreachable;

            // According to eventfd(2) the descriptor is readable if the counter
            // has a value greater than 0
            if ((fd[0].revents & posix.POLL.IN) != 0) {
                const err_int = try readIntFd(err_pipe[0]);
                return @as(SpawnError, @errorCast(@errorFromInt(err_int)));
            }
        } else {
            // Write maxInt(ErrInt) to the write end of the err_pipe. This is after
            // waitpid, so this write is guaranteed to be after the child
            // pid potentially wrote an error. This way we can do a blocking
            // read on the error pipe and either get maxInt(ErrInt) (no error) or
            // an error code.
            try writeIntFd(err_pipe[1], maxInt(ErrInt));
            const err_int = try readIntFd(err_pipe[0]);
            // Here we potentially return the fork child's error from the parent
            // pid.
            if (err_int != maxInt(ErrInt)) {
                return @as(SpawnError, @errorCast(@errorFromInt(err_int)));
            }
        }
    }

    return statusToTerm(status);
}

fn statusToTerm(status: u32) Term {
    return if (posix.W.IFEXITED(status))
        Term{ .Exited = posix.W.EXITSTATUS(status) }
    else if (posix.W.IFSIGNALED(status))
        Term{ .Signal = posix.W.TERMSIG(status) }
    else if (posix.W.IFSTOPPED(status))
        Term{ .Stopped = posix.W.STOPSIG(status) }
    else
        Term{ .Unknown = status };
}

fn spawnPosix(child: *Child) SpawnError!void {
    // The child process does need to access (one end of) these pipes. However,
    // we must initially set CLOEXEC to avoid a race condition. If another thread
    // is racing to spawn a different child process, we don't want it to inherit
    // these FDs in any scenario; that would mean that, for instance, calls to
    // `poll` from the parent would not report the child's stdout as closing when
    // expected, since the other child may retain a reference to the write end of
    // the pipe. So, we create the pipes with CLOEXEC initially. After fork, we
    // need to do something in the new child to make sure we preserve the reference
    // we want. We could use `fcntl` to remove CLOEXEC from the FD, but as it
    // turns out, we `dup2` everything anyway, so there's no need!
    const pipe_flags: posix.O = .{ .CLOEXEC = true };

    const stdin_pipe = if (child.stdin_behavior == .Pipe) try posix.pipe2(pipe_flags) else undefined;
    errdefer if (child.stdin_behavior == .Pipe) {
        destroyPipe(stdin_pipe);
    };

    const stdout_pipe = if (child.stdout_behavior == .Pipe) try posix.pipe2(pipe_flags) else undefined;
    errdefer if (child.stdout_behavior == .Pipe) {
        destroyPipe(stdout_pipe);
    };

    const stderr_pipe = if (child.stderr_behavior == .Pipe) try posix.pipe2(pipe_flags) else undefined;
    errdefer if (child.stderr_behavior == .Pipe) {
        destroyPipe(stderr_pipe);
    };

    const any_ignore = (child.stdin_behavior == .Ignore or child.stdout_behavior == .Ignore or child.stderr_behavior == .Ignore);
    const dev_null_fd = if (any_ignore)
        posix.openZ("/dev/null", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
            error.PathAlreadyExists => unreachable,
            error.NoSpaceLeft => unreachable,
            error.FileTooBig => unreachable,
            error.DeviceBusy => unreachable,
            error.FileLocksNotSupported => unreachable,
            error.BadPathName => unreachable, // Windows-only
            error.WouldBlock => unreachable,
            error.NetworkNotFound => unreachable, // Windows-only
            else => |e| return e,
        }
    else
        undefined;
    defer {
        if (any_ignore) posix.close(dev_null_fd);
    }

    const prog_pipe: [2]posix.fd_t = if (child.progress_node.index != .none)
        // We use CLOEXEC for the same reason as in `pipe_flags`.
        try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true })
    else
        .{ -1, -1 };
    errdefer destroyPipe(prog_pipe);

    var arena_allocator = std.heap.ArenaAllocator.init(child.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    // The POSIX standard does not allow malloc() between fork() and execve(),
    // and `child.allocator` may be a libc allocator.
    // I have personally observed the child process deadlocking when it tries
    // to call malloc() due to a heap allocation between fork() and execve(),
    // in musl v1.1.24.
    // Additionally, we want to reduce the number of possible ways things
    // can fail between fork() and execve().
    // Therefore, we do all the allocation for the execve() before the fork().
    // This means we must do the null-termination of argv and env vars here.
    const argv_buf = try arena.allocSentinel(?[*:0]const u8, child.argv.len, null);
    for (child.argv, 0..) |arg, i| argv_buf[i] = (try arena.dupeZ(u8, arg)).ptr;

    const prog_fileno = 3;
    comptime assert(@max(posix.STDIN_FILENO, posix.STDOUT_FILENO, posix.STDERR_FILENO) + 1 == prog_fileno);

    const envp: [*:null]const ?[*:0]const u8 = m: {
        const prog_fd: i32 = if (prog_pipe[1] == -1) -1 else prog_fileno;
        if (child.env_map) |env_map| {
            break :m (try process.createEnvironFromMap(arena, env_map, .{
                .zig_progress_fd = prog_fd,
            })).ptr;
        } else if (builtin.link_libc) {
            break :m (try process.createEnvironFromExisting(arena, std.c.environ, .{
                .zig_progress_fd = prog_fd,
            })).ptr;
        } else if (builtin.output_mode == .Exe) {
            // Then we have Zig start code and this works.
            // TODO type-safety for null-termination of `os.environ`.
            break :m (try process.createEnvironFromExisting(arena, @ptrCast(std.os.environ.ptr), .{
                .zig_progress_fd = prog_fd,
            })).ptr;
        } else {
            // TODO come up with a solution for this.
            @compileError("missing std lib enhancement: std.process.Child implementation has no way to collect the environment variables to forward to the child process");
        }
    };

    // This pipe is used to communicate errors between the time of fork
    // and execve from the child process to the parent process.
    const err_pipe = blk: {
        if (native_os == .linux) {
            const fd = try posix.eventfd(0, linux.EFD.CLOEXEC);
            // There's no distinction between the readable and the writeable
            // end with eventfd
            break :blk [2]posix.fd_t{ fd, fd };
        } else {
            break :blk try posix.pipe2(.{ .CLOEXEC = true });
        }
    };
    errdefer destroyPipe(err_pipe);

    const pid_result = try posix.fork();
    if (pid_result == 0) {
        // we are the child
        setUpChildIo(child.stdin_behavior, stdin_pipe[0], posix.STDIN_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);
        setUpChildIo(child.stdout_behavior, stdout_pipe[1], posix.STDOUT_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);
        setUpChildIo(child.stderr_behavior, stderr_pipe[1], posix.STDERR_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);

        if (child.cwd_dir) |cwd| {
            posix.fchdir(cwd.fd) catch |err| forkChildErrReport(err_pipe[1], err);
        } else if (child.cwd) |cwd| {
            posix.chdir(cwd) catch |err| forkChildErrReport(err_pipe[1], err);
        }

        // Must happen after fchdir above, the cwd file descriptor might be
        // equal to prog_fileno and be clobbered by this dup2 call.
        if (prog_pipe[1] != -1) posix.dup2(prog_pipe[1], prog_fileno) catch |err| forkChildErrReport(err_pipe[1], err);

        if (child.gid) |gid| {
            posix.setregid(gid, gid) catch |err| forkChildErrReport(err_pipe[1], err);
        }

        if (child.uid) |uid| {
            posix.setreuid(uid, uid) catch |err| forkChildErrReport(err_pipe[1], err);
        }

        const err = switch (child.expand_arg0) {
            .expand => posix.execvpeZ_expandArg0(.expand, argv_buf.ptr[0].?, argv_buf.ptr, envp),
            .no_expand => posix.execvpeZ_expandArg0(.no_expand, argv_buf.ptr[0].?, argv_buf.ptr, envp),
        };
        forkChildErrReport(err_pipe[1], err);
    }

    // we are the parent
    const pid: i32 = @intCast(pid_result);
    child.stdin = if (child.stdin_behavior == .Pipe) stdin: {
        posix.close(stdin_pipe[0]);
        break :stdin .{ .handle = stdin_pipe[1] };
    } else null;
    child.stdout = if (child.stdout_behavior == .Pipe) stdout: {
        posix.close(stdout_pipe[1]);
        break :stdout .{ .handle = stdout_pipe[0] };
    } else null;
    child.stderr = if (child.stderr_behavior == .Pipe) stderr: {
        posix.close(stderr_pipe[1]);
        break :stderr .{ .handle = stderr_pipe[0] };
    } else null;

    child.id = pid;
    child.err_pipe = err_pipe;
    child.term = null;

    if (prog_pipe[1] != -1) {
        posix.close(prog_pipe[1]);
    }
    child.progress_node.setIpcFd(prog_pipe[0]);
}

fn spawnWindows(child: *Child) SpawnError!void {
    const inheritable = windows.SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(windows.SECURITY_ATTRIBUTES),
        .bInheritHandle = windows.TRUE,
        .lpSecurityDescriptor = null,
    };

    const any_ignore = (child.stdin_behavior == StdIo.Ignore or child.stdout_behavior == StdIo.Ignore or child.stderr_behavior == StdIo.Ignore);

    const nul_handle = if (any_ignore)
        // "\Device\Null" or "\??\NUL"
        windows.OpenFile(unicode.utf8ToUtf16LeStringLiteral("\\Device\\Null"), .{
            .access_mask = .{
                .GENERIC = .{
                    .READ = true,
                    .WRITE = true,
                },
                .SYNCHRONIZE = true,
            },
            .share_access = .{},
            .sa = &inheritable,
            .creation = windows.OPEN_EXISTING,
        }) catch |err| switch (err) {
            error.PathAlreadyExists => return error.Unexpected, // not possible for "NUL"
            error.PipeBusy => return error.Unexpected, // not possible for "NUL"
            error.FileNotFound => return error.Unexpected, // not possible for "NUL"
            error.AccessDenied => return error.Unexpected, // not possible for "NUL"
            error.NameTooLong => return error.Unexpected, // not possible for "NUL"
            error.WouldBlock => return error.Unexpected, // not possible for "NUL"
            error.NetworkNotFound => return error.Unexpected, // not possible for "NUL"
            error.AntivirusInterference => return error.Unexpected, // not possible for "NUL"
            else => |e| return e,
        }
    else
        undefined;
    defer {
        if (any_ignore) posix.close(nul_handle);
    }

    const stdin_pipe: Pipe = switch (child.stdin_behavior) {
        .Pipe => try windowsMakePipeIn(&inheritable),
        .Ignore => .{ .read = nul_handle, .write = null },
        .Inherit => .{ .read = std.io.getStdIn().handle, .write = null },
        .Close => .{ .read = null, .write = null },
    };
    errdefer if (child.stdin_behavior == .Pipe) windowsDestroyPipe(stdin_pipe);

    const stdout_pipe: Pipe = switch (child.stdout_behavior) {
        .Pipe => try windowsMakePipeOut(&inheritable, .@"async"),
        .Ignore => .{ .read = null, .write = nul_handle },
        .Inherit => .{ .read = null, .write = std.io.getStdOut().handle },
        .Close => .{ .read = null, .write = null },
    };
    errdefer if (child.stdout_behavior == .Pipe) windowsDestroyPipe(stdout_pipe);

    const stderr_pipe: Pipe = switch (child.stderr_behavior) {
        .Pipe => try windowsMakePipeOut(&inheritable, .@"async"),
        .Ignore => .{ .read = null, .write = nul_handle },
        .Inherit => .{ .read = null, .write = std.io.getStdOut().handle },
        .Close => .{ .read = null, .write = null },
    };
    errdefer if (child.stderr_behavior == .Pipe) windowsDestroyPipe(stderr_pipe);

    const progress_pipe: Pipe = if (child.progress_node.index != .none)
        try windowsMakePipeOut(&inheritable, .nonblock)
    else
        .{ .read = null, .write = null };
    errdefer if (child.progress_node.index != .none) windowsDestroyPipe(progress_pipe);
    const progress_fd: ?i32 = if (progress_pipe.write) |fd|
        @intCast(@as(isize, @bitCast(@intFromPtr(fd))))
    else
        -1;

    const handles: StdHandles = .{
        .stdin = stdin_pipe.read,
        .stdout = stdout_pipe.write,
        .stderr = stderr_pipe.write,
        .progress = progress_pipe.write,
    };

    var cwd_buf: [windows.PATH_MAX_WIDE]u16 = undefined;
    const cwd_w = if (child.cwd) |cwd|
        cwd_buf[0..try unicode.wtf8ToWtf16Le(&cwd_buf, cwd)]
    else if (child.cwd_dir) |cwd|
        try windows.GetFinalPathNameByHandle(cwd.fd, .{}, &cwd_buf)
    else
        null;

    const envp: []const u16 = if (child.env_map) |env_map|
        try process.createWindowsEnvBlock(child.allocator, env_map, .{
            .zig_progress_fd = progress_fd,
        })
    else
        try process.createWindowsEnvBlockFromExisting(
            child.allocator,
            windows.peb().ProcessParameters.Environment,
            .{ .zig_progress_fd = progress_fd },
        );
    defer child.allocator.free(envp);

    const app_name_wtf8 = child.argv[0];
    const app_name_is_absolute = fs.path.isAbsolute(app_name_wtf8);

    // the cwd set in Child is in effect when choosing the executable path
    // to match posix semantics
    var cwd_path_w_needs_free = false;
    const cwd_path_w = x: {
        // If the app name is absolute, then we need to use its dirname as the cwd
        if (app_name_is_absolute) {
            cwd_path_w_needs_free = true;
            const dir = fs.path.dirname(app_name_wtf8).?;
            break :x try unicode.wtf8ToWtf16LeAllocZ(child.allocator, dir);
        } else if (child.cwd) |cwd| {
            cwd_path_w_needs_free = true;
            break :x try unicode.wtf8ToWtf16LeAllocZ(child.allocator, cwd);
        } else {
            break :x &[_:0]u16{}; // empty for cwd
        }
    };
    defer if (cwd_path_w_needs_free) child.allocator.free(cwd_path_w);

    // If the app name has more than just a filename, then we need to separate that
    // into the basename and dirname and use the dirname as an addition to the cwd
    // path. This is because NtQueryDirectoryFile cannot accept FileName params with
    // path separators.
    const app_basename_wtf8 = fs.path.basename(app_name_wtf8);
    // If the app name is absolute, then the cwd will already have the app's dirname in it,
    // so only populate app_dirname if app name is a relative path with > 0 path separators.
    const maybe_app_dirname_wtf8 = if (!app_name_is_absolute) fs.path.dirname(app_name_wtf8) else null;
    const app_dirname_w: ?[:0]u16 = x: {
        if (maybe_app_dirname_wtf8) |app_dirname_wtf8| {
            break :x try unicode.wtf8ToWtf16LeAllocZ(child.allocator, app_dirname_wtf8);
        }
        break :x null;
    };
    defer if (app_dirname_w != null) child.allocator.free(app_dirname_w.?);

    const app_name_w = try unicode.wtf8ToWtf16LeAllocZ(child.allocator, app_basename_wtf8);
    defer child.allocator.free(app_name_w);

    run: {
        const PATH: [:0]const u16 = process.getenvW(unicode.utf8ToUtf16LeStringLiteral("PATH")) orelse &[_:0]u16{};
        const PATHEXT: [:0]const u16 = process.getenvW(unicode.utf8ToUtf16LeStringLiteral("PATHEXT")) orelse &[_:0]u16{};

        // In case the command ends up being a .bat/.cmd script, we need to escape things using the cmd.exe rules
        // and invoke cmd.exe ourselves in order to mitigate arbitrary command execution from maliciously
        // constructed arguments.
        //
        // We'll need to wait until we're actually trying to run the command to know for sure
        // if the resolved command has the `.bat` or `.cmd` extension, so we defer actually
        // serializing the command line until we determine how it should be serialized.
        var cmd_line_cache = WindowsCommandLineCache.init(child.allocator, child.argv);
        defer cmd_line_cache.deinit();

        var app_buf = std.ArrayListUnmanaged(u16){};
        defer app_buf.deinit(child.allocator);

        try app_buf.appendSlice(child.allocator, app_name_w);

        var dir_buf = std.ArrayListUnmanaged(u16){};
        defer dir_buf.deinit(child.allocator);

        if (cwd_path_w.len > 0) {
            try dir_buf.appendSlice(child.allocator, cwd_path_w);
        }
        if (app_dirname_w) |app_dir| {
            if (dir_buf.items.len > 0) try dir_buf.append(child.allocator, fs.path.sep);
            try dir_buf.appendSlice(child.allocator, app_dir);
        }
        if (dir_buf.items.len > 0) {
            // Need to normalize the path, openDirW can't handle things like double backslashes
            const normalized_len = windows.normalizePath(u16, dir_buf.items) catch return error.BadPathName;
            dir_buf.shrinkRetainingCapacity(normalized_len);
        }

        windowsCreateProcessPathExt(child, &dir_buf, &app_buf, PATHEXT, &cmd_line_cache, envp, cwd_w, handles) catch |no_path_err| {
            const original_err = switch (no_path_err) {
                // argv[0] contains unsupported characters that will never resolve to a valid exe.
                error.InvalidArg0 => return error.FileNotFound,
                error.FileNotFound, error.InvalidExe, error.AccessDenied => |e| e,
                error.UnrecoverableInvalidExe => return error.InvalidExe,
                else => |e| return e,
            };

            // If the app name had path separators, that disallows PATH searching,
            // and there's no need to search the PATH if the app name is absolute.
            // We still search the path if the cwd is absolute because of the
            // "cwd set in Child is in effect when choosing the executable path
            // to match posix semantics" behavior--we don't want to skip searching
            // the PATH just because we were trying to set the cwd of the child process.
            if (app_dirname_w != null or app_name_is_absolute) {
                return original_err;
            }

            var it = mem.tokenizeScalar(u16, PATH, ';');
            while (it.next()) |search_path| {
                dir_buf.clearRetainingCapacity();
                try dir_buf.appendSlice(child.allocator, search_path);
                // Need to normalize the path, some PATH values can contain things like double
                // backslashes which openDirW can't handle
                const normalized_len = windows.normalizePath(u16, dir_buf.items) catch continue;
                dir_buf.shrinkRetainingCapacity(normalized_len);

                if (child.windowsCreateProcessPathExt(&dir_buf, &app_buf, PATHEXT, &cmd_line_cache, envp, cwd_w, handles)) {
                    break :run;
                } else |err| switch (err) {
                    // argv[0] contains unsupported characters that will never resolve to a valid exe.
                    error.InvalidArg0 => return error.FileNotFound,
                    error.FileNotFound, error.AccessDenied, error.InvalidExe => continue,
                    error.UnrecoverableInvalidExe => return error.InvalidExe,
                    else => |e| return e,
                }
            } else {
                return original_err;
            }
        };
    }

    child.stdin = if (child.stdin_behavior == .Pipe) stdin: {
        posix.close(stdin_pipe.read.?);
        break :stdin .{ .handle = stdin_pipe.write.? };
    } else null;
    child.stdout = if (child.stdout_behavior == .Pipe) stdout: {
        posix.close(stdout_pipe.write.?);
        break :stdout .{ .handle = stdout_pipe.read.? };
    } else null;
    child.stderr = if (child.stderr_behavior == .Pipe) stderr: {
        posix.close(stderr_pipe.write.?);
        break :stderr .{ .handle = stderr_pipe.read.? };
    } else null;
    child.term = null;
    if (child.progress_node.index != .none) {
        posix.close(progress_pipe.write.?);
        child.progress_node.setIpcFd(progress_pipe.read.?);
    }
}

fn setUpChildIo(stdio: StdIo, pipe_fd: i32, std_fileno: i32, dev_null_fd: i32) !void {
    switch (stdio) {
        .Pipe => try posix.dup2(pipe_fd, std_fileno),
        .Close => posix.close(std_fileno),
        .Inherit => {},
        .Ignore => try posix.dup2(dev_null_fd, std_fileno),
    }
}

fn destroyPipe(pipe: [2]posix.fd_t) void {
    if (pipe[0] != -1) posix.close(pipe[0]);
    if (pipe[0] != pipe[1]) posix.close(pipe[1]);
}

// Child of fork calls this to report an error to the fork parent.
// Then the child exits.
fn forkChildErrReport(fd: i32, err: Child.SpawnError) noreturn {
    writeIntFd(fd, @as(ErrInt, @intFromError(err))) catch {};
    // If we're linking libc, some naughty applications may have registered atexit handlers
    // which we really do not want to run in the fork child. I caught LLVM doing this and
    // it caused a deadlock instead of doing an exit syscall. In the words of Avril Lavigne,
    // "Why'd you have to go and make things so complicated?"
    if (builtin.link_libc) {
        // The _exit(2) function does nothing but make the exit syscall, unlike exit(3)
        std.c._exit(1);
    }
    posix.exit(1);
}

fn writeIntFd(fd: i32, value: ErrInt) !void {
    const file: File = .{ .handle = fd };
    file.writer().writeInt(u64, @intCast(value), .little) catch return error.SystemResources;
}

fn readIntFd(fd: i32) !ErrInt {
    const file: File = .{ .handle = fd };
    return @intCast(file.reader().readInt(u64, .little) catch return error.SystemResources);
}

const ErrInt = std.meta.Int(.unsigned, @sizeOf(anyerror) * 8);

/// Expects `app_buf` to contain exactly the app name, and `dir_buf` to contain exactly the dir path.
/// After return, `app_buf` will always contain exactly the app name and `dir_buf` will always contain exactly the dir path.
/// Note: `app_buf` should not contain any leading path separators.
/// Note: If the dir is the cwd, dir_buf should be empty (len = 0).
fn windowsCreateProcessPathExt(
    child: *Child,
    dir_buf: *std.ArrayListUnmanaged(u16),
    app_buf: *std.ArrayListUnmanaged(u16),
    pathext: []const u16,
    cmd_line_cache: *WindowsCommandLineCache,
    envp: ?[]const u16,
    cwd: ?[]const u16,
    handles: StdHandles,
) !void {
    const allocator = child.allocator;
    const app_name_len = app_buf.items.len;
    const dir_path_len = dir_buf.items.len;

    if (app_name_len == 0) return error.FileNotFound;

    defer app_buf.shrinkRetainingCapacity(app_name_len);
    defer dir_buf.shrinkRetainingCapacity(dir_path_len);

    // The name of the game here is to avoid CreateProcessW calls at all costs,
    // and only ever try calling it when we have a real candidate for execution.
    // Secondarily, we want to minimize the number of syscalls used when checking
    // for each PATHEXT-appended version of the app name.
    //
    // An overview of the technique used:
    // - Open the search directory for iteration (either cwd or a path from PATH)
    // - Use NtQueryDirectoryFile with a wildcard filename of `<app name>*` to
    //   check if anything that could possibly match either the unappended version
    //   of the app name or any of the versions with a PATHEXT value appended exists.
    // - If the wildcard NtQueryDirectoryFile call found nothing, we can exit early
    //   without needing to use PATHEXT at all.
    //
    // This allows us to use a <open dir, NtQueryDirectoryFile, close dir> sequence
    // for any directory that doesn't contain any possible matches, instead of having
    // to use a separate look up for each individual filename combination (unappended +
    // each PATHEXT appended). For directories where the wildcard *does* match something,
    // we iterate the matches and take note of any that are either the unappended version,
    // or a version with a supported PATHEXT appended. We then try calling CreateProcessW
    // with the found versions in the appropriate order.

    var dir = dir: {
        // needs to be null-terminated
        try dir_buf.append(allocator, 0);
        defer dir_buf.shrinkRetainingCapacity(dir_path_len);
        const dir_path_z = dir_buf.items[0 .. dir_buf.items.len - 1 :0];
        const prefixed_path = try windows.wToPrefixedFileW(dir_path_z, .{});
        break :dir fs.cwd().openDirW(prefixed_path.span().ptr, .{ .iterate = true }) catch
            return error.FileNotFound;
    };
    defer dir.close();

    // Add wildcard and null-terminator
    try app_buf.append(allocator, '*');
    try app_buf.append(allocator, 0);
    const app_name_wildcard = app_buf.items[0 .. app_buf.items.len - 1 :0];

    // This 2048 is arbitrary, we just want it to be large enough to get multiple FILE_DIRECTORY_INFORMATION entries
    // returned per NtQueryDirectoryFile call.
    var file_information_buf: [2048]u8 align(@alignOf(windows.FILE_DIRECTORY_INFORMATION)) = undefined;
    const file_info_maximum_single_entry_size = @sizeOf(windows.FILE_DIRECTORY_INFORMATION) + (windows.NAME_MAX * 2);
    if (file_information_buf.len < file_info_maximum_single_entry_size) {
        @compileError("file_information_buf must be large enough to contain at least one maximum size FILE_DIRECTORY_INFORMATION entry");
    }
    var io_status: windows.IO_STATUS_BLOCK = undefined;

    const num_supported_pathext = @typeInfo(CreateProcessSupportedExtension).Enum.fields.len;
    var pathext_seen = [_]bool{false} ** num_supported_pathext;
    var any_pathext_seen = false;
    var unappended_exists = false;

    // Fully iterate the wildcard matches via NtQueryDirectoryFile and take note of all versions
    // of the app_name we should try to spawn.
    // Note: This is necessary because the order of the files returned is filesystem-dependent:
    //       On NTFS, `blah.exe*` will always return `blah.exe` first if it exists.
    //       On FAT32, it's possible for something like `blah.exe.obj` to be returned first.
    while (true) {
        const app_name_len_bytes = std.math.cast(u16, app_name_wildcard.len * 2) orelse return error.NameTooLong;
        var app_name_unicode_string = windows.UNICODE_STRING{
            .Length = app_name_len_bytes,
            .MaximumLength = app_name_len_bytes,
            .Buffer = @constCast(app_name_wildcard.ptr),
        };
        const rc = windows.ntdll.NtQueryDirectoryFile(
            dir.fd,
            null,
            null,
            null,
            &io_status,
            &file_information_buf,
            file_information_buf.len,
            .FileDirectoryInformation,
            windows.FALSE, // single result
            &app_name_unicode_string,
            windows.FALSE, // restart iteration
        );

        // If we get nothing with the wildcard, then we can just bail out
        // as we know appending PATHEXT will not yield anything.
        switch (rc) {
            .SUCCESS => {},
            .NO_SUCH_FILE => return error.FileNotFound,
            .NO_MORE_FILES => break,
            .ACCESS_DENIED => return error.AccessDenied,
            else => return windows.unexpectedStatus(rc),
        }

        // According to the docs, this can only happen if there is not enough room in the
        // buffer to write at least one complete FILE_DIRECTORY_INFORMATION entry.
        // Therefore, this condition should not be possible to hit with the buffer size we use.
        std.debug.assert(io_status.Information != 0);

        var it = windows.FileInformationIterator(windows.FILE_DIRECTORY_INFORMATION){ .buf = &file_information_buf };
        while (it.next()) |info| {
            // Skip directories
            if (info.FileAttributes & windows.FILE_ATTRIBUTE_DIRECTORY != 0) continue;
            const filename = @as([*]u16, @ptrCast(&info.FileName))[0 .. info.FileNameLength / 2];
            // Because all results start with the app_name since we're using the wildcard `app_name*`,
            // if the length is equal to app_name then this is an exact match
            if (filename.len == app_name_len) {
                // Note: We can't break early here because it's possible that the unappended version
                //       fails to spawn, in which case we still want to try the PATHEXT appended versions.
                unappended_exists = true;
            } else if (windowsCreateProcessSupportsExtension(filename[app_name_len..])) |pathext_ext| {
                pathext_seen[@intFromEnum(pathext_ext)] = true;
                any_pathext_seen = true;
            }
        }
    }

    const unappended_err = unappended: {
        if (unappended_exists) {
            if (dir_path_len != 0) switch (dir_buf.items[dir_buf.items.len - 1]) {
                '/', '\\' => {},
                else => try dir_buf.append(allocator, fs.path.sep),
            };
            try dir_buf.appendSlice(allocator, app_buf.items[0..app_name_len]);
            try dir_buf.append(allocator, 0);
            const full_app_name = dir_buf.items[0 .. dir_buf.items.len - 1 :0];

            const is_bat_or_cmd = bat_or_cmd: {
                const app_name = app_buf.items[0..app_name_len];
                const ext_start = std.mem.lastIndexOfScalar(u16, app_name, '.') orelse break :bat_or_cmd false;
                const ext = app_name[ext_start..];
                const ext_enum = windowsCreateProcessSupportsExtension(ext) orelse break :bat_or_cmd false;
                switch (ext_enum) {
                    .cmd, .bat => break :bat_or_cmd true,
                    else => break :bat_or_cmd false,
                }
            };
            const cmd_line_w = if (is_bat_or_cmd)
                try cmd_line_cache.scriptCommandLine(full_app_name)
            else
                try cmd_line_cache.commandLine();
            const app_name_w = if (is_bat_or_cmd)
                try cmd_line_cache.cmdExePath()
            else
                full_app_name;

            if (child.windowsCreateProcess(app_name_w, cmd_line_w, envp, cwd, handles)) |_| {
                return;
            } else |err| switch (err) {
                error.FileNotFound,
                error.AccessDenied,
                => break :unappended err,
                error.InvalidExe => {
                    // On InvalidExe, if the extension of the app name is .exe then
                    // it's treated as an unrecoverable error. Otherwise, it'll be
                    // skipped as normal.
                    const app_name = app_buf.items[0..app_name_len];
                    const ext_start = std.mem.lastIndexOfScalar(u16, app_name, '.') orelse break :unappended err;
                    const ext = app_name[ext_start..];
                    if (windows.eqlIgnoreCaseWTF16(ext, unicode.utf8ToUtf16LeStringLiteral(".EXE"))) {
                        return error.UnrecoverableInvalidExe;
                    }
                    break :unappended err;
                },
                else => return err,
            }
        }
        break :unappended error.FileNotFound;
    };

    if (!any_pathext_seen) return unappended_err;

    // Now try any PATHEXT appended versions that we've seen
    var ext_it = mem.tokenizeScalar(u16, pathext, ';');
    while (ext_it.next()) |ext| {
        const ext_enum = windowsCreateProcessSupportsExtension(ext) orelse continue;
        if (!pathext_seen[@intFromEnum(ext_enum)]) continue;

        dir_buf.shrinkRetainingCapacity(dir_path_len);
        if (dir_path_len != 0) switch (dir_buf.items[dir_buf.items.len - 1]) {
            '/', '\\' => {},
            else => try dir_buf.append(allocator, fs.path.sep),
        };
        try dir_buf.appendSlice(allocator, app_buf.items[0..app_name_len]);
        try dir_buf.appendSlice(allocator, ext);
        try dir_buf.append(allocator, 0);
        const full_app_name = dir_buf.items[0 .. dir_buf.items.len - 1 :0];

        const is_bat_or_cmd = switch (ext_enum) {
            .cmd, .bat => true,
            else => false,
        };
        const cmd_line_w = if (is_bat_or_cmd)
            try cmd_line_cache.scriptCommandLine(full_app_name)
        else
            try cmd_line_cache.commandLine();
        const app_name_w = if (is_bat_or_cmd)
            try cmd_line_cache.cmdExePath()
        else
            full_app_name;

        if (child.windowsCreateProcess(app_name_w, cmd_line_w, envp, cwd, handles)) |_| {
            return;
        } else |err| switch (err) {
            error.FileNotFound => continue,
            error.AccessDenied => continue,
            error.InvalidExe => {
                // On InvalidExe, if the extension of the app name is .exe then
                // it's treated as an unrecoverable error. Otherwise, it'll be
                // skipped as normal.
                if (windows.eqlIgnoreCaseWTF16(ext, unicode.utf8ToUtf16LeStringLiteral(".EXE"))) {
                    return error.UnrecoverableInvalidExe;
                }
                continue;
            },
            else => return err,
        }
    }

    return unappended_err;
}

const StdHandles = struct {
    stdin: ?posix.fd_t,
    stdout: ?posix.fd_t,
    stderr: ?posix.fd_t,
    progress: ?posix.fd_t,

    pub const Field = std.meta.FieldEnum(StdHandles);
    pub const fields = std.enums.values(Field);
    pub fn get(handles: StdHandles, comptime field: Field) ?posix.fd_t {
        return if (@field(handles, @tagName(field))) |fd|
            if (fd != windows.INVALID_HANDLE_VALUE) fd else null
        else
            null;
    }
};
fn windowsCreateProcess(
    child: *Child,
    app_name: [:0]const u16,
    cmd_line: []const u16,
    envp: ?[]const u16,
    cwd: ?[]const u16,
    handles: StdHandles,
) !void {
    const parent_params = windows.peb().ProcessParameters;
    const app_name_us = try windows.UNICODE_STRING.init(@constCast(app_name));
    const image_name = try windows.wToPrefixedFileW(app_name, .{
        .dir = if (cwd) |path| .{ .wtf16_path = path } else .cwd,
        .allow_relative = false,
    });
    const env = env: {
        const min_env = [1]u16{0} ** 2;
        const env = envp orelse parent_params.Environment[0..@divExact(
            parent_params.EnvironmentSize,
            @sizeOf(windows.WCHAR),
        )];
        break :env if (env.len >= min_env.len) env else &min_env;
    };
    var create_info: windows.PS.CREATE_INFO = .{ .Info = .{ .InitialState = .{
        .InitFlags = .{
            .WriteOutputOnExit = true,
            .DetectManifest = true,
            .ProhibitedImageCharacteristics = 0x2000,
        },
        .AdditionalFileAccess = .{ .SPECIFIC = .{ .FILE = .{
            .READ_DATA = true,
            .READ_ATTRIBUTES = true,
        } } },
    } } };
    defer create_info.deinit();
    var handle_list: [StdHandles.fields.len]windows.HANDLE = undefined;
    var handle_list_len: usize = 0;
    inline for (StdHandles.fields) |field| {
        if (handles.get(field)) |handle| {
            if (mem.indexOfScalar(windows.HANDLE, handle_list[0..handle_list_len], handle) == null) {
                handle_list[handle_list_len] = handle;
                handle_list_len += 1;
            }
        }
    }
    switch (windows.ntdll.NtCreateUserProcess(
        &child.id,
        &child.thread_handle,
        .{ .MAXIMUM_ALLOWED = true },
        .{ .MAXIMUM_ALLOWED = true },
        null,
        null,
        .{ .INHERIT_HANDLES = handle_list_len > 0 },
        .{},
        &.{
            .AllocationSize = undefined,
            .Size = undefined,

            .hStdInput = handles.get(.stdin),
            .hStdOutput = handles.get(.stdout),
            .hStdError = handles.get(.stderr),

            .CurrentDirectory = .{
                .DosPath = if (cwd) |path|
                    try windows.UNICODE_STRING.init(@constCast(path))
                else
                    parent_params.CurrentDirectory.DosPath,
                .Handle = null, // has no effect
            },
            .ImagePathName = app_name_us,
            .CommandLine = try windows.UNICODE_STRING.init(@constCast(cmd_line)),
            .Environment = env.ptr,

            .dwFlags = windows.STARTF_USESTDHANDLES,

            .WindowTitle = app_name_us,
            .Desktop = parent_params.Desktop,

            .EnvironmentSize = env.len * @sizeOf(u16),
            .ProcessGroupId = parent_params.ProcessGroupId,
        },
        &create_info,
        &windows.PS.ATTRIBUTE.LIST.init(.{
            .IMAGE_NAME = mem.sliceAsBytes(image_name.span()),
            .HANDLE_LIST = mem.sliceAsBytes(handle_list[0..handle_list_len]),
            .CHPE = @as(u8, 1), // ???
        }).List,
    )) {
        .SUCCESS => {},
        .ACCESS_VIOLATION => unreachable,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .OBJECT_PATH_SYNTAX_BAD => unreachable,
        .ACCESS_DENIED => return error.AccessDenied,
        .INVALID_PARAMETER => unreachable,
        .INVALID_IMAGE_WIN_16,
        .INVALID_IMAGE_NE_FORMAT,
        .INVALID_IMAGE_PROTECT,
        .INVALID_IMAGE_NOT_MZ,
        => return error.InvalidExe,
        else => |e| return windows.unexpectedStatus(e),
    }
}

const Pipe = struct {
    read: ?posix.fd_t,
    write: ?posix.fd_t,
};

fn windowsMakePipeIn(sattr: *const windows.SECURITY_ATTRIBUTES) !Pipe {
    var read: posix.fd_t = undefined;
    var write: posix.fd_t = undefined;
    try windows.CreatePipe(&read, &write, sattr);
    errdefer windowsDestroyPipe(.{ .read = read, .write = write });
    try windows.SetHandleInformation(write, windows.HANDLE_FLAG_INHERIT, 0);
    return .{ .read = read, .write = write };
}

fn windowsDestroyPipe(pipe: Pipe) void {
    if (pipe.read) |h| posix.close(h);
    if (pipe.write) |h| posix.close(h);
}

fn windowsMakePipeOut(sattr: *const windows.SECURITY_ATTRIBUTES, mode: enum {
    /// Create the read handle that can be used with overlapped IO ops.
    @"async",
    /// Create non-blocking read and write handles.
    nonblock,
}) !Pipe {
    var tmp_bufw: [128]u16 = undefined;

    // Anonymous pipes are built upon Named pipes.
    // https://docs.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-createpipe
    // Asynchronous (overlapped) read and write operations are not supported by anonymous pipes.
    // https://docs.microsoft.com/en-us/windows/win32/ipc/anonymous-pipe-operations
    const pipe_path = blk: {
        var tmp_buf: [128]u8 = undefined;
        // Forge a random path for the pipe.
        const pipe_path = std.fmt.bufPrintZ(
            &tmp_buf,
            "\\\\.\\pipe\\zig-childprocess-{d}-{d}",
            .{ windows.GetCurrentProcessId(), pipe_name_counter.fetchAdd(1, .monotonic) },
        ) catch unreachable;
        const len = std.unicode.wtf8ToWtf16Le(&tmp_bufw, pipe_path) catch unreachable;
        tmp_bufw[len] = 0;
        break :blk tmp_bufw[0..len :0];
    };

    const read_handle = windows.kernel32.CreateNamedPipeW(
        pipe_path.ptr,
        .{ .ACCESS = .INBOUND, .OVERLAPPED = switch (mode) {
            .@"async" => true,
            .nonblock => false,
        } },
        .{ .NOWAIT = switch (mode) {
            .@"async" => false,
            .nonblock => true,
        } },
        1,
        4096,
        4096,
        0,
        sattr,
    );
    if (read_handle == windows.INVALID_HANDLE_VALUE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
    errdefer posix.close(read_handle);

    var sattr_copy = sattr.*;
    const write_handle = windows.kernel32.CreateFileW(
        pipe_path.ptr,
        .{ .GENERIC = .{ .WRITE = true } },
        0,
        &sattr_copy,
        windows.OPEN_EXISTING,
        windows.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (write_handle == windows.INVALID_HANDLE_VALUE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
    errdefer posix.close(write_handle);

    try windows.SetHandleInformation(read_handle, windows.HANDLE_FLAG_INHERIT, 0);

    return .{ .read = read_handle, .write = write_handle };
}

var pipe_name_counter = std.atomic.Value(u32).init(1);

// Should be kept in sync with `windowsCreateProcessSupportsExtension`
const CreateProcessSupportedExtension = enum {
    bat,
    cmd,
    com,
    exe,
};

/// Case-insensitive WTF-16 lookup
fn windowsCreateProcessSupportsExtension(ext: []const u16) ?CreateProcessSupportedExtension {
    if (ext.len != 4) return null;
    const State = enum {
        start,
        dot,
        b,
        ba,
        c,
        cm,
        co,
        e,
        ex,
    };
    var state: State = .start;
    for (ext) |c| switch (state) {
        .start => switch (c) {
            '.' => state = .dot,
            else => return null,
        },
        .dot => switch (c) {
            'b', 'B' => state = .b,
            'c', 'C' => state = .c,
            'e', 'E' => state = .e,
            else => return null,
        },
        .b => switch (c) {
            'a', 'A' => state = .ba,
            else => return null,
        },
        .c => switch (c) {
            'm', 'M' => state = .cm,
            'o', 'O' => state = .co,
            else => return null,
        },
        .e => switch (c) {
            'x', 'X' => state = .ex,
            else => return null,
        },
        .ba => switch (c) {
            't', 'T' => return .bat,
            else => return null,
        },
        .cm => switch (c) {
            'd', 'D' => return .cmd,
            else => return null,
        },
        .co => switch (c) {
            'm', 'M' => return .com,
            else => return null,
        },
        .ex => switch (c) {
            'e', 'E' => return .exe,
            else => return null,
        },
    };
    return null;
}

test windowsCreateProcessSupportsExtension {
    try std.testing.expectEqual(CreateProcessSupportedExtension.exe, windowsCreateProcessSupportsExtension(&[_]u16{ '.', 'e', 'X', 'e' }).?);
    try std.testing.expect(windowsCreateProcessSupportsExtension(&[_]u16{ '.', 'e', 'X', 'e', 'c' }) == null);
}

/// Serializes argv into a WTF-16 encoded command-line string for use with CreateProcessW.
///
/// Serialization is done on-demand and the result is cached in order to allow for:
/// - Only serializing the particular type of command line needed (`.bat`/`.cmd`
///   command line serialization is different from `.exe`/etc)
/// - Reusing the serialized command lines if necessary (i.e. if the execution
///   of a command fails and the PATH is going to be continued to be searched
///   for more candidates)
const WindowsCommandLineCache = struct {
    cmd_line: ?[:0]u16 = null,
    script_cmd_line: ?[:0]u16 = null,
    cmd_exe_path: ?[:0]u16 = null,
    argv: []const []const u8,
    allocator: mem.Allocator,

    fn init(allocator: mem.Allocator, argv: []const []const u8) WindowsCommandLineCache {
        return .{
            .allocator = allocator,
            .argv = argv,
        };
    }

    fn deinit(cache: *WindowsCommandLineCache) void {
        if (cache.cmd_line) |cmd_line| cache.allocator.free(cmd_line);
        if (cache.script_cmd_line) |script_cmd_line| cache.allocator.free(script_cmd_line);
        if (cache.cmd_exe_path) |cmd_exe_path| cache.allocator.free(cmd_exe_path);
    }

    fn commandLine(cache: *WindowsCommandLineCache) ![:0]u16 {
        if (cache.cmd_line == null) {
            cache.cmd_line = try argvToCommandLineWindows(cache.allocator, cache.argv);
        }
        return cache.cmd_line.?;
    }

    /// Not cached, since the path to the batch script will change during PATH searching.
    /// `script_path` should be as qualified as possible, e.g. if the PATH is being searched,
    /// then script_path should include both the search path and the script filename
    /// (this allows avoiding cmd.exe having to search the PATH again).
    fn scriptCommandLine(cache: *WindowsCommandLineCache, script_path: []const u16) ![:0]u16 {
        if (cache.script_cmd_line) |v| cache.allocator.free(v);
        cache.script_cmd_line = try argvToScriptCommandLineWindows(
            cache.allocator,
            script_path,
            cache.argv[1..],
        );
        return cache.script_cmd_line.?;
    }

    fn cmdExePath(cache: *WindowsCommandLineCache) ![:0]u16 {
        if (cache.cmd_exe_path == null) {
            cache.cmd_exe_path = try windowsCmdExePath(cache.allocator);
        }
        return cache.cmd_exe_path.?;
    }
};

/// Returns the absolute path of `cmd.exe` within the Windows system directory.
/// The caller owns the returned slice.
fn windowsCmdExePath(allocator: mem.Allocator) error{ OutOfMemory, Unexpected }![:0]u16 {
    var buf = try std.ArrayListUnmanaged(u16).initCapacity(allocator, 128);
    errdefer buf.deinit(allocator);
    while (true) {
        const unused_slice = buf.unusedCapacitySlice();
        // TODO: Get the system directory from PEB.ReadOnlyStaticServerData
        const len = windows.kernel32.GetSystemDirectoryW(@ptrCast(unused_slice), @intCast(unused_slice.len));
        if (len == 0) {
            switch (windows.kernel32.GetLastError()) {
                else => |err| return windows.unexpectedError(err),
            }
        }
        if (len > unused_slice.len) {
            try buf.ensureUnusedCapacity(allocator, len);
        } else {
            buf.items.len = len;
            break;
        }
    }
    switch (buf.items[buf.items.len - 1]) {
        '/', '\\' => {},
        else => try buf.append(allocator, fs.path.sep),
    }
    try buf.appendSlice(allocator, unicode.utf8ToUtf16LeStringLiteral("cmd.exe"));
    return try buf.toOwnedSliceSentinel(allocator, 0);
}

const ArgvToCommandLineError = error{ OutOfMemory, InvalidWtf8, InvalidArg0 };

/// Serializes `argv` to a Windows command-line string suitable for passing to a child process and
/// parsing by the `CommandLineToArgvW` algorithm. The caller owns the returned slice.
///
/// To avoid arbitrary command execution, this function should not be used when spawning `.bat`/`.cmd` scripts.
/// https://flatt.tech/research/posts/batbadbut-you-cant-securely-execute-commands-on-windows/
///
/// When executing `.bat`/`.cmd` scripts, use `argvToScriptCommandLineWindows` instead.
fn argvToCommandLineWindows(
    allocator: mem.Allocator,
    argv: []const []const u8,
) ArgvToCommandLineError![:0]u16 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    if (argv.len != 0) {
        const arg0 = argv[0];

        // The first argument must be quoted if it contains spaces or ASCII control characters
        // (excluding DEL). It also follows special quoting rules where backslashes have no special
        // interpretation, which makes it impossible to pass certain first arguments containing
        // double quotes to a child process without characters from the first argument leaking into
        // subsequent ones (which could have security implications).
        //
        // Empty arguments technically don't need quotes, but we quote them anyway for maximum
        // compatibility with different implementations of the 'CommandLineToArgvW' algorithm.
        //
        // Double quotes are illegal in paths on Windows, so for the sake of simplicity we reject
        // all first arguments containing double quotes, even ones that we could theoretically
        // serialize in unquoted form.
        var needs_quotes = arg0.len == 0;
        for (arg0) |c| {
            if (c <= ' ') {
                needs_quotes = true;
            } else if (c == '"') {
                return error.InvalidArg0;
            }
        }
        if (needs_quotes) {
            try buf.append('"');
            try buf.appendSlice(arg0);
            try buf.append('"');
        } else {
            try buf.appendSlice(arg0);
        }

        for (argv[1..]) |arg| {
            try buf.append(' ');

            // Subsequent arguments must be quoted if they contain spaces, tabs or double quotes,
            // or if they are empty. For simplicity and for maximum compatibility with different
            // implementations of the 'CommandLineToArgvW' algorithm, we also quote all ASCII
            // control characters (again, excluding DEL).
            needs_quotes = for (arg) |c| {
                if (c <= ' ' or c == '"') {
                    break true;
                }
            } else arg.len == 0;
            if (!needs_quotes) {
                try buf.appendSlice(arg);
                continue;
            }

            try buf.append('"');
            var backslash_count: usize = 0;
            for (arg) |byte| {
                switch (byte) {
                    '\\' => {
                        backslash_count += 1;
                    },
                    '"' => {
                        try buf.appendNTimes('\\', backslash_count * 2 + 1);
                        try buf.append('"');
                        backslash_count = 0;
                    },
                    else => {
                        try buf.appendNTimes('\\', backslash_count);
                        try buf.append(byte);
                        backslash_count = 0;
                    },
                }
            }
            try buf.appendNTimes('\\', backslash_count * 2);
            try buf.append('"');
        }
    }

    return try unicode.wtf8ToWtf16LeAllocZ(allocator, buf.items);
}

test argvToCommandLineWindows {
    const t = testArgvToCommandLineWindows;

    try t(&.{
        \\C:\Program Files\zig\zig.exe
        ,
        \\run
        ,
        \\.\src\main.zig
        ,
        \\-target
        ,
        \\x86_64-windows-gnu
        ,
        \\-O
        ,
        \\ReleaseSafe
        ,
        \\--
        ,
        \\--emoji=🗿
        ,
        \\--eval=new Regex("Dwayne \"The Rock\" Johnson")
        ,
    },
        \\"C:\Program Files\zig\zig.exe" run .\src\main.zig -target x86_64-windows-gnu -O ReleaseSafe -- --emoji=🗿 "--eval=new Regex(\"Dwayne \\\"The Rock\\\" Johnson\")"
    );

    try t(&.{}, "");
    try t(&.{""}, "\"\"");
    try t(&.{" "}, "\" \"");
    try t(&.{"\t"}, "\"\t\"");
    try t(&.{"\x07"}, "\"\x07\"");
    try t(&.{"🦎"}, "🦎");

    try t(
        &.{ "zig", "aa aa", "bb\tbb", "cc\ncc", "dd\r\ndd", "ee\x7Fee" },
        "zig \"aa aa\" \"bb\tbb\" \"cc\ncc\" \"dd\r\ndd\" ee\x7Fee",
    );

    try t(
        &.{ "\\\\foo bar\\foo bar\\", "\\\\zig zag\\zig zag\\" },
        "\"\\\\foo bar\\foo bar\\\" \"\\\\zig zag\\zig zag\\\\\"",
    );

    try std.testing.expectError(
        error.InvalidArg0,
        argvToCommandLineWindows(std.testing.allocator, &.{"\"quotes\"quotes\""}),
    );
    try std.testing.expectError(
        error.InvalidArg0,
        argvToCommandLineWindows(std.testing.allocator, &.{"quotes\"quotes"}),
    );
    try std.testing.expectError(
        error.InvalidArg0,
        argvToCommandLineWindows(std.testing.allocator, &.{"q u o t e s \" q u o t e s"}),
    );
}

fn testArgvToCommandLineWindows(argv: []const []const u8, expected_cmd_line: []const u8) !void {
    const cmd_line_w = try argvToCommandLineWindows(std.testing.allocator, argv);
    defer std.testing.allocator.free(cmd_line_w);

    const cmd_line = try unicode.wtf16LeToWtf8Alloc(std.testing.allocator, cmd_line_w);
    defer std.testing.allocator.free(cmd_line);

    try std.testing.expectEqualStrings(expected_cmd_line, cmd_line);
}

const ArgvToScriptCommandLineError = error{
    OutOfMemory,
    InvalidWtf8,
    /// NUL (U+0000), LF (U+000A), CR (U+000D) are not allowed
    /// within arguments when executing a `.bat`/`.cmd` script.
    /// - NUL/LF signifiies end of arguments, so anything afterwards
    ///   would be lost after execution.
    /// - CR is stripped by `cmd.exe`, so any CR codepoints
    ///   would be lost after execution.
    InvalidBatchScriptArg,
};

/// Serializes `argv` to a Windows command-line string that uses `cmd.exe /c` and `cmd.exe`-specific
/// escaping rules. The caller owns the returned slice.
///
/// Escapes `argv` using the suggested mitigation against arbitrary command execution from:
/// https://flatt.tech/research/posts/batbadbut-you-cant-securely-execute-commands-on-windows/
///
/// The return of this function will look like
/// `cmd.exe /d /e:ON /v:OFF /c "<escaped command line>"`
/// and should be used as the `lpCommandLine` of `CreateProcessW`, while the
/// return of `windowsCmdExePath` should be used as `lpApplicationName`.
///
/// Should only be used when spawning `.bat`/`.cmd` scripts, see `argvToCommandLineWindows` otherwise.
/// The `.bat`/`.cmd` file must be known to both have the `.bat`/`.cmd` extension and exist on the filesystem.
fn argvToScriptCommandLineWindows(
    allocator: mem.Allocator,
    /// Path to the `.bat`/`.cmd` script. If this path is relative, it is assumed to be relative to the CWD.
    /// The script must have been verified to exist at this path before calling this function.
    script_path: []const u16,
    /// Arguments, not including the script name itself. Expected to be encoded as WTF-8.
    script_args: []const []const u8,
) ArgvToScriptCommandLineError![:0]u16 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 64);
    defer buf.deinit();

    // `/d` disables execution of AutoRun commands.
    // `/e:ON` and `/v:OFF` are needed for BatBadBut mitigation:
    // > If delayed expansion is enabled via the registry value DelayedExpansion,
    // > it must be disabled by explicitly calling cmd.exe with the /V:OFF option.
    // > Escaping for % requires the command extension to be enabled.
    // > If it’s disabled via the registry value EnableExtensions, it must be enabled with the /E:ON option.
    // https://flatt.tech/research/posts/batbadbut-you-cant-securely-execute-commands-on-windows/
    buf.appendSliceAssumeCapacity("cmd.exe /d /e:ON /v:OFF /c \"");

    // Always quote the path to the script arg
    buf.appendAssumeCapacity('"');
    // We always want the path to the batch script to include a path separator in order to
    // avoid cmd.exe searching the PATH for the script. This is not part of the arbitrary
    // command execution mitigation, we just know exactly what script we want to execute
    // at this point, and potentially making cmd.exe re-find it is unnecessary.
    //
    // If the script path does not have a path separator, then we know its relative to CWD and
    // we can just put `.\` in the front.
    if (mem.indexOfAny(u16, script_path, &[_]u16{ mem.nativeToLittle(u16, '\\'), mem.nativeToLittle(u16, '/') }) == null) {
        try buf.appendSlice(".\\");
    }
    // Note that we don't do any escaping/mitigations for this argument, since the relevant
    // characters (", %, etc) are illegal in file paths and this function should only be called
    // with script paths that have been verified to exist.
    try unicode.wtf16LeToWtf8ArrayList(&buf, script_path);
    buf.appendAssumeCapacity('"');

    for (script_args) |arg| {
        // Literal carriage returns get stripped when run through cmd.exe
        // and NUL/newlines act as 'end of command.' Because of this, it's basically
        // always a mistake to include these characters in argv, so it's
        // an error condition in order to ensure that the return of this
        // function can always roundtrip through cmd.exe.
        if (std.mem.indexOfAny(u8, arg, "\x00\r\n") != null) {
            return error.InvalidBatchScriptArg;
        }

        // Separate args with a space.
        try buf.append(' ');

        // Need to quote if the argument is empty (otherwise the arg would just be lost)
        // or if the last character is a `\`, since then something like "%~2" in a .bat
        // script would cause the closing " to be escaped which we don't want.
        var needs_quotes = arg.len == 0 or arg[arg.len - 1] == '\\';
        if (!needs_quotes) {
            for (arg) |c| {
                switch (c) {
                    // Known good characters that don't need to be quoted
                    'A'...'Z', 'a'...'z', '0'...'9', '#', '$', '*', '+', '-', '.', '/', ':', '?', '@', '\\', '_' => {},
                    // When in doubt, quote
                    else => {
                        needs_quotes = true;
                        break;
                    },
                }
            }
        }
        if (needs_quotes) {
            try buf.append('"');
        }
        var backslashes: usize = 0;
        for (arg) |c| {
            switch (c) {
                '\\' => {
                    backslashes += 1;
                },
                '"' => {
                    try buf.appendNTimes('\\', backslashes);
                    try buf.append('"');
                    backslashes = 0;
                },
                // Replace `%` with `%%cd:~,%`.
                //
                // cmd.exe allows extracting a substring from an environment
                // variable with the syntax: `%foo:~<start_index>,<end_index>%`.
                // Therefore, `%cd:~,%` will always expand to an empty string
                // since both the start and end index are blank, and it is assumed
                // that `%cd%` is always available since it is a built-in variable
                // that corresponds to the current directory.
                //
                // This means that replacing `%foo%` with `%%cd:~,%foo%%cd:~,%`
                // will stop `%foo%` from being expanded and *after* expansion
                // we'll still be left with `%foo%` (the literal string).
                '%' => {
                    // the trailing `%` is appended outside the switch
                    try buf.appendSlice("%%cd:~,");
                    backslashes = 0;
                },
                else => {
                    backslashes = 0;
                },
            }
            try buf.append(c);
        }
        if (needs_quotes) {
            try buf.appendNTimes('\\', backslashes);
            try buf.append('"');
        }
    }

    try buf.append('"');

    return try unicode.wtf8ToWtf16LeAllocZ(allocator, buf.items);
}
