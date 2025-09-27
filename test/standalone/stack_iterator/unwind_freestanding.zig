//! Test StackIterator on 'freestanding' target.  Based on unwind.zig.

const std = @import("std");

noinline fn frame3(expected: *[4]usize, addr_buf: *[4]usize) std.builtin.StackTrace {
    expected[0] = @returnAddress();
    return std.debug.captureCurrentStackTrace(.{
        .first_address = @returnAddress(),
        .allow_unsafe_unwind = true,
    }, addr_buf);
}

noinline fn frame2(expected: *[4]usize, addr_buf: *[4]usize) std.builtin.StackTrace {
    expected[1] = @returnAddress();
    return frame3(expected, addr_buf);
}

noinline fn frame1(expected: *[4]usize, addr_buf: *[4]usize) std.builtin.StackTrace {
    expected[2] = @returnAddress();

    // Use a stack frame that is too big to encode in __unwind_info's stack-immediate encoding
    // to exercise the stack-indirect encoding path
    var pad: [std.math.maxInt(u8) * @sizeOf(usize) + 1]u8 = undefined;
    _ = std.mem.doNotOptimizeAway(&pad);

    return frame2(expected, addr_buf);
}

noinline fn frame0(expected: *[4]usize, addr_buf: *[4]usize) std.builtin.StackTrace {
    expected[3] = @returnAddress();
    return frame1(expected, addr_buf);
}

/// No-OS entrypoint
export fn _start() callconv(.withStackAlign(.c, 1)) noreturn {
    var expected: [4]usize = undefined;
    var addr_buf: [4]usize = undefined;
    const trace = frame0(&expected, &addr_buf);

    // Since we can't print from this freestanding test, we'll just use the exit
    // code to communicate error conditions.

    // Unlike `unwind.zig`, we can expect *exactly* 4 frames, as we are the
    // actual entry point and the frame pointer will be 0 on entry.
    if (trace.index != 4) exit(1);
    if (trace.instruction_addresses[0] != expected[0]) exit(2);
    if (trace.instruction_addresses[1] != expected[1]) exit(3);
    if (trace.instruction_addresses[2] != expected[2]) exit(4);
    if (trace.instruction_addresses[3] != expected[3]) exit(5);

    exit(0);
}

fn exit(code: u8) noreturn {
    // We are intentionally compiling with the target OS being "freestanding" to
    // exercise std.debug, but we still need to exit the process somehow; so do
    // the appropriate x86_64-linux syscall.
    asm volatile (
        \\movl $60, %%eax
        \\syscall
        :
        : [code] "{edi}" (code),
        : .{ .edi = true, .eax = true });

    unreachable;
}
