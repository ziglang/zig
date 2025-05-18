const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const testing = std.testing;
const posix = std.posix;
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;
const link_libc = builtin.link_libc;

const max_stack_trace_depth = 32;

const do_signal = switch (native_os) {
    .wasi, .windows => false,
    else => true,
};

var installed_signal_handler = false;
var handled_signal = false;
var captured_frames = false;

const AddrArray = std.BoundedArray(usize, max_stack_trace_depth);

// Global variables to capture different stack traces in.  Compared at the end of main() against "expected" array
var signal_frames: AddrArray = undefined;
var full_frames: AddrArray = undefined;
var skip_frames: AddrArray = undefined;

// StackIterator is the core of this test, but still worth executing the dumpCurrentStackTrace* functions
// (These platforms don't fail on StackIterator, they just return empty traces.)
const supports_stack_iterator =
    (native_os != .windows) and // StackIterator is (currently?) POSIX/DWARF centered.
    !native_arch.isWasm(); // wasm has no introspection

// Getting the backtrace inside the signal handler (with the ucontext_t)
// gets stuck in a loop on some systems:
const expect_signal_frame_overflow =
    (native_arch.isArm() and link_libc) or // loops above main()
    native_arch.isAARCH64(); // non-deterministic, sometimes overflows, sometimes not

// Getting the backtrace inside the signal handler (with the ucontext_t)
// does not contain the expected content on some systems:
const expect_signal_frame_useless =
    (native_arch == .x86_64 and link_libc and builtin.abi.isGnu()) or // stuck on pthread_kill?
    (native_arch == .x86_64 and link_libc and builtin.abi.isMusl() and builtin.omit_frame_pointer) or // immediately confused backtrace
    (native_arch == .x86_64 and builtin.os.tag.isDarwin()) or // immediately confused backtrace
    native_arch.isAARCH64() or // non-deterministic, sometimes overflows, sometimes confused
    native_arch.isRISCV() or // `ucontext_t` not defined yet
    native_arch.isMIPS() or // Missing ucontext_t. Most stack traces are empty ... (with or without libc)
    native_arch.isPowerPC() or // dumpCurrent* useless, StackIterator empty, ctx-based trace empty (with or without libc)
    (native_arch.isThumb() and !link_libc); // stops on first element of trace

// Signal handler to gather stack traces from the given signal context.
fn testFromSigUrg(sig: i32, info: *const posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.c) void {
    // std.debug.print("sig={} info={*} ctx_ptr={*}\n", .{ sig, info, ctx_ptr });
    _ = info;
    _ = sig;

    var ctx: *posix.ucontext_t = undefined;
    var local_ctx: posix.ucontext_t = undefined;

    // Darwin kernels don't align `ctx_ptr` properly. Handle this defensively.
    if (builtin.os.tag.isDarwin() and builtin.cpu.arch == .aarch64) {
        const align_ctx: *align(1) posix.ucontext_t = @ptrCast(ctx_ptr);
        local_ctx = align_ctx.*;

        // The kernel incorrectly writes the contents of `__mcontext_data` right after `mcontext`,
        // rather than after the 8 bytes of padding that are supposed to sit between the two. Copy the
        // contents to the right place so that the `mcontext` pointer will be correct after the
        // `relocateContext` call below.
        local_ctx.__mcontext_data = @as(*align(1) extern struct {
            onstack: c_int,
            sigmask: std.c.sigset_t,
            stack: std.c.stack_t,
            link: ?*std.c.ucontext_t,
            mcsize: u64,
            mcontext: *std.c.mcontext_t,
            __mcontext_data: std.c.mcontext_t align(@sizeOf(usize)), // Disable padding after `mcontext`.
        }, @ptrCast(align_ctx)).__mcontext_data;

        debug.relocateContext(&local_ctx);
        ctx = &local_ctx;
    } else {
        ctx = @ptrCast(@alignCast(ctx_ptr));
    }

    std.debug.print("(from signal handler) dumpStackTraceFromBase({*} => {*}):\n", .{ ctx_ptr, ctx });
    debug.dumpStackTraceFromBase(ctx);

    const debug_info = debug.getSelfDebugInfo() catch @panic("failed to openSelfDebugInfo");
    var sig_it = debug.StackIterator.initWithContext(null, debug_info, ctx) catch @panic("failed StackIterator.initWithContext");
    defer sig_it.deinit();

    // Save the backtrace from 'ctx' into the 'signal_frames' array
    while (sig_it.next()) |return_address| {
        signal_frames.append(return_address) catch @panic("signal_frames.append()");
        if (signal_frames.len == signal_frames.capacity()) break;
    }

    handled_signal = true;
}

