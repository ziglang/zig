const builtin = @import("builtin");
const std = @import("std");
const os = std.os;

pub const log_level = .info;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) @panic("leaks");
    const al = gpa.allocator();

    const args = try std.process.argsAlloc(al);
    defer al.free(args);

    if (args.len <= 1) {
        try parentMain(al);
    } else {
        try childMain();
    }
}

const hello_msg = "hello";
const response_msg = "same to you";

fn parentMain(al: std.mem.Allocator) !void {
    const stdin_pipe = try os.pipe();
    const stdout_pipe = try os.pipe();

    const self_exe = try std.fs.selfExePathAlloc(al);
    defer al.free(self_exe);
    var child = std.ChildProcess.init(&[_][]const u8{ self_exe, "child" }, al);

    child.stdin_behavior = .Provided;
    child.stdin = std.fs.File{ .handle = stdin_pipe[0] };
    child.stdout_behavior = .Provided;
    child.stdout = std.fs.File{ .handle = stdout_pipe[1] };

    try child.spawn();
    os.close(stdin_pipe[0]);
    os.close(stdout_pipe[1]);

    std.log.debug("parent: sending hello", .{});
    {
        const len = try os.write(stdin_pipe[1], hello_msg);
        std.debug.assert(len == hello_msg.len);
        os.close(stdin_pipe[1]);
    }

    std.log.debug("parent: waiting for response", .{});
    {
        var buf: [50]u8 = undefined;
        const len = try os.read(stdout_pipe[0], &buf);
        std.debug.assert(len == response_msg.len);
        std.debug.assert(std.mem.eql(u8, buf[0..response_msg.len], response_msg));
    }
    std.log.debug("parent: got response", .{});
    const term = try child.wait();
    switch (term) {
        .Exited => |code| if (code != 0) @panic("non-zero exit code from child"),
        else => @panic("abnormal child process termination"),
    }
}

fn childMain() !void {
    std.log.debug("child: waiting for hello", .{});
    {
        var buf: [50]u8 = undefined;
        const len = try std.io.getStdIn().reader().read(&buf);
        std.debug.assert(len == hello_msg.len);
        std.debug.assert(std.mem.eql(u8, buf[0..hello_msg.len], hello_msg));
    }
    std.log.debug("child: sending response", .{});
    try std.io.getStdOut().writer().writeAll(response_msg);
    std.log.debug("child: done, exiting", .{});
}
