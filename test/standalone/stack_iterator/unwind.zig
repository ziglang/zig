const std = @import("std");
const builtin = @import("builtin");
const fatal = std.process.fatal;

noinline fn frame3(expected: *[4]usize, addr_buf: *[4]usize) std.builtin.StackTrace {
    expected[0] = @returnAddress();
    return std.debug.captureCurrentStackTrace(.{
        .first_address = @returnAddress(),
        .allow_unsafe_unwind = true,
    }, addr_buf);
}

noinline fn frame2(expected: *[4]usize, addr_buf: *[4]usize) std.builtin.StackTrace {
    // Exercise different __unwind_info / DWARF CFI encodings by forcing some registers to be restored
    if (builtin.target.ofmt != .c) {
        switch (builtin.target.cpu.arch) {
            .x86 => {
                if (builtin.omit_frame_pointer) {
                    asm volatile (
                        \\movl $3, %%ebx
                        \\movl $1, %%ecx
                        \\movl $2, %%edx
                        \\movl $7, %%edi
                        \\movl $6, %%esi
                        \\movl $5, %%ebp
                        ::: .{ .ebx = true, .ecx = true, .edx = true, .edi = true, .esi = true, .ebp = true });
                } else {
                    asm volatile (
                        \\movl $3, %%ebx
                        \\movl $1, %%ecx
                        \\movl $2, %%edx
                        \\movl $7, %%edi
                        \\movl $6, %%esi
                        ::: .{ .ebx = true, .ecx = true, .edx = true, .edi = true, .esi = true });
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
                        ::: .{ .rbx = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .rbp = true });
                } else {
                    asm volatile (
                        \\movq $3, %%rbx
                        \\movq $12, %%r12
                        \\movq $13, %%r13
                        \\movq $14, %%r14
                        \\movq $15, %%r15
                        ::: .{ .rbx = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true });
                }
            },
            else => {},
        }
    }

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

pub fn main() void {
    if (std.debug.cpu_context.Native == noreturn and builtin.omit_frame_pointer) {
        // Stack unwinding is impossible.
        return;
    }

    var expected: [4]usize = undefined;
    var addr_buf: [4]usize = undefined;
    const trace = frame0(&expected, &addr_buf);
    // There may be *more* than 4 frames (due to the caller of `main`); that's okay.
    if (trace.index < 4) {
        fatal("expected at least 4 frames, got '{d}':\n{f}", .{ trace.index, &trace });
    }
    if (!std.mem.eql(usize, trace.instruction_addresses, &expected)) {
        const expected_trace: std.builtin.StackTrace = .{
            .index = 4,
            .instruction_addresses = &expected,
        };
        fatal("expected trace:\n{f}\nactual trace:\n{f}", .{ &expected_trace, &trace });
    }
}