// Leaf test function.  Gather backtraces for comparison with "expected".
noinline fn frame3(expected: *[4]usize) void {
    expected[0] = @returnAddress();

    // Test the print-current-stack trace functions
    std.debug.print("dumpCurrentStackTrace(null):\n", .{});
    debug.dumpCurrentStackTrace(null);

    std.debug.print("dumpCurrentStackTrace({x}):\n", .{expected[0]});
    debug.dumpCurrentStackTrace(expected[0]);

    // Trigger signal handler here and see that it's ctx is a viable start for unwinding
    if (do_signal and installed_signal_handler) {
        posix.raise(posix.SIG.URG) catch @panic("failed to raise posix.SIG.URG");
    }

    // Capture stack traces directly, two ways, if supported
    if (std.debug.ThreadContext != void and native_os != .windows) {
        var context: debug.ThreadContext = undefined;

        const gotContext = debug.getContext(&context);

        if (!std.debug.have_getcontext) {
            testing.expectEqual(false, gotContext) catch @panic("getContext unexpectedly succeeded");
        } else {
            testing.expectEqual(true, gotContext) catch @panic("failed to getContext");

            const debug_info = debug.getSelfDebugInfo() catch @panic("failed to openSelfDebugInfo");

            // Run the "full" iterator
            testing.expect(debug.getContext(&context)) catch @panic("failed to getContext");
            var full_it = debug.StackIterator.initWithContext(null, debug_info, &context) catch @panic("failed StackIterator.initWithContext");
            defer full_it.deinit();

            while (full_it.next()) |return_address| {
                full_frames.append(return_address) catch @panic("full_frames.append()");
                if (full_frames.len == full_frames.capacity()) break;
            }

            // Run the iterator that skips until `expected[0]` is seen
            testing.expect(debug.getContext(&context)) catch @panic("failed 2nd getContext");
            var skip_it = debug.StackIterator.initWithContext(expected[0], debug_info, &context) catch @panic("failed StackIterator.initWithContext");
            defer skip_it.deinit();

            while (skip_it.next()) |return_address| {
                skip_frames.append(return_address) catch @panic("skip_frames.append()");
                if (skip_frames.len == skip_frames.capacity()) break;
            }

            captured_frames = true;
        }
    }
}

noinline fn frame2(expected: *[4]usize) void {
    // Exercise different __unwind_info / DWARF CFI encodings by forcing some registers to be restored
    if (builtin.target.ofmt != .c) {
        switch (native_arch) {
            .x86 => {
                if (builtin.omit_frame_pointer) {
                    asm volatile (
                        \\movl $3, %%ebx
                        \\movl $1, %%ecx
                        \\movl $2, %%edx
                        \\movl $7, %%edi
                        \\movl $6, %%esi
                        \\movl $5, %%ebp
                        ::: "ebx", "ecx", "edx", "edi", "esi", "ebp");
                } else {
                    asm volatile (
                        \\movl $3, %%ebx
                        \\movl $1, %%ecx
                        \\movl $2, %%edx
                        \\movl $7, %%edi
                        \\movl $6, %%esi
                        ::: "ebx", "ecx", "edx", "edi", "esi");
                }
            },
            .x86_64 => {
                if (builtin.omit_frame_pointer) {
                    asm volatile (
                        \\movq $3, %%rbx
                        \\movq $12, %%r12
                        \\movq $13, %%r13
                        \\movq $14, %%r14
                        \\movq $15, %%r15
                        \\movq $6, %%rbp
                        ::: "rbx", "r12", "r13", "r14", "r15", "rbp");
                } else {
                    asm volatile (
                        \\movq $3, %%rbx
                        \\movq $12, %%r12
                        \\movq $13, %%r13
                        \\movq $14, %%r14
                        \\movq $15, %%r15
                        ::: "rbx", "r12", "r13", "r14", "r15");
                }
            },
            else => {},
        }
    }

    expected[1] = @returnAddress();
    frame3(expected);
}

noinline fn frame1(expected: *[4]usize) void {
    expected[2] = @returnAddress();

    // Use a stack frame that is too big to encode in __unwind_info's stack-immediate encoding
    // to exercise the stack-indirect encoding path
    var pad: [std.math.maxInt(u8) * @sizeOf(usize) + 1]u8 = undefined;
    _ = std.mem.doNotOptimizeAway(&pad);

    frame2(expected);
}

noinline fn frame0(expected: *[4]usize) void {
    expected[3] = @returnAddress();
    frame1(expected);
}

