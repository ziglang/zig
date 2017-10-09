const io = @import("../io.zig");
const os = @import("index.zig");
const posix = os.posix;
const mem = @import("../mem.zig");
const Allocator = mem.Allocator;
const debug = @import("../debug.zig");
const assert = debug.assert;
const BufMap = @import("../buf_map.zig").BufMap;
const builtin = @import("builtin");
const Os = builtin.Os;
const LinkedList = @import("../linked_list.zig").LinkedList;

error PermissionDenied;
error ProcessNotFound;

var children_nodes = LinkedList(&ChildProcess).init();

pub const ChildProcess = struct {
    pub pid: i32,
    pub allocator: &mem.Allocator,

    pub stdin: ?&io.OutStream,
    pub stdout: ?&io.InStream,
    pub stderr: ?&io.InStream,

    pub term: ?%Term,

    pub argv: []const []const u8,

    /// Possibly called from a signal handler. Must set this before calling `spawn`.
    pub onTerm: ?fn(&ChildProcess),

    /// Leave as null to use the current env map using the supplied allocator.
    pub env_map: ?&const BufMap,

    pub stdin_behavior: StdIo,
    pub stdout_behavior: StdIo,
    pub stderr_behavior: StdIo,

    /// Set to change the user id when spawning the child process.
    pub uid: ?u32,

    /// Set to change the group id when spawning the child process.
    pub gid: ?u32,

    /// Set to change the current working directory when spawning the child process.
    pub cwd: ?[]const u8,

    err_pipe: [2]i32,
    llnode: LinkedList(&ChildProcess).Node,

    pub const Term = enum {
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
    pub fn init(argv: []const []const u8, allocator: &Allocator) -> %&ChildProcess {
        const child = %return allocator.create(ChildProcess);
        %defer allocator.destroy(child);

        *child = ChildProcess {
            .allocator = allocator,
            .argv = argv,
            .pid = undefined,
            .err_pipe = undefined,
            .llnode = undefined,
            .term = null,
            .onTerm = null,
            .env_map = null,
            .cwd = null,
            .uid = null,
            .gid = null,
            .stdin = null,
            .stdout = null,
            .stderr = null,
            .stdin_behavior = StdIo.Inherit,
            .stdout_behavior = StdIo.Inherit,
            .stderr_behavior = StdIo.Inherit,
        };

        return child;
    }

    pub fn setUserName(self: &ChildProcess, name: []const u8) -> %void {
        const user_info = %return os.getUserInfo(name);
        self.uid = user_info.uid;
        self.gid = user_info.gid;
    }

    /// onTerm can be called before `spawn` returns.
    /// On success must call `kill` or `wait`.
    pub fn spawn(self: &ChildProcess) -> %void {
        return switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.darwin => self.spawnPosix(),
            else => @compileError("Unsupported OS"),
        };
    }

    pub fn spawnAndWait(self: &ChildProcess) -> %Term {
        %return self.spawn();
        return self.wait();
    }

    /// Forcibly terminates child process and then cleans up all resources.
    pub fn kill(self: &ChildProcess) -> %Term {
        block_SIGCHLD();
        defer restore_SIGCHLD();

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
                else => error.Unexpected,
            };
        }
        self.waitUnwrapped();
        return ??self.term;
    }

    /// Blocks until child process terminates and then cleans up all resources.
    pub fn wait(self: &ChildProcess) -> %Term {
        block_SIGCHLD();
        defer restore_SIGCHLD();

        if (self.term) |term| {
            self.cleanupStreams();
            return term;
        }

        self.waitUnwrapped();
        return ??self.term;
    }

    pub fn deinit(self: &ChildProcess) {
        self.allocator.destroy(self);
    }

    fn waitUnwrapped(self: &ChildProcess) {
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

    fn handleWaitResult(self: &ChildProcess, status: i32) {
        self.term = self.cleanupAfterWait(status);

        if (self.onTerm) |onTerm| {
            onTerm(self);
        }
    }

    fn cleanupStreams(self: &ChildProcess) {
        if (self.stdin) |stdin| { stdin.close(); self.allocator.destroy(stdin); self.stdin = null; }
        if (self.stdout) |stdout| { stdout.close(); self.allocator.destroy(stdout); self.stdout = null; }
        if (self.stderr) |stderr| { stderr.close(); self.allocator.destroy(stderr); self.stderr = null; }
    }

    fn cleanupAfterWait(self: &ChildProcess, status: i32) -> %Term {
        children_nodes.remove(&self.llnode);

        defer {
            os.posixClose(self.err_pipe[0]);
            os.posixClose(self.err_pipe[1]);
        };

        // Write @maxValue(ErrInt) to the write end of the err_pipe. This is after
        // waitpid, so this write is guaranteed to be after the child
        // pid potentially wrote an error. This way we can do a blocking
        // read on the error pipe and either get @maxValue(ErrInt) (no error) or
        // an error code.
        %return writeIntFd(self.err_pipe[1], @maxValue(ErrInt));
        const err_int = %return readIntFd(self.err_pipe[0]);
        // Here we potentially return the fork child's error
        // from the parent pid.
        if (err_int != @maxValue(ErrInt)) {
            return error(err_int);
        }

        return statusToTerm(status);
    }

    fn statusToTerm(status: i32) -> Term {
        return if (posix.WIFEXITED(status)) {
            Term.Exited { posix.WEXITSTATUS(status) }
        } else if (posix.WIFSIGNALED(status)) {
            Term.Signal { posix.WTERMSIG(status) }
        } else if (posix.WIFSTOPPED(status)) {
            Term.Stopped { posix.WSTOPSIG(status) }
        } else {
            Term.Unknown { status }
        };
    }

    fn spawnPosix(self: &ChildProcess) -> %void {
        // TODO atomically set a flag saying that we already did this
        install_SIGCHLD_handler();

        const stdin_pipe = if (self.stdin_behavior == StdIo.Pipe) %return makePipe() else undefined;
        %defer if (self.stdin_behavior == StdIo.Pipe) { destroyPipe(stdin_pipe); };

        const stdout_pipe = if (self.stdout_behavior == StdIo.Pipe) %return makePipe() else undefined;
        %defer if (self.stdout_behavior == StdIo.Pipe) { destroyPipe(stdout_pipe); };

        const stderr_pipe = if (self.stderr_behavior == StdIo.Pipe) %return makePipe() else undefined;
        %defer if (self.stderr_behavior == StdIo.Pipe) { destroyPipe(stderr_pipe); };

        const any_ignore = (self.stdin_behavior == StdIo.Ignore or self.stdout_behavior == StdIo.Ignore or self.stderr_behavior == StdIo.Ignore);
        const dev_null_fd = if (any_ignore) {
            %return os.posixOpen("/dev/null", posix.O_RDWR, 0, null)
        } else {
            undefined
        };
        defer { if (any_ignore) os.posixClose(dev_null_fd); };

        var env_map_owned: BufMap = undefined;
        var we_own_env_map: bool = undefined;
        const env_map = if (self.env_map) |env_map| {
            we_own_env_map = false;
            env_map
        } else {
            we_own_env_map = true;
            env_map_owned = %return os.getEnvMap(self.allocator);
            &env_map_owned
        };
        defer { if (we_own_env_map) env_map_owned.deinit(); }

        // This pipe is used to communicate errors between the time of fork
        // and execve from the child process to the parent process.
        const err_pipe = %return makePipe();
        %defer destroyPipe(err_pipe);

        const stdin_ptr = if (self.stdin_behavior == StdIo.Pipe) {
            %return self.allocator.create(io.OutStream)
        } else {
            null
        };
        const stdout_ptr = if (self.stdout_behavior == StdIo.Pipe) {
            %return self.allocator.create(io.InStream)
        } else {
            null
        };
        const stderr_ptr = if (self.stderr_behavior == StdIo.Pipe) {
            %return self.allocator.create(io.InStream)
        } else {
            null
        };

        block_SIGCHLD();
        const pid_result = posix.fork();
        const pid_err = posix.getErrno(pid_result);
        if (pid_err > 0) {
            restore_SIGCHLD();
            return switch (pid_err) {
                posix.EAGAIN, posix.ENOMEM, posix.ENOSYS => error.SystemResources,
                else => error.Unexpected,
            };
        }
        if (pid_result == 0) {
            // we are the child
            restore_SIGCHLD();

            setUpChildIo(self.stdin_behavior, stdin_pipe[0], posix.STDIN_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(self.stdout_behavior, stdout_pipe[1], posix.STDOUT_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(self.stderr_behavior, stderr_pipe[1], posix.STDERR_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);

            if (self.cwd) |cwd| {
                os.changeCurDir(self.allocator, cwd) %%
                    |err| forkChildErrReport(err_pipe[1], err);
            }

            if (self.gid) |gid| {
                os.posix_setregid(gid, gid) %% |err| forkChildErrReport(err_pipe[1], err);
            }

            if (self.uid) |uid| {
                os.posix_setreuid(uid, uid) %% |err| forkChildErrReport(err_pipe[1], err);
            }

            os.posixExecve(self.argv, env_map, self.allocator) %%
                |err| forkChildErrReport(err_pipe[1], err);
        }

        // we are the parent
        const pid = i32(pid_result);
        if (stdin_ptr) |outstream| {
            *outstream = io.OutStream {
                .fd = stdin_pipe[1],
                .handle = {},
                .handle_id = {},
                .buffer = undefined,
                .index = 0,
            };
        }
        if (stdout_ptr) |instream| {
            *instream = io.InStream {
                .fd = stdout_pipe[0],
                .handle = {},
                .handle_id = {},
            };
        }
        if (stderr_ptr) |instream| {
            *instream = io.InStream {
                .fd = stderr_pipe[0],
                .handle = {},
                .handle_id = {},
            };
        }

        self.pid = pid;
        self.err_pipe = err_pipe;
        self.llnode = LinkedList(&ChildProcess).Node.init(self);
        self.term = null;
        self.stdin = stdin_ptr;
        self.stdout = stdout_ptr;
        self.stderr = stderr_ptr;

        // TODO make this atomic so it works even with threads
        children_nodes.prepend(&self.llnode);

        restore_SIGCHLD();

        if (self.stdin_behavior == StdIo.Pipe) { os.posixClose(stdin_pipe[0]); }
        if (self.stdout_behavior == StdIo.Pipe) { os.posixClose(stdout_pipe[1]); }
        if (self.stderr_behavior == StdIo.Pipe) { os.posixClose(stderr_pipe[1]); }
    }

    fn setUpChildIo(stdio: StdIo, pipe_fd: i32, std_fileno: i32, dev_null_fd: i32) -> %void {
        switch (stdio) {
            StdIo.Pipe => %return os.posixDup2(pipe_fd, std_fileno),
            StdIo.Close => os.posixClose(std_fileno),
            StdIo.Inherit => {},
            StdIo.Ignore => %return os.posixDup2(dev_null_fd, std_fileno),
        }
    }
};

fn makePipe() -> %[2]i32 {
    var fds: [2]i32 = undefined;
    const err = posix.getErrno(posix.pipe(&fds));
    if (err > 0) {
        return switch (err) {
            posix.EMFILE, posix.ENFILE => error.SystemResources,
            else => error.Unexpected,
        }
    }
    return fds;
}

fn destroyPipe(pipe: &const [2]i32) {
    os.posixClose((*pipe)[0]);
    os.posixClose((*pipe)[1]);
}

// Child of fork calls this to report an error to the fork parent.
// Then the child exits.
fn forkChildErrReport(fd: i32, err: error) -> noreturn {
    _ = writeIntFd(fd, ErrInt(err));
    posix.exit(1);
}

const ErrInt = @IntType(false, @sizeOf(error) * 8);

fn writeIntFd(fd: i32, value: ErrInt) -> %void {
    var bytes: [@sizeOf(ErrInt)]u8 = undefined;
    mem.writeInt(bytes[0..], value, true);
    os.posixWrite(fd, bytes[0..]) %% return error.SystemResources;
}

fn readIntFd(fd: i32) -> %ErrInt {
    var bytes: [@sizeOf(ErrInt)]u8 = undefined;
    os.posixRead(fd, bytes[0..]) %% return error.SystemResources;
    return mem.readInt(bytes[0..], ErrInt, true);
}

extern fn sigchld_handler(_: i32) {
    while (true) {
        var status: i32 = undefined;
        const pid_result = posix.waitpid(-1, &status, posix.WNOHANG);
        if (pid_result == 0) {
            return;
        }
        const err = posix.getErrno(pid_result);
        if (err > 0) {
            if (err == posix.ECHILD) {
                return;
            }
            unreachable;
        }
        handleTerm(i32(pid_result), status);
    }
}

fn handleTerm(pid: i32, status: i32) {
    var it = children_nodes.first;
    while (it) |node| : (it = node.next) {
        if (node.data.pid == pid) {
            node.data.handleWaitResult(status);
            return;
        }
    }
}

const sigchld_set = {
    var signal_set = posix.empty_sigset;
    posix.sigaddset(&signal_set, posix.SIGCHLD);
    signal_set
};

fn block_SIGCHLD() {
    const err = posix.getErrno(posix.sigprocmask(posix.SIG_BLOCK, &sigchld_set, null));
    assert(err == 0);
}

fn restore_SIGCHLD() {
    const err = posix.getErrno(posix.sigprocmask(posix.SIG_UNBLOCK, &sigchld_set, null));
    assert(err == 0);
}

const sigchld_action = posix.Sigaction {
    .handler = sigchld_handler,
    .mask = posix.empty_sigset,
    .flags = posix.SA_RESTART | posix.SA_NOCLDSTOP,
};

fn install_SIGCHLD_handler() {
    const err = posix.getErrno(posix.sigaction(posix.SIGCHLD, &sigchld_action, null));
    assert(err == 0);
}
