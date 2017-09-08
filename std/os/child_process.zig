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
    pid: i32,

    err_pipe: [2]i32,
    llnode: LinkedList(&ChildProcess).Node,
    allocator: &mem.Allocator,

    stdin: ?&io.OutStream,
    stdout: ?&io.InStream,
    stderr: ?&io.InStream,

    term: ?%Term,

    /// Possibly called from a signal handler.
    onTerm: ?fn(&ChildProcess),

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

    /// onTerm can be called before `spawn` returns.
    pub fn spawn(exe_path: []const u8, args: []const []const u8,
        cwd: ?[]const u8, env_map: &const BufMap,
        stdin: StdIo, stdout: StdIo, stderr: StdIo,
        onTerm: ?fn(&ChildProcess), allocator: &Allocator) -> %&ChildProcess
    {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.darwin => {
                return spawnPosix(exe_path, args, cwd, env_map, stdin, stdout, stderr, onTerm, allocator);
            },
            else => @compileError("Unsupported OS"),
        }
    }

    /// Forcibly terminates child process and then cleans up all resources.
    pub fn kill(self: &ChildProcess) -> %Term {
        block_SIGCHLD();
        defer restore_SIGCHLD();

        if (self.term) |term| {
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
            return term;
        }

        self.waitUnwrapped();
        return ??self.term;
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
        if (self.stdin) |stdin| { stdin.close(); self.allocator.free(stdin); }
        if (self.stdout) |stdout| { stdout.close(); self.allocator.free(stdout); }
        if (self.stderr) |stderr| { stderr.close(); self.allocator.free(stderr); }
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

    fn spawnPosix(exe_path: []const u8, args: []const []const u8,
        maybe_cwd: ?[]const u8, env_map: &const BufMap,
        stdin: StdIo, stdout: StdIo, stderr: StdIo,
        onTerm: ?fn(&ChildProcess), allocator: &Allocator) -> %&ChildProcess
    {
        // TODO atomically set a flag saying that we already did this
        install_SIGCHLD_handler();

        const stdin_pipe = if (stdin == StdIo.Pipe) %return makePipe() else undefined;
        %defer if (stdin == StdIo.Pipe) { destroyPipe(stdin_pipe); };

        const stdout_pipe = if (stdout == StdIo.Pipe) %return makePipe() else undefined;
        %defer if (stdout == StdIo.Pipe) { destroyPipe(stdout_pipe); };

        const stderr_pipe = if (stderr == StdIo.Pipe) %return makePipe() else undefined;
        %defer if (stderr == StdIo.Pipe) { destroyPipe(stderr_pipe); };

        const any_ignore = (stdin == StdIo.Ignore or stdout == StdIo.Ignore or stderr == StdIo.Ignore);
        const dev_null_fd = if (any_ignore) {
            %return os.posixOpen("/dev/null", posix.O_RDWR, 0, null)
        } else {
            undefined
        };

        // This pipe is used to communicate errors between the time of fork
        // and execve from the child process to the parent process.
        const err_pipe = %return makePipe();
        %defer destroyPipe(err_pipe);

        const child = %return allocator.create(ChildProcess);
        %defer allocator.destroy(child);

        const stdin_ptr = if (stdin == StdIo.Pipe) {
            %return allocator.create(io.OutStream)
        } else {
            null
        };
        const stdout_ptr = if (stdout == StdIo.Pipe) {
            %return allocator.create(io.InStream)
        } else {
            null
        };
        const stderr_ptr = if (stderr == StdIo.Pipe) {
            %return allocator.create(io.InStream)
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

            setUpChildIo(stdin, stdin_pipe[0], posix.STDIN_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(stdout, stdout_pipe[1], posix.STDOUT_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(stderr, stderr_pipe[1], posix.STDERR_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);

            if (maybe_cwd) |cwd| {
                os.changeCurDir(allocator, cwd) %%
                    |err| forkChildErrReport(err_pipe[1], err);
            }

            os.posixExecve(exe_path, args, env_map, allocator) %%
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

        *child = ChildProcess {
            .allocator = allocator,
            .pid = pid,
            .err_pipe = err_pipe,
            .llnode = LinkedList(&ChildProcess).Node.init(child),
            .term = null,
            .onTerm = onTerm,
            .stdin = stdin_ptr,
            .stdout = stdout_ptr,
            .stderr = stderr_ptr,
        };

        children_nodes.prepend(&child.llnode);

        restore_SIGCHLD();

        if (stdin == StdIo.Pipe) { os.posixClose(stdin_pipe[0]); }
        if (stdout == StdIo.Pipe) { os.posixClose(stdout_pipe[1]); }
        if (stderr == StdIo.Pipe) { os.posixClose(stderr_pipe[1]); }
        if (any_ignore) { os.posixClose(dev_null_fd); }

        return child;
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
