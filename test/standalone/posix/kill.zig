const std = @import("std");
const posix = std.posix;
const builtin = @import("builtin");
const native_os = builtin.target.os.tag;

pub fn main() !void {
    try test_kill_zero_self_should_succeed();
    try test_kill_nonexistent();
}

fn test_kill_nonexistent() !void {
    if ((native_os != .linux) and (native_os != .macos)) return;
    // Linux is limited by PID_MAX_LIMIT constant which is around 4 million
    // MacOS maximum pid appears to be 99999 and not configurable.
    // Others are unknown thus not tested.
    const impossible_pid: posix.pid_t = 1_999_999_999;
    try std.testing.expectError(posix.KillError.ProcessNotFound, posix.kill(impossible_pid, .INVAL));
}

fn test_kill_zero_self_should_succeed() !void {
    // Windows does not have kill -0 equivalent
    if (native_os == .windows) return;
    try posix.kill(posix.getpid(), .INVAL);
}
