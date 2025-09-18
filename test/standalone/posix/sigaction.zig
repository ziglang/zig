const std = @import("std");
const builtin = @import("builtin");

const native_os = builtin.target.os.tag;

pub fn main() !void {
    if (native_os == .wasi or native_os == .windows) {
        return; // no sigaction
    }

    try test_sigaction();
    try test_sigset_bits();
}

fn test_sigaction() !void {
    if (native_os == .macos and builtin.target.cpu.arch == .x86_64) {
        return; // https://github.com/ziglang/zig/issues/15381
    }

    const test_signo = std.posix.SIG.URG; // URG only because it is ignored by default in debuggers

    const S = struct {
        var handler_called_count: u32 = 0;

        fn handler(sig: i32, info: *const std.posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.c) void {
            _ = ctx_ptr;
            // Check that we received the correct signal.
            const info_sig = switch (native_os) {
                .netbsd => info.info.signo,
                else => info.signo,
            };
            if (sig == test_signo and sig == info_sig) {
                handler_called_count += 1;
            }
        }
    };

    var sa: std.posix.Sigaction = .{
        .handler = .{ .sigaction = &S.handler },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.SIGINFO | std.posix.SA.RESETHAND,
    };

    var old_sa: std.posix.Sigaction = undefined;

    // Install the new signal handler.
    std.posix.sigaction(test_signo, &sa, null);

    // Check that we can read it back correctly.
    std.posix.sigaction(test_signo, null, &old_sa);
    try std.testing.expectEqual(&S.handler, old_sa.handler.sigaction.?);
    try std.testing.expect((old_sa.flags & std.posix.SA.SIGINFO) != 0);

    // Invoke the handler.
    try std.posix.raise(test_signo);
    try std.testing.expectEqual(1, S.handler_called_count);

    // Check if passing RESETHAND correctly reset the handler to SIG_DFL
    std.posix.sigaction(test_signo, null, &old_sa);
    try std.testing.expectEqual(std.posix.SIG.DFL, old_sa.handler.handler);

    // Reinstall the signal w/o RESETHAND and re-raise
    sa.flags = std.posix.SA.SIGINFO;
    std.posix.sigaction(test_signo, &sa, null);
    try std.posix.raise(test_signo);
    try std.testing.expectEqual(2, S.handler_called_count);

    // Now set the signal to ignored
    sa.handler = .{ .handler = std.posix.SIG.IGN };
    sa.flags = 0;
    std.posix.sigaction(test_signo, &sa, null);

    // Re-raise to ensure handler is actually ignored
    try std.posix.raise(test_signo);
    try std.testing.expectEqual(2, S.handler_called_count);

    // Ensure that ignored state is returned when querying
    std.posix.sigaction(test_signo, null, &old_sa);
    try std.testing.expectEqual(std.posix.SIG.IGN, old_sa.handler.handler);
}

fn test_sigset_bits() !void {
    const NO_SIG: i32 = 0;

    const S = struct {
        var expected_sig: i32 = undefined;
        var seen_sig: i32 = NO_SIG;

        fn handler(sig: i32, info: *const std.posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.c) void {
            _ = ctx_ptr;

            const info_sig = switch (native_os) {
                .netbsd => info.info.signo,
                else => info.signo,
            };
            if (seen_sig == NO_SIG and sig == expected_sig and sig == info_sig) {
                seen_sig = sig;
            }
        }
    };

    // Assume this is a single-threaded process where the current thread has the
    // 'pid' thread id.  (The sigprocmask calls are thread-private state.)
    const self_tid = std.posix.system.getpid();

    // To check that sigset_t mapping matches kernel (think u32/u64 mismatches on
    // big-endian), try sending a blocked signal to make sure the mask matches the
    // signal.  (Send URG and CHLD because they're ignored by default in the
    // debugger, vs. USR1 or other named signals)
    inline for ([_]i32{ std.posix.SIG.URG, std.posix.SIG.CHLD, 62, 94, 126 }) |test_signo| {
        if (test_signo >= std.posix.NSIG) continue;

        S.expected_sig = test_signo;
        S.seen_sig = NO_SIG;

        const sa: std.posix.Sigaction = .{
            .handler = .{ .sigaction = &S.handler },
            .mask = std.posix.sigemptyset(),
            .flags = std.posix.SA.SIGINFO | std.posix.SA.RESETHAND,
        };

        var old_sa: std.posix.Sigaction = undefined;

        // Install the new signal handler.
        std.posix.sigaction(test_signo, &sa, &old_sa);

        // block the signal and see that its delayed until unblocked
        var block_one: std.posix.sigset_t = std.posix.sigemptyset();
        std.posix.sigaddset(&block_one, test_signo);
        std.posix.sigprocmask(std.posix.SIG.BLOCK, &block_one, null);

        // qemu maps target signals to host signals 1-to-1, so targets
        // with more signals than the host will fail to send the signal.
        const rc = std.posix.system.kill(self_tid, test_signo);
        switch (std.posix.errno(rc)) {
            .SUCCESS => {
                // See that the signal is blocked, then unblocked
                try std.testing.expectEqual(NO_SIG, S.seen_sig);
                std.posix.sigprocmask(std.posix.SIG.UNBLOCK, &block_one, null);
                try std.testing.expectEqual(test_signo, S.seen_sig);
            },
            .INVAL => {
                // Signal won't get delviered.  Just clean up.
                std.posix.sigprocmask(std.posix.SIG.UNBLOCK, &block_one, null);
                try std.testing.expectEqual(NO_SIG, S.seen_sig);
            },
            else => |errno| return std.posix.unexpectedErrno(errno),
        }

        // Restore original handler
        std.posix.sigaction(test_signo, &old_sa, null);
    }
}