pub fn main() !void {
    try run_tests();
    std.debug.print("Test complete.\n", .{});
}

fn run_tests() !void {
    // Disabled until the DWARF unwinder bugs on .aarch64 are solved
    if (builtin.omit_frame_pointer and comptime builtin.target.os.tag.isDarwin() and native_arch == .aarch64) return;

    if (do_signal) {
        std.debug.print("Installing SIGURG handler ...\n", .{});
        posix.sigaction(posix.SIG.URG, &.{
            .handler = .{ .sigaction = testFromSigUrg },
            .mask = posix.sigemptyset(),
            .flags = (posix.SA.SIGINFO | posix.SA.RESTART),
        }, null);
        installed_signal_handler = true;
    } else {
        std.debug.print("(No signal-based backtrace on this configuration.)\n", .{});
        installed_signal_handler = false;
    }
    handled_signal = false;

    signal_frames = try AddrArray.init(0);
    skip_frames = try AddrArray.init(0);
    full_frames = try AddrArray.init(0);

    std.debug.print("Running...\n", .{});

    var expected: [4]usize = undefined;
    frame0(&expected);

    std.debug.print("Verification: arch={s} link_libc={} have_ucontext={} have_getcontext={} ...\n", .{
        @tagName(native_arch), link_libc, std.debug.have_ucontext, std.debug.have_getcontext,
    });
    std.debug.print("  expected={any}\n", .{expected});
    std.debug.print("  full_frames={any}\n", .{full_frames.slice()});
    std.debug.print("  skip_frames={any}\n", .{skip_frames.slice()});
    std.debug.print("  signal_frames={any}\n", .{signal_frames.slice()});

    var fail_count: usize = 0;

    if (do_signal and installed_signal_handler) {
        try testing.expectEqual(true, handled_signal);
    }

    // None of the backtraces should overflow max_stack_trace_depth

    if (skip_frames.len == skip_frames.capacity()) {
        std.debug.print("skip_frames contains too many frames: {}\n", .{skip_frames.len});
        fail_count += 1;
    }

    if (full_frames.len == full_frames.capacity()) {
        std.debug.print("full_frames contains too many frames: {}\n", .{full_frames.len});
        fail_count += 1;
    }

    if (signal_frames.len == signal_frames.capacity()) {
        if (expect_signal_frame_overflow) {
            // The signal_frames backtrace overflows.  Ignore this for now.
            std.debug.print("(expected) signal_frames overflow: {}\n", .{signal_frames.len});
        } else {
            std.debug.print("signal_frames contains too many frames: {}\n", .{signal_frames.len});
            fail_count += 1;
        }
    }

    if (supports_stack_iterator) {
        if (captured_frames) {
            // Saved 'skip_frames' should start with the expected frames, exactly.
            try testing.expectEqual(skip_frames.slice()[0..4].*, expected);

            // The return addresses in "expected[]" should show up, in order, in the "full_frames" array
            var found = false;
            for (0..full_frames.len) |i| {
                const addr = full_frames.get(i);
                if (addr == expected[0]) {
                    try testing.expectEqual(full_frames.get(i + 1), expected[1]);
                    try testing.expectEqual(full_frames.get(i + 2), expected[2]);
                    try testing.expectEqual(full_frames.get(i + 3), expected[3]);
                    found = true;
                }
            }
            if (!found) {
                std.debug.print("full_frames[...] does not include expected[0..4]\n", .{});
                fail_count += 1;
            }
        }

        if (installed_signal_handler and handled_signal) {
            // The return addresses in "expected[]" should show up, in order, in the "signal_frames" array
            var found = false;
            for (0..signal_frames.len) |i| {
                const signal_addr = signal_frames.get(i);
                if (signal_addr == expected[0]) {
                    try testing.expectEqual(signal_frames.get(i + 1), expected[1]);
                    try testing.expectEqual(signal_frames.get(i + 2), expected[2]);
                    try testing.expectEqual(signal_frames.get(i + 3), expected[3]);
                    found = true;
                }
            }
            if (!found) {
                if (expect_signal_frame_useless) {
                    std.debug.print("(expected) signal_frames[...] does not include expected[0..4]\n", .{});
                } else {
                    std.debug.print("signal_frames[...] does not include expected[0..4]\n", .{});
                    fail_count += 1;
                }
            }
        }
    } else {
        // If these tests fail, then this platform now supports StackIterator
        try testing.expectEqual(0, skip_frames.len);
        try testing.expectEqual(0, full_frames.len);
        try testing.expectEqual(0, signal_frames.len);
    }

    try testing.expectEqual(0, fail_count);
}
