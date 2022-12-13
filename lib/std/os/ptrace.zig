const std = @import("std");
const builtin = @import("builtin");

const os = @import("../os.zig");
const system = os.system;
const errno = system.getErrno;
const pid_t = system.pid_t;
const unexpectedErrno = os.unexpectedErrno;
const UnexpectedError = os.UnexpectedError;

pub usingnamespace ptrace;

const ptrace = if (builtin.target.isDarwin()) struct {
    pub const PtraceError = error{
        ProcessNotFound,
        PermissionDenied,
    } || UnexpectedError;

    pub fn ptrace(request: i32, pid: pid_t, addr: ?[*]u8, signal: i32) PtraceError!void {
        switch (errno(system.ptrace(request, pid, addr, signal))) {
            .SUCCESS => return,
            .SRCH => return error.ProcessNotFound,
            .INVAL => unreachable,
            .BUSY, .PERM => return error.PermissionDenied,
            else => |err| return unexpectedErrno(err),
        }
    }
} else struct {};
