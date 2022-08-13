const builtin = @import("builtin");
const std = @import("std");
const os = std.os;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) @panic("leaks");
    const al = gpa.allocator();

    const args = try std.process.argsAlloc(al);
    defer al.free(args);

    if (args.len <= 1) {
        try parentMain(al);
    } else {
        try childMain(args);
    }
}

fn parentMain(al: std.mem.Allocator) !void {
    // mimic a real use case for child process setup, setting up a
    // pipe that needs to be closed in the child process
    const act = os.Sigaction{
        .handler = .{ .handler = os.SIG.IGN },
        .mask = os.empty_sigset,
        .flags = os.SA.SIGINFO,
    };
    try os.sigaction(os.SIG.PIPE, &act, null);
    const pipe = try os.pipe();

    const self_exe = try std.fs.selfExePathAlloc(al);
    defer al.free(self_exe);
    var read_pipe_str_buf: [30]u8 = undefined;
    const read_pipe_str = try std.fmt.bufPrint(&read_pipe_str_buf, "{d}", .{pipe[0]});
    var child = std.ChildProcess.init(&[_][]const u8{
        self_exe,
        read_pipe_str,
    }, al);
    if (try child.fork()) |forked| {
        // This statement is the purpose of this test. It demonstrates that
        // the ChildProcess API supports extra setup in the child process.
        //
        // In this case we close the write end of the pipe in the child process so that
        // when the parent process closes it, the read end of the pipe will also close,
        // otherwise, the pipe would stay open since the child process has a reference
        // to the write end of the pipe.
        os.close(pipe[1]);

        forked.setup() catch |err| forked.reportError(err);
        forked.reportError(forked.exec());
    }

    const len = try os.write(pipe[1], "hello");
    std.debug.assert(len == 5);
    os.close(pipe[1]);

    const term = try child.wait();
    switch (term) {
        .Exited => |code| if (code != 0) @panic("non-zero exit code from child"),
        else => @panic("abnormal child process termination"),
    }
}

fn childMain(args: []const []const u8) !void {
    const pipe_fd_str = args[1];
    const pipe_fd = try std.fmt.parseInt(os.fd_t, pipe_fd_str, 10);
    var buf: [5]u8 = undefined;
    {
        const len = try os.read(pipe_fd, &buf);
        std.debug.assert(len == 5);
        std.debug.assert(std.mem.eql(u8, &buf, "hello"));
    }
    {
        // if the write end of the pipe wasn't closed then we'll just wait
        // here forever
        try std.io.getStdOut().writer().writeAll("child process waiting for pipe to close...\n");
        const len = try os.read(pipe_fd, &buf);
        try std.io.getStdOut().writer().writeAll("pipe closed\n");
        std.debug.assert(len == 0);
    }
}
