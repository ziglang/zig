/// Test StackIterator on 'freestanding' target.  Based on unwind.zig.
const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;

noinline fn frame3(expected: *[4]usize, unwound: *[4]usize) void {
    expected[0] = @returnAddress();

    var it = debug.StackIterator.init(@returnAddress(), @frameAddress());
    defer it.deinit();

    // Save StackIterator's frame addresses into `unwound`:
    for (unwound) |*addr| {
        if (it.next()) |return_address| addr.* = return_address;
    }
}

noinline fn frame2(expected: *[4]usize, unwound: *[4]usize) void {
    expected[1] = @returnAddress();
    frame3(expected, unwound);
}

noinline fn frame1(expected: *[4]usize, unwound: *[4]usize) void {
    expected[2] = @returnAddress();

    // Use a stack frame that is too big to encode in __unwind_info's stack-immediate encoding
    // to exercise the stack-indirect encoding path
    var pad: [std.math.maxInt(u8) * @sizeOf(usize) + 1]u8 = undefined;
    _ = std.mem.doNotOptimizeAway(&pad);

    frame2(expected, unwound);
}

noinline fn frame0(expected: *[4]usize, unwound: *[4]usize) void {
    expected[3] = @returnAddress();
    frame1(expected, unwound);
}

// Freestanding entrypoint
export fn _start() callconv(.C) noreturn {
    var expected: [4]usize = undefined;
    var unwound: [4]usize = undefined;
    frame0(&expected, &unwound);

    // Verify result (no std.testing in freestanding)
    var missed: c_int = 0;
    for (expected, unwound) |expectFA, actualFA| {
        if (expectFA != actualFA) {
            missed += 1;
        }
    }

    // Need to compile as "freestanding" to exercise the StackIterator code, but when run as a
    // regression test need to actually exit.  So assume we're running on x86_64-linux ...
    asm volatile (
        \\movl $60, %%eax
        \\syscall
        :
        : [missed] "{edi}" (missed),
        : "edi", "eax"
    );

    while (true) {} // unreached
}
