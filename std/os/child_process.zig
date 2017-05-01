const io = @import("../io.zig");
const os = @import("index.zig");
const posix = os.posix;
const mem = @import("../mem.zig");
const Allocator = mem.Allocator;
const errno = @import("errno.zig");
const debug = @import("../debug.zig");
const assert = debug.assert;
const BufMap = @import("../buf_map.zig").BufMap;
const builtin = @import("builtin");
const Os = builtin.Os;

pub const ChildProcess = struct {
    pid: i32,
    err_pipe: [2]i32,

    stdin: ?io.OutStream,
    stdout: ?io.InStream,
    stderr: ?io.InStream,

    pub const Term = enum {
        Clean: i32,
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

    pub fn spawn(exe_path: []const u8, args: []const []const u8,
        cwd: ?[]const u8, env_map: &const BufMap,
        stdin: StdIo, stdout: StdIo, stderr: StdIo, allocator: &Allocator) -> %ChildProcess
    {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.darwin => {
                return spawnPosix(exe_path, args, cwd, env_map, stdin, stdout, stderr, allocator);
            },
            else => @compileError("Unsupported OS"),
        }
    }

    /// Blocks until child process terminates and then cleans up all resources.
    pub fn wait(self: &ChildProcess) -> %Term {
        defer {
            os.posixClose(self.err_pipe[0]);
            os.posixClose(self.err_pipe[1]);
        };

        var status: i32 = undefined;
        while (true) {
            const err = posix.getErrno(posix.waitpid(self.pid, &status, 0));
            if (err > 0) {
                switch (err) {
                    errno.EINVAL, errno.ECHILD => unreachable,
                    errno.EINTR => continue,
                    else => {
                        test (self.stdin) |*stdin| { stdin.close(); }
                        test (self.stdout) |*stdout| { stdout.close(); }
                        test (self.stderr) |*stderr| { stderr.close(); }
                        return error.Unexpected;
                    },
                }
            }
            break;
        }

        test (self.stdin) |*stdin| { stdin.close(); }
        test (self.stdout) |*stdout| { stdout.close(); }
        test (self.stderr) |*stderr| { stderr.close(); }

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
            Term.Clean { posix.WEXITSTATUS(status) }
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
        stdin: StdIo, stdout: StdIo, stderr: StdIo, allocator: &Allocator) -> %ChildProcess
    {
        // TODO issue #295
        //const stdin_pipe = if (stdin == StdIo.Pipe) %return makePipe() else undefined;
        var stdin_pipe: [2]i32 = undefined;
        if (stdin == StdIo.Pipe)
            stdin_pipe = %return makePipe();
        %defer if (stdin == StdIo.Pipe) { destroyPipe(stdin_pipe); };

        // TODO issue #295
        //const stdout_pipe = if (stdout == StdIo.Pipe) %return makePipe() else undefined;
        var stdout_pipe: [2]i32 = undefined;
        if (stdout == StdIo.Pipe) 
            stdout_pipe = %return makePipe();
        %defer if (stdout == StdIo.Pipe) { destroyPipe(stdout_pipe); };

        // TODO issue #295
        //const stderr_pipe = if (stderr == StdIo.Pipe) %return makePipe() else undefined;
        var stderr_pipe: [2]i32 = undefined;
        if (stderr == StdIo.Pipe) 
            stderr_pipe = %return makePipe();
        %defer if (stderr == StdIo.Pipe) { destroyPipe(stderr_pipe); };

        const any_ignore = (stdin == StdIo.Ignore or stdout == StdIo.Ignore or stderr == StdIo.Ignore);
        // TODO issue #295
        //const dev_null_fd = if (any_ignore) {
        //    %return os.posixOpen("/dev/null", posix.O_RDWR, 0, null)
        //} else {
        //    undefined
        //};
        var dev_null_fd: i32 = undefined;
        if (any_ignore)
            dev_null_fd = %return os.posixOpen("/dev/null", posix.O_RDWR, 0, null);

        // This pipe is used to communicate errors between the time of fork
        // and execve from the child process to the parent process.
        const err_pipe = %return makePipe();
        %defer destroyPipe(err_pipe);

        const pid = posix.fork();
        const pid_err = posix.getErrno(pid);
        if (pid_err > 0) {
            return switch (pid_err) {
                errno.EAGAIN, errno.ENOMEM, errno.ENOSYS => error.SystemResources,
                else => error.Unexpected,
            };
        }
        if (pid == 0) {
            // we are the child
            setUpChildIo(stdin, stdin_pipe[0], posix.STDIN_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(stdout, stdout_pipe[1], posix.STDOUT_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);
            setUpChildIo(stderr, stderr_pipe[1], posix.STDERR_FILENO, dev_null_fd) %%
                |err| forkChildErrReport(err_pipe[1], err);

            test (maybe_cwd) |cwd| {
                os.changeCurDir(allocator, cwd) %%
                    |err| forkChildErrReport(err_pipe[1], err);
            }

            os.posixExecve(exe_path, args, env_map, allocator) %%
                |err| forkChildErrReport(err_pipe[1], err);
        }

        // we are the parent
        if (stdin == StdIo.Pipe) { os.posixClose(stdin_pipe[0]); }
        if (stdout == StdIo.Pipe) { os.posixClose(stdout_pipe[1]); }
        if (stderr == StdIo.Pipe) { os.posixClose(stderr_pipe[1]); }
        if (any_ignore) { os.posixClose(dev_null_fd); }

        return ChildProcess {
            .pid = i32(pid),
            .err_pipe = err_pipe,

            .stdin = if (stdin == StdIo.Pipe) {
                io.OutStream {
                    .fd = stdin_pipe[1],
                    .buffer = undefined,
                    .index = 0,
                }
            } else {
                null
            },
            .stdout = if (stdout == StdIo.Pipe) {
                io.InStream {
                    .fd = stdout_pipe[0],
                }
            } else {
                null
            },
            .stderr = if (stderr == StdIo.Pipe) {
                io.InStream {
                    .fd = stderr_pipe[0],
                }
            } else {
                null
            },
        };
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
            errno.EMFILE, errno.ENFILE => error.SystemResources,
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
    mem.writeInt(bytes[0...], value, true);

    var index: usize = 0;
    while (index < bytes.len) {
        const amt_written = posix.write(fd, &bytes[index], bytes.len - index);
        const err = posix.getErrno(amt_written);
        if (err > 0) {
            switch (err) {
                errno.EINTR => continue,
                errno.EINVAL => unreachable,
                else => return error.SystemResources,
            }
        }
        index += amt_written;
    }
}

fn readIntFd(fd: i32) -> %ErrInt {
    var bytes: [@sizeOf(ErrInt)]u8 = undefined;

    var index: usize = 0;
    while (index < bytes.len) {
        const amt_written = posix.read(fd, &bytes[index], bytes.len - index);
        const err = posix.getErrno(amt_written);
        if (err > 0) {
            switch (err) {
                errno.EINTR => continue,
                errno.EINVAL => unreachable,
                else => return error.SystemResources,
            }
        }
        index += amt_written;
    }

    return mem.readInt(bytes[0...], ErrInt, true);
}

