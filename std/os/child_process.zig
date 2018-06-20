const std = @import("../index.zig");
const cstr = std.cstr;
const io = std.io;
const os = std.os;
const posix = os.posix;
const windows = os.windows;
const mem = std.mem;
const debug = std.debug;
const assert = debug.assert;
const BufMap = std.BufMap;
const Buffer = std.Buffer;
const builtin = @import("builtin");
const Os = builtin.Os;
const LinkedList = std.LinkedList;

const is_windows = builtin.os == Os.windows;

pub const ChildProcess = struct {
    pub pid: if (is_windows) void else i32,
    pub handle: if (is_windows) windows.HANDLE else void,
    pub thread_handle: if (is_windows) windows.HANDLE else void,

    pub allocator: *mem.Allocator,

    pub stdin: ?os.File,
    pub stdout: ?os.File,
    pub stderr: ?os.File,

    pub term: ?(SpawnError!Term),

    pub argv: []const []const u8,

    /// Leave as null to use the current env map using the supplied allocator.
    pub env_map: ?*const BufMap,

    pub stdin_behavior: StdIo,
    pub stdout_behavior: StdIo,
    pub stderr_behavior: StdIo,

    /// Set to change the user id when spawning the child process.
    pub uid: if (is_windows) void else ?u32,

    /// Set to change the group id when spawning the child process.
    pub gid: if (is_windows) void else ?u32,

    /// Set to change the current working directory when spawning the child process.
    pub cwd: ?[]const u8,

    err_pipe: if (is_windows) void else [2]i32,
    llnode: if (is_windows) void else LinkedList(*ChildProcess).Node,

    pub const SpawnError = error{
        ProcessFdQuotaExceeded,
        Unexpected,
        NotDir,
        SystemResources,
        FileNotFound,
        NameTooLong,
        SymLinkLoop,
        FileSystem,
        OutOfMemory,
        AccessDenied,
        PermissionDenied,
        InvalidUserId,
        ResourceLimitReached,
        InvalidExe,
        IsDir,
        FileBusy,
    };

    pub const Term = union(enum) {
        Exited: i32,
        Signal: i32,
        Stopped: i32,
        Unknown: i32,
    };

    pub const StdIo = enum {
        Inherit,
        Ignore,
        Pipe,
        Close,
    };

    /// First argument in argv is the executable.
    /// On success must call deinit.
    pub fn init(argv: []const []const u8, allocator: *mem.Allocator) !*ChildProcess {
        const child = try allocator.create(ChildProcess{
            .allocator = allocator,
            .argv = argv,
            .pid = undefined,
            .handle = undefined,
            .thread_handle = undefined,
            .err_pipe = undefined,
            .llnode = undefined,
            .term = null,
            .env_map = null,
            .cwd = null,
            .uid = if (is_windows) {} else
                null,
            .gid = if (is_windows) {} else
                null,
            .stdin = null,
            .stdout = null,
            .stderr = null,
            .stdin_behavior = StdIo.Inherit,
            .stdout_behavior = StdIo.Inherit,
            .stderr_behavior = StdIo.Inherit,
        });
        errdefer allocator.destroy(child);
        return child;
    }

    pub fn setUserName(self: *ChildProcess, name: []const u8) !void {
        const user_info = try os.getUserInfo(name);
        self.uid = user_info.uid;
        self.gid = user_info.gid;
    }

    /// On success must call `kill` or `wait`.
    pub fn spawn(self: *ChildProcess) !void {
        if (is_windows) {
            return self.spawnWindows();
        } else {
            return self.spawnPosix();
        }
    }

    pub fn spawnAndWait(self: *ChildProcess) !Term {
        try self.spawn();
        return self.wait();
    }

    /// Forcibly terminates child process and then cleans up all resources.
    pub fn kill(self: *ChildProcess) !Term {
        if (is_windows) {
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

        if (!windows.TerminateProcess(self.handle, exit_code)) {
            const err = windows.GetLastError();
            return switch (err) {
                else => os.unexpectedErrorWindows(err),
            };
        }
        try self.waitUnwrappedWindows();
        return self.term.?;
    }

    pub fn killPosix(self: *ChildProcess) !Term {
        if (self.term) |term| {
            self.cleanupStreams();
            return term;
        }
        const ret = posix.kill(self.pid, posix.SIGTERM);
        const err = posix.getErrno(ret);
        if (err > 0) {
            return switch (err) {
                posix.EINVAL => unreachable,
                posix.EPERM => error.PermissionDenied,
                posix.ESRCH => error.ProcessNotFound,
                else => os.unexpectedErrorPosix(err),
            };
        }
        self.waitUnwrapped();
        return self.term.?;
    }

    /// Blocks until child process terminates and then cleans up all resources.
    pub fn wait(self: *ChildProcess) !Term {
        if (is_windows) {
            return self.waitWindows();
        } else {
            return self.waitPosix();
        }
    }

    pub const ExecResult = struct {
        term: os.ChildProcess.Term,
        stdout: []u8,
        stderr: []u8,
    };

    /// Spawns a child process, waits for it, collecting stdout and stderr, and then returns.
    /// If it succeeds, the caller owns result.stdout and result.stderr memory.
    pub fn exec(allocator: *mem.Allocator, argv: []const []const u8, cwd: ?[]const u8, env_map: ?*const BufMap, max_output_size: usize) !ExecResult {
        const child = try ChildProcess.init(argv, allocator);
        defer child.deinit();

        child.stdin_behavior = ChildProcess.StdIo.Ignore;
        child.stdout_behavior = ChildProcess.StdIo.Pipe;
        child.stderr_behavior = ChildProcess.StdIo.Pipe;
        child.cwd = cwd;
        child.env_map = env_map;

        try child.spawn();

        var stdout = Buffer.initNull(allocator);
        var stderr = Buffer.initNull(allocator);
        defer Buffer.deinit(&stdout);
        defer Buffer.deinit(&stderr);

        var stdout_file_in_stream = io.FileInStream.init(&child.stdout.?);
        var stderr_file_in_stream = io.FileInStream.init(&child.stderr.?);

        try stdout_file_in_stream.stream.readAllBuffer(&stdout, max_output_size);
        try stderr_file_in_stream.stream.readAllBuffer(&stderr, max_output_size);

        return ExecResult{
            .term = try child.wait(),
            .stdout = stdout.toOwnedSlice(),
            .stderr = stderr.toOwnedSlice(),
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

        self.waitUnwrapped();
        return self.term.?;
    }

    pub fn deinit(self: *ChildProcess) void {
        self.allocator.destroy(self);
    }

    fn waitUnwrappedWindows(self: *ChildProcess) !void {
        const result = os.windowsWaitSingle(self.handle, windows.INFINITE);

        self.term = (SpawnError!Term)(x: {
            var exit_code: windows.DWORD = undefined;
            if (windows.GetExitCodeProcess(self.handle, &exit_code) == 0) {
                break :x Term{ .Unknown = 0 };
            } else {
                break :x Term{ .Exited = @bitCast(i32, exit_code) };
            }
        });

        os.close(self.handle);
        os.close(self.thread_handle);
        self.cleanupStreams();
        return result;
    }

    fn waitUnwrapped(self: *ChildProcess) void {
        var status: i32 = undefined;
        while (true) {
            const err = posix.getErrno(posix.waitpid(self.pid, &status, 0));
            if (err > 0) {
                switch (err) {
                    posix.EINTR => continue,
                    else => unreachable,
                }
            }
            self.cleanupStreams();
            self.handleWaitResult(status);
            return;
        }
    }

    fn handleWaitResult(self: *ChildProcess, status: i32) void {
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

    fn cleanupAfterWait(self: *ChildProcess, status: i32) !Term {
        defer {
            os.close(self.err_pipe[0]);
            os.close(self.err_pipe[1]);
        }

        // Write @maxValue(ErrInt) to the write end of the err_pipe. This is after
        // waitpid, so this write is guaranteed to be after the child
        // pid potentially wrote an error. This way we can do a blocking
        // read on the error pipe and either get @maxValue(ErrInt) (no error) or
        // an error code.
        try writeIntFd(self.err_pipe[1], @maxValue(ErrInt));
        const err_int = try readIntFd(self.err_pipe[0]);
        // Here we potentially return the fork child's error
        // from the parent pid.
        if (err_int != @maxValue(ErrInt)) {
            return @errSetCast(SpawnError, @intToError(err_int));
        }

        return statusToTerm(status);
    }

    fn statusToTerm(status: i32) Term {
        return if (posix.WIFEXITED(status))
            Term{ .Exited = posix.WEXITSTATUS(status) }
        else if (posix.WIFSIGNALED(status))
            Term{ .Signal = posix.WTERMSIG(status) }
        else if (posix.WIFSTOPPED(status))
            Term{ .Stopped = posix.WSTOPSIG(status) }
        else
            Term{ .Unknown = status };
    }

    fn spawnPosix(self: *ChildProcess) !void {
        const stdin_pipe = if (self.stdin_behavior == StdIo.Pipe) try makePipe() else undefined;
        errdefer if (self.stdin_behavior == StdIo.Pipe) {
            destroyPipe(stdin_pipe);
        };

        const stdout_pipe = if (self.stdout_behavior == StdIo.Pipe) try makePipe() else undefined;
        errdefer if (self.stdout_behavior == StdIo.Pipe) {
            destroyPipe(stdout_pipe);
        };

        const stderr_pipe = if (self.stderr_behavior == StdIo.Pipe) try makePipe() else undefined;
        errdefer if (self.stderr_behavior == StdIo.Pipe) {
            destroyPipe(stderr_pipe);
        };

        const any_ignore = (self.stdin_behavior == StdIo.Ignore or self.stdout_behavior == StdIo.Ignore or self.stderr_behavior == StdIo.Ignore);
        const dev_null_fd = if (any_ignore) blk: {
            const dev_null_path = "/dev/null";
            var fixed_buffer_mem: [dev_null_path.len + 1]u8 = undefined;
            var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
            break :blk try os.posixOpen(&fixed_allocator.allocator, "/dev/null", posix.O_RDWR, 0);
        } else blk: {
            break :blk undefined;
        };
        defer {
            if (any_ignore) os.close(dev_null_fd);
        }

        var env_map_owned: BufMap = undefined;
        var we_own_env_map: bool = undefined;
        const env_map = if (self.env_map) |env_map| x: {
            we_own_env_map = false;
            break :x env_map;
        } else x: {
            we_own_env_map = true;
            env_map_owned = try os.getEnvMap(self.allocator);
            break :x &env_map_owned;
        };
        defer {
            if (we_own_env_map) env_map_owned.deinit();
        }

        // This pipe is used to communicate errors between the time of fork
        // and execve from the child process to the parent process.
        const err_pipe = try makePipe();
        errdefer destroyPipe(err_pipe);

        const pid_result = posix.fork();
        const pid_err = posix.getErrno(pid_result);
        if (pid_err > 0) {
            return switch (pid_err) {
                posix.EAGAIN, posix.ENOMEM, posix.ENOSYS => error.SystemResources,
                else => os.unexpectedErrorPosix(pid_err),
            };
        }
        if (pid_result == 0) {
            // we are the child
            setUpChildIo(self.stdin_behavior, stdin_pipe[0], posix.STDIN_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(self.stdout_behavior, stdout_pipe[1], posix.STDOUT_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(self.stderr_behavior, stderr_pipe[1], posix.STDERR_FILENO, dev_null_fd) catch |err| forkChildErrReport(err_pipe[1], err);

            if (self.cwd) |cwd| {
                os.changeCurDir(self.allocator, cwd) catch |err| forkChildErrReport(err_pipe[1], err);
            }

            if (self.gid) |gid| {
                os.posix_setregid(gid, gid) catch |err| forkChildErrReport(err_pipe[1], err);
            }

            if (self.uid) |uid| {
                os.posix_setreuid(uid, uid) catch |err| forkChildErrReport(err_pipe[1], err);
            }

            os.posixExecve(self.argv, env_map, self.allocator) catch |err| forkChildErrReport(err_pipe[1], err);
        }

        // we are the parent
        const pid = @intCast(i32, pid_result);
        if (self.stdin_behavior == StdIo.Pipe) {
            self.stdin = os.File.openHandle(stdin_pipe[1]);
        } else {
            self.stdin = null;
        }
        if (self.stdout_behavior == StdIo.Pipe) {
            self.stdout = os.File.openHandle(stdout_pipe[0]);
        } else {
            self.stdout = null;
        }
        if (self.stderr_behavior == StdIo.Pipe) {
            self.stderr = os.File.openHandle(stderr_pipe[0]);
        } else {
            self.stderr = null;
        }

        self.pid = pid;
        self.err_pipe = err_pipe;
        self.llnode = LinkedList(*ChildProcess).Node.init(self);
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

    fn spawnWindows(self: *ChildProcess) !void {
        const saAttr = windows.SECURITY_ATTRIBUTES{
            .nLength = @sizeOf(windows.SECURITY_ATTRIBUTES),
            .bInheritHandle = windows.TRUE,
            .lpSecurityDescriptor = null,
        };

        const any_ignore = (self.stdin_behavior == StdIo.Ignore or self.stdout_behavior == StdIo.Ignore or self.stderr_behavior == StdIo.Ignore);

        const nul_handle = if (any_ignore) blk: {
            const nul_file_path = "NUL";
            var fixed_buffer_mem: [nul_file_path.len + 1]u8 = undefined;
            var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
            break :blk try os.windowsOpen(&fixed_allocator.allocator, "NUL", windows.GENERIC_READ, windows.FILE_SHARE_READ, windows.OPEN_EXISTING, windows.FILE_ATTRIBUTE_NORMAL);
        } else blk: {
            break :blk undefined;
        };
        defer {
            if (any_ignore) os.close(nul_handle);
        }
        if (any_ignore) {
            try windowsSetHandleInfo(nul_handle, windows.HANDLE_FLAG_INHERIT, 0);
        }

        var g_hChildStd_IN_Rd: ?windows.HANDLE = null;
        var g_hChildStd_IN_Wr: ?windows.HANDLE = null;
        switch (self.stdin_behavior) {
            StdIo.Pipe => {
                try windowsMakePipeIn(&g_hChildStd_IN_Rd, &g_hChildStd_IN_Wr, saAttr);
            },
            StdIo.Ignore => {
                g_hChildStd_IN_Rd = nul_handle;
            },
            StdIo.Inherit => {
                g_hChildStd_IN_Rd = windows.GetStdHandle(windows.STD_INPUT_HANDLE);
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
                try windowsMakePipeOut(&g_hChildStd_OUT_Rd, &g_hChildStd_OUT_Wr, saAttr);
            },
            StdIo.Ignore => {
                g_hChildStd_OUT_Wr = nul_handle;
            },
            StdIo.Inherit => {
                g_hChildStd_OUT_Wr = windows.GetStdHandle(windows.STD_OUTPUT_HANDLE);
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
                try windowsMakePipeOut(&g_hChildStd_ERR_Rd, &g_hChildStd_ERR_Wr, saAttr);
            },
            StdIo.Ignore => {
                g_hChildStd_ERR_Wr = nul_handle;
            },
            StdIo.Inherit => {
                g_hChildStd_ERR_Wr = windows.GetStdHandle(windows.STD_ERROR_HANDLE);
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

        var siStartInfo = windows.STARTUPINFOA{
            .cb = @sizeOf(windows.STARTUPINFOA),
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

        const cwd_slice = if (self.cwd) |cwd| try cstr.addNullByte(self.allocator, cwd) else null;
        defer if (cwd_slice) |cwd| self.allocator.free(cwd);
        const cwd_ptr = if (cwd_slice) |cwd| cwd.ptr else null;

        const maybe_envp_buf = if (self.env_map) |env_map| try os.createWindowsEnvBlock(self.allocator, env_map) else null;
        defer if (maybe_envp_buf) |envp_buf| self.allocator.free(envp_buf);
        const envp_ptr = if (maybe_envp_buf) |envp_buf| envp_buf.ptr else null;

        // the cwd set in ChildProcess is in effect when choosing the executable path
        // to match posix semantics
        const app_name = x: {
            if (self.cwd) |cwd| {
                const resolved = try os.path.resolve(self.allocator, cwd, self.argv[0]);
                defer self.allocator.free(resolved);
                break :x try cstr.addNullByte(self.allocator, resolved);
            } else {
                break :x try cstr.addNullByte(self.allocator, self.argv[0]);
            }
        };
        defer self.allocator.free(app_name);

        windowsCreateProcess(app_name.ptr, cmd_line.ptr, envp_ptr, cwd_ptr, &siStartInfo, &piProcInfo) catch |no_path_err| {
            if (no_path_err != error.FileNotFound) return no_path_err;

            const PATH = try os.getEnvVarOwned(self.allocator, "PATH");
            defer self.allocator.free(PATH);

            var it = mem.split(PATH, ";");
            while (it.next()) |search_path| {
                const joined_path = try os.path.join(self.allocator, search_path, app_name);
                defer self.allocator.free(joined_path);

                if (windowsCreateProcess(joined_path.ptr, cmd_line.ptr, envp_ptr, cwd_ptr, &siStartInfo, &piProcInfo)) |_| {
                    break;
                } else |err| if (err == error.FileNotFound) {
                    continue;
                } else {
                    return err;
                }
            }
        };

        if (g_hChildStd_IN_Wr) |h| {
            self.stdin = os.File.openHandle(h);
        } else {
            self.stdin = null;
        }
        if (g_hChildStd_OUT_Rd) |h| {
            self.stdout = os.File.openHandle(h);
        } else {
            self.stdout = null;
        }
        if (g_hChildStd_ERR_Rd) |h| {
            self.stderr = os.File.openHandle(h);
        } else {
            self.stderr = null;
        }

        self.handle = piProcInfo.hProcess;
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
            StdIo.Pipe => try os.posixDup2(pipe_fd, std_fileno),
            StdIo.Close => os.close(std_fileno),
            StdIo.Inherit => {},
            StdIo.Ignore => try os.posixDup2(dev_null_fd, std_fileno),
        }
    }
};

fn windowsCreateProcess(app_name: [*]u8, cmd_line: [*]u8, envp_ptr: ?[*]u8, cwd_ptr: ?[*]u8, lpStartupInfo: *windows.STARTUPINFOA, lpProcessInformation: *windows.PROCESS_INFORMATION) !void {
    if (windows.CreateProcessA(app_name, cmd_line, null, null, windows.TRUE, 0, @ptrCast(?*c_void, envp_ptr), cwd_ptr, lpStartupInfo, lpProcessInformation) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.FILE_NOT_FOUND, windows.ERROR.PATH_NOT_FOUND => error.FileNotFound,
            windows.ERROR.INVALID_PARAMETER => unreachable,
            windows.ERROR.INVALID_NAME => error.InvalidName,
            else => os.unexpectedErrorWindows(err),
        };
    }
}

/// Caller must dealloc.
/// Guarantees a null byte at result[result.len].
fn windowsCreateCommandLine(allocator: *mem.Allocator, argv: []const []const u8) ![]u8 {
    var buf = try Buffer.initSize(allocator, 0);
    defer buf.deinit();

    var buf_stream = &io.BufferOutStream.init(&buf).stream;

    for (argv) |arg, arg_i| {
        if (arg_i != 0) try buf.appendByte(' ');
        if (mem.indexOfAny(u8, arg, " \t\n\"") == null) {
            try buf.append(arg);
            continue;
        }
        try buf.appendByte('"');
        var backslash_count: usize = 0;
        for (arg) |byte| {
            switch (byte) {
                '\\' => backslash_count += 1,
                '"' => {
                    try buf_stream.writeByteNTimes('\\', backslash_count * 2 + 1);
                    try buf.appendByte('"');
                    backslash_count = 0;
                },
                else => {
                    try buf_stream.writeByteNTimes('\\', backslash_count);
                    try buf.appendByte(byte);
                    backslash_count = 0;
                },
            }
        }
        try buf_stream.writeByteNTimes('\\', backslash_count * 2);
        try buf.appendByte('"');
    }

    return buf.toOwnedSlice();
}

fn windowsDestroyPipe(rd: ?windows.HANDLE, wr: ?windows.HANDLE) void {
    if (rd) |h| os.close(h);
    if (wr) |h| os.close(h);
}

// TODO: workaround for bug where the `const` from `&const` is dropped when the type is
// a namespace field lookup
const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;

fn windowsMakePipe(rd: *windows.HANDLE, wr: *windows.HANDLE, sattr: *const SECURITY_ATTRIBUTES) !void {
    if (windows.CreatePipe(rd, wr, sattr, 0) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            else => os.unexpectedErrorWindows(err),
        };
    }
}

fn windowsSetHandleInfo(h: windows.HANDLE, mask: windows.DWORD, flags: windows.DWORD) !void {
    if (windows.SetHandleInformation(h, mask, flags) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            else => os.unexpectedErrorWindows(err),
        };
    }
}

fn windowsMakePipeIn(rd: *?windows.HANDLE, wr: *?windows.HANDLE, sattr: *const SECURITY_ATTRIBUTES) !void {
    var rd_h: windows.HANDLE = undefined;
    var wr_h: windows.HANDLE = undefined;
    try windowsMakePipe(&rd_h, &wr_h, sattr);
    errdefer windowsDestroyPipe(rd_h, wr_h);
    try windowsSetHandleInfo(wr_h, windows.HANDLE_FLAG_INHERIT, 0);
    rd.* = rd_h;
    wr.* = wr_h;
}

fn windowsMakePipeOut(rd: *?windows.HANDLE, wr: *?windows.HANDLE, sattr: *const SECURITY_ATTRIBUTES) !void {
    var rd_h: windows.HANDLE = undefined;
    var wr_h: windows.HANDLE = undefined;
    try windowsMakePipe(&rd_h, &wr_h, sattr);
    errdefer windowsDestroyPipe(rd_h, wr_h);
    try windowsSetHandleInfo(rd_h, windows.HANDLE_FLAG_INHERIT, 0);
    rd.* = rd_h;
    wr.* = wr_h;
}

fn makePipe() ![2]i32 {
    var fds: [2]i32 = undefined;
    const err = posix.getErrno(posix.pipe(&fds));
    if (err > 0) {
        return switch (err) {
            posix.EMFILE, posix.ENFILE => error.SystemResources,
            else => os.unexpectedErrorPosix(err),
        };
    }
    return fds;
}

fn destroyPipe(pipe: *const [2]i32) void {
    os.close((pipe.*)[0]);
    os.close((pipe.*)[1]);
}

// Child of fork calls this to report an error to the fork parent.
// Then the child exits.
fn forkChildErrReport(fd: i32, err: ChildProcess.SpawnError) noreturn {
    _ = writeIntFd(fd, ErrInt(@errorToInt(err)));
    posix.exit(1);
}

const ErrInt = @IntType(false, @sizeOf(error) * 8);

fn writeIntFd(fd: i32, value: ErrInt) !void {
    var bytes: [@sizeOf(ErrInt)]u8 = undefined;
    mem.writeInt(bytes[0..], value, builtin.endian);
    os.posixWrite(fd, bytes[0..]) catch return error.SystemResources;
}

fn readIntFd(fd: i32) !ErrInt {
    var bytes: [@sizeOf(ErrInt)]u8 = undefined;
    os.posixRead(fd, bytes[0..]) catch return error.SystemResources;
    return mem.readInt(bytes[0..], ErrInt, builtin.endian);
}
