const std = @import("std.zig");
const builtin = @import("builtin");
const unicode = std.unicode;
const io = std.io;
const fs = std.fs;
const os = std.os;
const process = std.process;
const File = std.fs.File;
const windows = os.windows;
const linux = os.linux;
const mem = std.mem;
const math = std.math;
const debug = std.debug;
const EnvMap = process.EnvMap;
const Os = std.builtin.Os;
const TailQueue = std.TailQueue;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;

pub const ChildProcess = struct {
    pub const Id = switch (builtin.os.tag) {
        .windows => windows.HANDLE,
        .wasi => void,
        else => os.pid_t,
    };

    /// Available after calling `spawn()`. This becomes `undefined` after calling `wait()`.
    /// On Windows this is the hProcess.
    /// On POSIX this is the pid.
    id: Id,
    thread_handle: if (builtin.os.tag == .windows) windows.HANDLE else void,

    allocator: mem.Allocator,

    stdin: ?File,
    stdout: ?File,
    stderr: ?File,

    term: ?(SpawnError!Term),

    argv: []const []const u8,

    /// Leave as null to use the current env map using the supplied allocator.
    env_map: ?*const EnvMap,

    stdin_behavior: StdIo,
    stdout_behavior: StdIo,
    stderr_behavior: StdIo,

    /// Set to change the user id when spawning the child process.
    uid: if (builtin.os.tag == .windows or builtin.os.tag == .wasi) void else ?os.uid_t,

    /// Set to change the group id when spawning the child process.
    gid: if (builtin.os.tag == .windows or builtin.os.tag == .wasi) void else ?os.gid_t,

    /// Set to change the current working directory when spawning the child process.
    cwd: ?[]const u8,
    /// Set to change the current working directory when spawning the child process.
    /// This is not yet implemented for Windows. See https://github.com/ziglang/zig/issues/5190
    /// Once that is done, `cwd` will be deprecated in favor of this field.
    cwd_dir: ?fs.Dir = null,

    err_pipe: ?if (builtin.os.tag == .windows) void else [2]os.fd_t,

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

    pub const ResourceUsageStatistics = struct {
        rusage: @TypeOf(rusage_init) = rusage_init,

        /// Returns the peak resident set size of the child process, in bytes,
        /// if available.
        pub inline fn getMaxRss(rus: ResourceUsageStatistics) ?usize {
            switch (builtin.os.tag) {
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

        const rusage_init = switch (builtin.os.tag) {
            .linux, .macos, .ios => @as(?std.os.rusage, null),
            .windows => @as(?windows.VM_COUNTERS, null),
            else => {},
        };
    };

    pub const Arg0Expand = os.Arg0Expand;

    pub const SpawnError = error{
        OutOfMemory,

        /// POSIX-only. `StdIo.Ignore` was selected and opening `/dev/null` returned ENODEV.
        NoDevice,

        /// Windows-only. One of:
        /// * `cwd` was provided and it could not be re-encoded into UTF16LE, or
        /// * The `PATH` or `PATHEXT` environment variable contained invalid UTF-8.
        InvalidUtf8,

        /// Windows-only. `cwd` was provided, but the path did not exist when spawning the child process.
        CurrentWorkingDirectoryUnlinked,
    } ||
        os.ExecveError ||
        os.SetIdError ||
        os.ChangeCurDirError ||
        windows.CreateProcessError ||
        windows.GetProcessMemoryInfoError ||
        windows.WaitForSingleObjectError;

    pub const Term = union(enum) {
        Exited: u8,
        Signal: u32,
        Stopped: u32,
        Unknown: u32,
    };

    pub const StdIo = enum {
        Inherit,
        Ignore,
        Pipe,
        Close,
    };

    /// First argument in argv is the executable.
    pub fn init(argv: []const []const u8, allocator: mem.Allocator) ChildProcess {
        return .{
            .allocator = allocator,
            .argv = argv,
            .id = undefined,
            .thread_handle = undefined,
            .err_pipe = null,
            .term = null,
            .env_map = null,
            .cwd = null,
            .uid = if (builtin.os.tag == .windows or builtin.os.tag == .wasi) {} else null,
            .gid = if (builtin.os.tag == .windows or builtin.os.tag == .wasi) {} else null,
            .stdin = null,
            .stdout = null,
            .stderr = null,
            .stdin_behavior = StdIo.Inherit,
            .stdout_behavior = StdIo.Inherit,
            .stderr_behavior = StdIo.Inherit,
            .expand_arg0 = .no_expand,
        };
    }

    pub fn setUserName(self: *ChildProcess, name: []const u8) !void {
        const user_info = try std.process.getUserInfo(name);
        self.uid = user_info.uid;
        self.gid = user_info.gid;
    }

    /// On success must call `kill` or `wait`.
    /// After spawning the `id` is available.
    pub fn spawn(self: *ChildProcess) SpawnError!void {
        if (!std.process.can_spawn) {
            @compileError("the target operating system cannot spawn processes");
        }

        if (builtin.os.tag == .windows) {
            return self.spawnWindows();
        } else {
            return self.spawnPosix();
        }
    }

    pub fn spawnAndWait(self: *ChildProcess) SpawnError!Term {
        try self.spawn();
        return self.wait();
    }

    /// Forcibly terminates child process and then cleans up all resources.
    pub fn kill(self: *ChildProcess) !Term {
        if (builtin.os.tag == .windows) {
            return self.killWindows(1);
        } else {
            return self.killPosix();
        }
    }

    pub fn killWindows(self: *ChildProcess, exit_code: windows.UINT) !Term {
        if (self.term) |term| {
            self.cleanupStreams();
            return term;
        }

        try windows.TerminateProcess(self.id, exit_code);
        try self.waitUnwrappedWindows();
        return self.term.?;
    }

    pub fn killPosix(self: *ChildProcess) !Term {
        if (self.term) |term| {
            self.cleanupStreams();
            return term;
        }
        try os.kill(self.id, os.SIG.TERM);
        try self.waitUnwrapped();
        return self.term.?;
    }

    /// Blocks until child process terminates and then cleans up all resources.
    pub fn wait(self: *ChildProcess) !Term {
        const term = if (builtin.os.tag == .windows)
            try self.waitWindows()
        else
            try self.waitPosix();

        self.id = undefined;

        return term;
    }

    pub const ExecResult = struct {
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
        child: ChildProcess,
        stdout: *std.ArrayList(u8),
        stderr: *std.ArrayList(u8),
        max_output_bytes: usize,
    ) !void {
        debug.assert(child.stdout_behavior == .Pipe);
        debug.assert(child.stderr_behavior == .Pipe);

        // we could make this work with multiple allocators but YAGNI
        if (stdout.allocator.ptr != stderr.allocator.ptr or
            stdout.allocator.vtable != stderr.allocator.vtable)
            @panic("ChildProcess.collectOutput only supports 1 allocator");

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

    pub const ExecError = os.GetCwdError || os.ReadError || SpawnError || os.PollError || error{
        StdoutStreamTooLong,
        StderrStreamTooLong,
    };

    /// Spawns a child process, waits for it, collecting stdout and stderr, and then returns.
    /// If it succeeds, the caller owns result.stdout and result.stderr memory.
    pub fn exec(args: struct {
        allocator: mem.Allocator,
        argv: []const []const u8,
        cwd: ?[]const u8 = null,
        cwd_dir: ?fs.Dir = null,
        env_map: ?*const EnvMap = null,
        max_output_bytes: usize = 50 * 1024,
        expand_arg0: Arg0Expand = .no_expand,
    }) ExecError!ExecResult {
        var child = ChildProcess.init(args.argv, args.allocator);
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

        return ExecResult{
            .term = try child.wait(),
            .stdout = try stdout.toOwnedSlice(),
            .stderr = try stderr.toOwnedSlice(),
        };
    }

    fn waitWindows(self: *ChildProcess) !Term {
        if (self.term) |term| {
            self.cleanupStreams();
            return term;
        }

        try self.waitUnwrappedWindows();
        return self.term.?;
    }

    fn waitPosix(self: *ChildProcess) !Term {
        if (self.term) |term| {
            self.cleanupStreams();
            return term;
        }

        try self.waitUnwrapped();
        return self.term.?;
    }

    fn waitUnwrappedWindows(self: *ChildProcess) !void {
        const result = windows.WaitForSingleObjectEx(self.id, windows.INFINITE, false);

        self.term = @as(SpawnError!Term, x: {
            var exit_code: windows.DWORD = undefined;
            if (windows.kernel32.GetExitCodeProcess(self.id, &exit_code) == 0) {
                break :x Term{ .Unknown = 0 };
            } else {
                break :x Term{ .Exited = @as(u8, @truncate(exit_code)) };
            }
        });

        if (self.request_resource_usage_statistics) {
            self.resource_usage_statistics.rusage = try windows.GetProcessMemoryInfo(self.id);
        }

        os.close(self.id);
        os.close(self.thread_handle);
        self.cleanupStreams();
        return result;
    }

    fn waitUnwrapped(self: *ChildProcess) !void {
        const res: os.WaitPidResult = res: {
            if (self.request_resource_usage_statistics) {
                switch (builtin.os.tag) {
                    .linux, .macos, .ios => {
                        var ru: std.os.rusage = undefined;
                        const res = os.wait4(self.id, 0, &ru);
                        self.resource_usage_statistics.rusage = ru;
                        break :res res;
                    },
                    else => {},
                }
            }

            break :res os.waitpid(self.id, 0);
        };
        const status = res.status;
        self.cleanupStreams();
        self.handleWaitResult(status);
    }

    fn handleWaitResult(self: *ChildProcess, status: u32) void {
        self.term = self.cleanupAfterWait(status);
    }

    fn cleanupStreams(self: *ChildProcess) void {
        if (self.stdin) |*stdin| {
            stdin.close();
            self.stdin = null;
        }
        if (self.stdout) |*stdout| {
            stdout.close();
            self.stdout = null;
        }
        if (self.stderr) |*stderr| {
            stderr.close();
            self.stderr = null;
        }
    }

    fn cleanupAfterWait(self: *ChildProcess, status: u32) !Term {
        if (self.err_pipe) |err_pipe| {
            defer destroyPipe(err_pipe);

            if (builtin.os.tag == .linux) {
                var fd = [1]std.os.pollfd{std.os.pollfd{
                    .fd = err_pipe[0],
                    .events = std.os.POLL.IN,
                    .revents = undefined,
                }};

                // Check if the eventfd buffer stores a non-zero value by polling
                // it, that's the error code returned by the child process.
                _ = std.os.poll(&fd, 0) catch unreachable;

                // According to eventfd(2) the descriptor is readable if the counter
                // has a value greater than 0
                if ((fd[0].revents & std.os.POLL.IN) != 0) {
                    const err_int = try readIntFd(err_pipe[0]);
                    return @as(SpawnError, @errSetCast(@errorFromInt(err_int)));
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
                    return @as(SpawnError, @errSetCast(@errorFromInt(err_int)));
                }
            }
        }

        return statusToTerm(status);
    }

    fn statusToTerm(status: u32) Term {
        return if (os.W.IFEXITED(status))
            Term{ .Exited = os.W.EXITSTATUS(status) }
        else if (os.W.IFSIGNALED(status))
            Term{ .Signal = os.W.TERMSIG(status) }
        else if (os.W.IFSTOPPED(status))
            Term{ .Stopped = os.W.STOPSIG(status) }
        else
            Term{ .Unknown = status };
    }

    fn spawnPosix(self: *ChildProcess) SpawnError!void {
        const pipe_flags = if (io.is_async) os.O.NONBLOCK else 0;
        const stdin_pipe = if (self.stdin_behavior == StdIo.Pipe) try os.pipe2(pipe_flags) else undefined;
        errdefer if (self.stdin_behavior == StdIo.Pipe) {
            destroyPipe(stdin_pipe);
        };

        const stdout_pipe = if (self.stdout_behavior == StdIo.Pipe) try os.pipe2(pipe_flags) else undefined;
        errdefer if (self.stdout_behavior == StdIo.Pipe) {
            destroyPipe(stdout_pipe);
        };

        const stderr_pipe = if (self.stderr_behavior == StdIo.Pipe) try os.pipe2(pipe_flags) else undefined;
        errdefer if (self.stderr_behavior == StdIo.Pipe) {
            destroyPipe(stderr_pipe);
        };

        const any_ignore = (self.stdin_behavior == StdIo.Ignore or self.stdout_behavior == StdIo.Ignore or self.stderr_behavior == StdIo.Ignore);
        const dev_null_fd = if (any_ignore)
            os.openZ("/dev/null", os.O.RDWR, 0) catch |err| switch (err) {
                error.PathAlreadyExists => unreachable,
                error.NoSpaceLeft => unreachable,
                error.FileTooBig => unreachable,
                error.DeviceBusy => unreachable,
                error.FileLocksNotSupported => unreachable,
                error.BadPathName => unreachable, // Windows-only
                error.InvalidHandle => unreachable, // WASI-only
                error.WouldBlock => unreachable,
                error.NetworkNotFound => unreachable, // Windows-only
                else => |e| return e,
            }
        else
            undefined;
        defer {
            if (any_ignore) os.close(dev_null_fd);
        }

        var arena_allocator = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        // The POSIX standard does not allow malloc() between fork() and execve(),
        // and `self.allocator` may be a libc allocator.
        // I have personally observed the child process deadlocking when it tries
        // to call malloc() due to a heap allocation between fork() and execve(),
        // in musl v1.1.24.
        // Additionally, we want to reduce the number of possible ways things
        // can fail between fork() and execve().
        // Therefore, we do all the allocation for the execve() before the fork().
        // This means we must do the null-termination of argv and env vars here.
        const argv_buf = try arena.allocSentinel(?[*:0]const u8, self.argv.len, null);
        for (self.argv, 0..) |arg, i| argv_buf[i] = (try arena.dupeZ(u8, arg)).ptr;

        const envp = m: {
            if (self.env_map) |env_map| {
                const envp_buf = try createNullDelimitedEnvMap(arena, env_map);
                break :m envp_buf.ptr;
            } else if (builtin.link_libc) {
                break :m std.c.environ;
            } else if (builtin.output_mode == .Exe) {
                // Then we have Zig start code and this works.
                // TODO type-safety for null-termination of `os.environ`.
                break :m @as([*:null]const ?[*:0]const u8, @ptrCast(os.environ.ptr));
            } else {
                // TODO come up with a solution for this.
                @compileError("missing std lib enhancement: ChildProcess implementation has no way to collect the environment variables to forward to the child process");
            }
        };

        // This pipe is used to communicate errors between the time of fork
        // and execve from the child process to the parent process.
        const err_pipe = blk: {
            if (builtin.os.tag == .linux) {
                const fd = try os.eventfd(0, linux.EFD.CLOEXEC);
                // There's no distinction between the readable and the writeable
                // end with eventfd
                break :blk [2]os.fd_t{ fd, fd };
            } else {
                break :blk try os.pipe2(os.O.CLOEXEC);
            }
        };
        errdefer destroyPipe(err_pipe);

        const pid_result = try os.fork();
        if (pid_result == 0) {
            // we are the child
            setUpChildIo(self.stdin_behavior, stdin_pipe[0], os.STDIN_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(self.stdout_behavior, stdout_pipe[1], os.STDOUT_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(self.stderr_behavior, stderr_pipe[1], os.STDERR_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);

            if (self.stdin_behavior == .Pipe) {
                os.close(stdin_pipe[0]);
                os.close(stdin_pipe[1]);
            }
            if (self.stdout_behavior == .Pipe) {
                os.close(stdout_pipe[0]);
                os.close(stdout_pipe[1]);
            }
            if (self.stderr_behavior == .Pipe) {
                os.close(stderr_pipe[0]);
                os.close(stderr_pipe[1]);
            }

            if (self.cwd_dir) |cwd| {
                os.fchdir(cwd.fd) catch |err| forkChildErrReport(err_pipe[1], err);
            } else if (self.cwd) |cwd| {
                os.chdir(cwd) catch |err| forkChildErrReport(err_pipe[1], err);
            }

            if (self.gid) |gid| {
                os.setregid(gid, gid) catch |err| forkChildErrReport(err_pipe[1], err);
            }

            if (self.uid) |uid| {
                os.setreuid(uid, uid) catch |err| forkChildErrReport(err_pipe[1], err);
            }

            const err = switch (self.expand_arg0) {
                .expand => os.execvpeZ_expandArg0(.expand, argv_buf.ptr[0].?, argv_buf.ptr, envp),
                .no_expand => os.execvpeZ_expandArg0(.no_expand, argv_buf.ptr[0].?, argv_buf.ptr, envp),
            };
            forkChildErrReport(err_pipe[1], err);
        }

        // we are the parent
        const pid = @as(i32, @intCast(pid_result));
        if (self.stdin_behavior == StdIo.Pipe) {
            self.stdin = File{ .handle = stdin_pipe[1] };
        } else {
            self.stdin = null;
        }
        if (self.stdout_behavior == StdIo.Pipe) {
            self.stdout = File{ .handle = stdout_pipe[0] };
        } else {
            self.stdout = null;
        }
        if (self.stderr_behavior == StdIo.Pipe) {
            self.stderr = File{ .handle = stderr_pipe[0] };
        } else {
            self.stderr = null;
        }

        self.id = pid;
        self.err_pipe = err_pipe;
        self.term = null;

        if (self.stdin_behavior == StdIo.Pipe) {
            os.close(stdin_pipe[0]);
        }
        if (self.stdout_behavior == StdIo.Pipe) {
            os.close(stdout_pipe[1]);
        }
        if (self.stderr_behavior == StdIo.Pipe) {
            os.close(stderr_pipe[1]);
        }
    }

    fn spawnWindows(self: *ChildProcess) SpawnError!void {
        const saAttr = windows.SECURITY_ATTRIBUTES{
            .nLength = @sizeOf(windows.SECURITY_ATTRIBUTES),
            .bInheritHandle = windows.TRUE,
            .lpSecurityDescriptor = null,
        };

        const any_ignore = (self.stdin_behavior == StdIo.Ignore or self.stdout_behavior == StdIo.Ignore or self.stderr_behavior == StdIo.Ignore);

        const nul_handle = if (any_ignore)
            // "\Device\Null" or "\??\NUL"
            windows.OpenFile(&[_]u16{ '\\', 'D', 'e', 'v', 'i', 'c', 'e', '\\', 'N', 'u', 'l', 'l' }, .{
                .access_mask = windows.GENERIC_READ | windows.SYNCHRONIZE,
                .share_access = windows.FILE_SHARE_READ,
                .creation = windows.OPEN_EXISTING,
                .io_mode = .blocking,
            }) catch |err| switch (err) {
                error.PathAlreadyExists => unreachable, // not possible for "NUL"
                error.PipeBusy => unreachable, // not possible for "NUL"
                error.FileNotFound => unreachable, // not possible for "NUL"
                error.AccessDenied => unreachable, // not possible for "NUL"
                error.NameTooLong => unreachable, // not possible for "NUL"
                error.WouldBlock => unreachable, // not possible for "NUL"
                error.NetworkNotFound => unreachable, // not possible for "NUL"
                else => |e| return e,
            }
        else
            undefined;
        defer {
            if (any_ignore) os.close(nul_handle);
        }
        if (any_ignore) {
            try windows.SetHandleInformation(nul_handle, windows.HANDLE_FLAG_INHERIT, 0);
        }

        var g_hChildStd_IN_Rd: ?windows.HANDLE = null;
        var g_hChildStd_IN_Wr: ?windows.HANDLE = null;
        switch (self.stdin_behavior) {
            StdIo.Pipe => {
                try windowsMakePipeIn(&g_hChildStd_IN_Rd, &g_hChildStd_IN_Wr, &saAttr);
            },
            StdIo.Ignore => {
                g_hChildStd_IN_Rd = nul_handle;
            },
            StdIo.Inherit => {
                g_hChildStd_IN_Rd = windows.GetStdHandle(windows.STD_INPUT_HANDLE) catch null;
            },
            StdIo.Close => {
                g_hChildStd_IN_Rd = null;
            },
        }
        errdefer if (self.stdin_behavior == StdIo.Pipe) {
            windowsDestroyPipe(g_hChildStd_IN_Rd, g_hChildStd_IN_Wr);
        };

        var g_hChildStd_OUT_Rd: ?windows.HANDLE = null;
        var g_hChildStd_OUT_Wr: ?windows.HANDLE = null;
        switch (self.stdout_behavior) {
            StdIo.Pipe => {
                try windowsMakeAsyncPipe(&g_hChildStd_OUT_Rd, &g_hChildStd_OUT_Wr, &saAttr);
            },
            StdIo.Ignore => {
                g_hChildStd_OUT_Wr = nul_handle;
            },
            StdIo.Inherit => {
                g_hChildStd_OUT_Wr = windows.GetStdHandle(windows.STD_OUTPUT_HANDLE) catch null;
            },
            StdIo.Close => {
                g_hChildStd_OUT_Wr = null;
            },
        }
        errdefer if (self.stdin_behavior == StdIo.Pipe) {
            windowsDestroyPipe(g_hChildStd_OUT_Rd, g_hChildStd_OUT_Wr);
        };

        var g_hChildStd_ERR_Rd: ?windows.HANDLE = null;
        var g_hChildStd_ERR_Wr: ?windows.HANDLE = null;
        switch (self.stderr_behavior) {
            StdIo.Pipe => {
                try windowsMakeAsyncPipe(&g_hChildStd_ERR_Rd, &g_hChildStd_ERR_Wr, &saAttr);
            },
            StdIo.Ignore => {
                g_hChildStd_ERR_Wr = nul_handle;
            },
            StdIo.Inherit => {
                g_hChildStd_ERR_Wr = windows.GetStdHandle(windows.STD_ERROR_HANDLE) catch null;
            },
            StdIo.Close => {
                g_hChildStd_ERR_Wr = null;
            },
        }
        errdefer if (self.stdin_behavior == StdIo.Pipe) {
            windowsDestroyPipe(g_hChildStd_ERR_Rd, g_hChildStd_ERR_Wr);
        };

        const cmd_line = try windowsCreateCommandLine(self.allocator, self.argv);
        defer self.allocator.free(cmd_line);

        var siStartInfo = windows.STARTUPINFOW{
            .cb = @sizeOf(windows.STARTUPINFOW),
            .hStdError = g_hChildStd_ERR_Wr,
            .hStdOutput = g_hChildStd_OUT_Wr,
            .hStdInput = g_hChildStd_IN_Rd,
            .dwFlags = windows.STARTF_USESTDHANDLES,

            .lpReserved = null,
            .lpDesktop = null,
            .lpTitle = null,
            .dwX = 0,
            .dwY = 0,
            .dwXSize = 0,
            .dwYSize = 0,
            .dwXCountChars = 0,
            .dwYCountChars = 0,
            .dwFillAttribute = 0,
            .wShowWindow = 0,
            .cbReserved2 = 0,
            .lpReserved2 = null,
        };
        var piProcInfo: windows.PROCESS_INFORMATION = undefined;

        const cwd_w = if (self.cwd) |cwd| try unicode.utf8ToUtf16LeWithNull(self.allocator, cwd) else null;
        defer if (cwd_w) |cwd| self.allocator.free(cwd);
        const cwd_w_ptr = if (cwd_w) |cwd| cwd.ptr else null;

        const maybe_envp_buf = if (self.env_map) |env_map| try createWindowsEnvBlock(self.allocator, env_map) else null;
        defer if (maybe_envp_buf) |envp_buf| self.allocator.free(envp_buf);
        const envp_ptr = if (maybe_envp_buf) |envp_buf| envp_buf.ptr else null;

        const app_name_utf8 = self.argv[0];
        const app_name_is_absolute = fs.path.isAbsolute(app_name_utf8);

        // the cwd set in ChildProcess is in effect when choosing the executable path
        // to match posix semantics
        var cwd_path_w_needs_free = false;
        const cwd_path_w = x: {
            // If the app name is absolute, then we need to use its dirname as the cwd
            if (app_name_is_absolute) {
                cwd_path_w_needs_free = true;
                const dir = fs.path.dirname(app_name_utf8).?;
                break :x try unicode.utf8ToUtf16LeWithNull(self.allocator, dir);
            } else if (self.cwd) |cwd| {
                cwd_path_w_needs_free = true;
                break :x try unicode.utf8ToUtf16LeWithNull(self.allocator, cwd);
            } else {
                break :x &[_:0]u16{}; // empty for cwd
            }
        };
        defer if (cwd_path_w_needs_free) self.allocator.free(cwd_path_w);

        // If the app name has more than just a filename, then we need to separate that
        // into the basename and dirname and use the dirname as an addition to the cwd
        // path. This is because NtQueryDirectoryFile cannot accept FileName params with
        // path separators.
        const app_basename_utf8 = fs.path.basename(app_name_utf8);
        // If the app name is absolute, then the cwd will already have the app's dirname in it,
        // so only populate app_dirname if app name is a relative path with > 0 path separators.
        const maybe_app_dirname_utf8 = if (!app_name_is_absolute) fs.path.dirname(app_name_utf8) else null;
        const app_dirname_w: ?[:0]u16 = x: {
            if (maybe_app_dirname_utf8) |app_dirname_utf8| {
                break :x try unicode.utf8ToUtf16LeWithNull(self.allocator, app_dirname_utf8);
            }
            break :x null;
        };
        defer if (app_dirname_w != null) self.allocator.free(app_dirname_w.?);

        const app_name_w = try unicode.utf8ToUtf16LeWithNull(self.allocator, app_basename_utf8);
        defer self.allocator.free(app_name_w);

        const cmd_line_w = try unicode.utf8ToUtf16LeWithNull(self.allocator, cmd_line);
        defer self.allocator.free(cmd_line_w);

        exec: {
            const PATH: [:0]const u16 = std.os.getenvW(unicode.utf8ToUtf16LeStringLiteral("PATH")) orelse &[_:0]u16{};
            const PATHEXT: [:0]const u16 = std.os.getenvW(unicode.utf8ToUtf16LeStringLiteral("PATHEXT")) orelse &[_:0]u16{};

            var app_buf = std.ArrayListUnmanaged(u16){};
            defer app_buf.deinit(self.allocator);

            try app_buf.appendSlice(self.allocator, app_name_w);

            var dir_buf = std.ArrayListUnmanaged(u16){};
            defer dir_buf.deinit(self.allocator);

            if (cwd_path_w.len > 0) {
                try dir_buf.appendSlice(self.allocator, cwd_path_w);
            }
            if (app_dirname_w) |app_dir| {
                if (dir_buf.items.len > 0) try dir_buf.append(self.allocator, fs.path.sep);
                try dir_buf.appendSlice(self.allocator, app_dir);
            }
            if (dir_buf.items.len > 0) {
                // Need to normalize the path, openDirW can't handle things like double backslashes
                const normalized_len = windows.normalizePath(u16, dir_buf.items) catch return error.BadPathName;
                dir_buf.shrinkRetainingCapacity(normalized_len);
            }

            windowsCreateProcessPathExt(self.allocator, &dir_buf, &app_buf, PATHEXT, cmd_line_w.ptr, envp_ptr, cwd_w_ptr, &siStartInfo, &piProcInfo) catch |no_path_err| {
                var original_err = switch (no_path_err) {
                    error.FileNotFound, error.InvalidExe, error.AccessDenied => |e| e,
                    error.UnrecoverableInvalidExe => return error.InvalidExe,
                    else => |e| return e,
                };

                // If the app name had path separators, that disallows PATH searching,
                // and there's no need to search the PATH if the app name is absolute.
                // We still search the path if the cwd is absolute because of the
                // "cwd set in ChildProcess is in effect when choosing the executable path
                // to match posix semantics" behavior--we don't want to skip searching
                // the PATH just because we were trying to set the cwd of the child process.
                if (app_dirname_w != null or app_name_is_absolute) {
                    return original_err;
                }

                var it = mem.tokenizeScalar(u16, PATH, ';');
                while (it.next()) |search_path| {
                    dir_buf.clearRetainingCapacity();
                    try dir_buf.appendSlice(self.allocator, search_path);
                    // Need to normalize the path, some PATH values can contain things like double
                    // backslashes which openDirW can't handle
                    const normalized_len = windows.normalizePath(u16, dir_buf.items) catch continue;
                    dir_buf.shrinkRetainingCapacity(normalized_len);

                    if (windowsCreateProcessPathExt(self.allocator, &dir_buf, &app_buf, PATHEXT, cmd_line_w.ptr, envp_ptr, cwd_w_ptr, &siStartInfo, &piProcInfo)) {
                        break :exec;
                    } else |err| switch (err) {
                        error.FileNotFound, error.AccessDenied, error.InvalidExe => continue,
                        error.UnrecoverableInvalidExe => return error.InvalidExe,
                        else => |e| return e,
                    }
                } else {
                    return original_err;
                }
            };
        }

        if (g_hChildStd_IN_Wr) |h| {
            self.stdin = File{ .handle = h };
        } else {
            self.stdin = null;
        }
        if (g_hChildStd_OUT_Rd) |h| {
            self.stdout = File{ .handle = h };
        } else {
            self.stdout = null;
        }
        if (g_hChildStd_ERR_Rd) |h| {
            self.stderr = File{ .handle = h };
        } else {
            self.stderr = null;
        }

        self.id = piProcInfo.hProcess;
        self.thread_handle = piProcInfo.hThread;
        self.term = null;

        if (self.stdin_behavior == StdIo.Pipe) {
            os.close(g_hChildStd_IN_Rd.?);
        }
        if (self.stderr_behavior == StdIo.Pipe) {
            os.close(g_hChildStd_ERR_Wr.?);
        }
        if (self.stdout_behavior == StdIo.Pipe) {
            os.close(g_hChildStd_OUT_Wr.?);
        }
    }

    fn setUpChildIo(stdio: StdIo, pipe_fd: i32, std_fileno: i32, dev_null_fd: i32) !void {
        switch (stdio) {
            .Pipe => try os.dup2(pipe_fd, std_fileno),
            .Close => os.close(std_fileno),
            .Inherit => {},
            .Ignore => try os.dup2(dev_null_fd, std_fileno),
        }
    }
};

/// Expects `app_buf` to contain exactly the app name, and `dir_buf` to contain exactly the dir path.
/// After return, `app_buf` will always contain exactly the app name and `dir_buf` will always contain exactly the dir path.
/// Note: `app_buf` should not contain any leading path separators.
/// Note: If the dir is the cwd, dir_buf should be empty (len = 0).
fn windowsCreateProcessPathExt(
    allocator: mem.Allocator,
    dir_buf: *std.ArrayListUnmanaged(u16),
    app_buf: *std.ArrayListUnmanaged(u16),
    pathext: [:0]const u16,
    cmd_line: [*:0]u16,
    envp_ptr: ?[*]u16,
    cwd_ptr: ?[*:0]u16,
    lpStartupInfo: *windows.STARTUPINFOW,
    lpProcessInformation: *windows.PROCESS_INFORMATION,
) !void {
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
        const prefixed_path = try windows.wToPrefixedFileW(dir_path_z);
        break :dir fs.cwd().openDirW(prefixed_path.span().ptr, .{}, true) catch return error.FileNotFound;
    };
    defer dir.close();

    // Add wildcard and null-terminator
    try app_buf.append(allocator, '*');
    try app_buf.append(allocator, 0);
    const app_name_wildcard = app_buf.items[0 .. app_buf.items.len - 1 :0];

    // This 2048 is arbitrary, we just want it to be large enough to get multiple FILE_DIRECTORY_INFORMATION entries
    // returned per NtQueryDirectoryFile call.
    var file_information_buf: [2048]u8 align(@alignOf(os.windows.FILE_DIRECTORY_INFORMATION)) = undefined;
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
        const app_name_len_bytes = math.cast(u16, app_name_wildcard.len * 2) orelse return error.NameTooLong;
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

            if (windowsCreateProcess(full_app_name.ptr, cmd_line, envp_ptr, cwd_ptr, lpStartupInfo, lpProcessInformation)) |_| {
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

        if (windowsCreateProcess(full_app_name.ptr, cmd_line, envp_ptr, cwd_ptr, lpStartupInfo, lpProcessInformation)) |_| {
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

fn windowsCreateProcess(app_name: [*:0]u16, cmd_line: [*:0]u16, envp_ptr: ?[*]u16, cwd_ptr: ?[*:0]u16, lpStartupInfo: *windows.STARTUPINFOW, lpProcessInformation: *windows.PROCESS_INFORMATION) !void {
    // TODO the docs for environment pointer say:
    // > A pointer to the environment block for the new process. If this parameter
    // > is NULL, the new process uses the environment of the calling process.
    // > ...
    // > An environment block can contain either Unicode or ANSI characters. If
    // > the environment block pointed to by lpEnvironment contains Unicode
    // > characters, be sure that dwCreationFlags includes CREATE_UNICODE_ENVIRONMENT.
    // > If this parameter is NULL and the environment block of the parent process
    // > contains Unicode characters, you must also ensure that dwCreationFlags
    // > includes CREATE_UNICODE_ENVIRONMENT.
    // This seems to imply that we have to somehow know whether our process parent passed
    // CREATE_UNICODE_ENVIRONMENT if we want to pass NULL for the environment parameter.
    // Since we do not know this information that would imply that we must not pass NULL
    // for the parameter.
    // However this would imply that programs compiled with -DUNICODE could not pass
    // environment variables to programs that were not, which seems unlikely.
    // More investigation is needed.
    return windows.CreateProcessW(
        app_name,
        cmd_line,
        null,
        null,
        windows.TRUE,
        windows.CREATE_UNICODE_ENVIRONMENT,
        @as(?*anyopaque, @ptrCast(envp_ptr)),
        cwd_ptr,
        lpStartupInfo,
        lpProcessInformation,
    );
}

// Should be kept in sync with `windowsCreateProcessSupportsExtension`
const CreateProcessSupportedExtension = enum {
    bat,
    cmd,
    com,
    exe,
};

/// Case-insensitive UTF-16 lookup
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

test "windowsCreateProcessSupportsExtension" {
    try std.testing.expectEqual(CreateProcessSupportedExtension.exe, windowsCreateProcessSupportsExtension(&[_]u16{ '.', 'e', 'X', 'e' }).?);
    try std.testing.expect(windowsCreateProcessSupportsExtension(&[_]u16{ '.', 'e', 'X', 'e', 'c' }) == null);
}

/// Caller must dealloc.
fn windowsCreateCommandLine(allocator: mem.Allocator, argv: []const []const u8) ![:0]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    for (argv, 0..) |arg, arg_i| {
        if (arg_i != 0) try buf.append(' ');
        if (mem.indexOfAny(u8, arg, " \t\n\"") == null) {
            try buf.appendSlice(arg);
            continue;
        }
        try buf.append('"');
        var backslash_count: usize = 0;
        for (arg) |byte| {
            switch (byte) {
                '\\' => backslash_count += 1,
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

    return buf.toOwnedSliceSentinel(0);
}

fn windowsDestroyPipe(rd: ?windows.HANDLE, wr: ?windows.HANDLE) void {
    if (rd) |h| os.close(h);
    if (wr) |h| os.close(h);
}

fn windowsMakePipeIn(rd: *?windows.HANDLE, wr: *?windows.HANDLE, sattr: *const windows.SECURITY_ATTRIBUTES) !void {
    var rd_h: windows.HANDLE = undefined;
    var wr_h: windows.HANDLE = undefined;
    try windows.CreatePipe(&rd_h, &wr_h, sattr);
    errdefer windowsDestroyPipe(rd_h, wr_h);
    try windows.SetHandleInformation(wr_h, windows.HANDLE_FLAG_INHERIT, 0);
    rd.* = rd_h;
    wr.* = wr_h;
}

var pipe_name_counter = std.atomic.Atomic(u32).init(1);

fn windowsMakeAsyncPipe(rd: *?windows.HANDLE, wr: *?windows.HANDLE, sattr: *const windows.SECURITY_ATTRIBUTES) !void {
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
            .{ windows.kernel32.GetCurrentProcessId(), pipe_name_counter.fetchAdd(1, .Monotonic) },
        ) catch unreachable;
        const len = std.unicode.utf8ToUtf16Le(&tmp_bufw, pipe_path) catch unreachable;
        tmp_bufw[len] = 0;
        break :blk tmp_bufw[0..len :0];
    };

    // Create the read handle that can be used with overlapped IO ops.
    const read_handle = windows.kernel32.CreateNamedPipeW(
        pipe_path.ptr,
        windows.PIPE_ACCESS_INBOUND | windows.FILE_FLAG_OVERLAPPED,
        windows.PIPE_TYPE_BYTE,
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
    errdefer os.close(read_handle);

    var sattr_copy = sattr.*;
    const write_handle = windows.kernel32.CreateFileW(
        pipe_path.ptr,
        windows.GENERIC_WRITE,
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
    errdefer os.close(write_handle);

    try windows.SetHandleInformation(read_handle, windows.HANDLE_FLAG_INHERIT, 0);

    rd.* = read_handle;
    wr.* = write_handle;
}

fn destroyPipe(pipe: [2]os.fd_t) void {
    os.close(pipe[0]);
    if (pipe[0] != pipe[1]) os.close(pipe[1]);
}

// Child of fork calls this to report an error to the fork parent.
// Then the child exits.
fn forkChildErrReport(fd: i32, err: ChildProcess.SpawnError) noreturn {
    writeIntFd(fd, @as(ErrInt, @intFromError(err))) catch {};
    // If we're linking libc, some naughty applications may have registered atexit handlers
    // which we really do not want to run in the fork child. I caught LLVM doing this and
    // it caused a deadlock instead of doing an exit syscall. In the words of Avril Lavigne,
    // "Why'd you have to go and make things so complicated?"
    if (builtin.link_libc) {
        // The _exit(2) function does nothing but make the exit syscall, unlike exit(3)
        std.c._exit(1);
    }
    os.exit(1);
}

const ErrInt = std.meta.Int(.unsigned, @sizeOf(anyerror) * 8);

fn writeIntFd(fd: i32, value: ErrInt) !void {
    const file = File{
        .handle = fd,
        .capable_io_mode = .blocking,
        .intended_io_mode = .blocking,
    };
    file.writer().writeIntNative(u64, @as(u64, @intCast(value))) catch return error.SystemResources;
}

fn readIntFd(fd: i32) !ErrInt {
    const file = File{
        .handle = fd,
        .capable_io_mode = .blocking,
        .intended_io_mode = .blocking,
    };
    return @as(ErrInt, @intCast(file.reader().readIntNative(u64) catch return error.SystemResources));
}

/// Caller must free result.
pub fn createWindowsEnvBlock(allocator: mem.Allocator, env_map: *const EnvMap) ![]u16 {
    // count bytes needed
    const max_chars_needed = x: {
        var max_chars_needed: usize = 4; // 4 for the final 4 null bytes
        var it = env_map.iterator();
        while (it.next()) |pair| {
            // +1 for '='
            // +1 for null byte
            max_chars_needed += pair.key_ptr.len + pair.value_ptr.len + 2;
        }
        break :x max_chars_needed;
    };
    const result = try allocator.alloc(u16, max_chars_needed);
    errdefer allocator.free(result);

    var it = env_map.iterator();
    var i: usize = 0;
    while (it.next()) |pair| {
        i += try unicode.utf8ToUtf16Le(result[i..], pair.key_ptr.*);
        result[i] = '=';
        i += 1;
        i += try unicode.utf8ToUtf16Le(result[i..], pair.value_ptr.*);
        result[i] = 0;
        i += 1;
    }
    result[i] = 0;
    i += 1;
    result[i] = 0;
    i += 1;
    result[i] = 0;
    i += 1;
    result[i] = 0;
    i += 1;
    return try allocator.realloc(result, i);
}

pub fn createNullDelimitedEnvMap(arena: mem.Allocator, env_map: *const EnvMap) ![:null]?[*:0]u8 {
    const envp_count = env_map.count();
    const envp_buf = try arena.allocSentinel(?[*:0]u8, envp_count, null);
    {
        var it = env_map.iterator();
        var i: usize = 0;
        while (it.next()) |pair| : (i += 1) {
            const env_buf = try arena.allocSentinel(u8, pair.key_ptr.len + pair.value_ptr.len + 1, 0);
            @memcpy(env_buf[0..pair.key_ptr.len], pair.key_ptr.*);
            env_buf[pair.key_ptr.len] = '=';
            @memcpy(env_buf[pair.key_ptr.len + 1 ..][0..pair.value_ptr.len], pair.value_ptr.*);
            envp_buf[i] = env_buf.ptr;
        }
        assert(i == envp_count);
    }
    return envp_buf;
}

test "createNullDelimitedEnvMap" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var envmap = EnvMap.init(allocator);
    defer envmap.deinit();

    try envmap.put("HOME", "/home/ifreund");
    try envmap.put("WAYLAND_DISPLAY", "wayland-1");
    try envmap.put("DISPLAY", ":1");
    try envmap.put("DEBUGINFOD_URLS", " ");
    try envmap.put("XCURSOR_SIZE", "24");

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const environ = try createNullDelimitedEnvMap(arena.allocator(), &envmap);

    try testing.expectEqual(@as(usize, 5), environ.len);

    inline for (.{
        "HOME=/home/ifreund",
        "WAYLAND_DISPLAY=wayland-1",
        "DISPLAY=:1",
        "DEBUGINFOD_URLS= ",
        "XCURSOR_SIZE=24",
    }) |target| {
        for (environ) |variable| {
            if (mem.eql(u8, mem.span(variable orelse continue), target)) break;
        } else {
            try testing.expect(false); // Environment variable not found
        }
    }
}
