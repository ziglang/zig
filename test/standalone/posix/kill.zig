const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    try test_kill_zero_self_should_succeed();
    try test_kill_nonexistent();
}

fn test_kill_nonexistent() !void {
    const impossible_pid: posix.pid_t = 1_999_999_999;
    posix.kill(impossible_pid, .INVAL) catch |err| switch (err) {
        posix.KillError.ProcessNotFound => return,
        else => return err,
    };
    return error.ProcessShouldHaveNotBeenFound;
}

fn test_kill_zero_self_should_succeed() !void {
    try posix.kill(posix.getpid(), .INVAL);
}
