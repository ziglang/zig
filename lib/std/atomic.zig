const std = @import("std.zig");
const target = std.Target.current;

pub const Ordering = std.builtin.AtomicOrder;

pub const Stack = @import("atomic/stack.zig").Stack;
pub const Queue = @import("atomic/queue.zig").Queue;
pub const Atomic = @import("atomic/Atomic.zig").Atomic;

test "std.atomic" {
    _ = @import("atomic/stack.zig");
    _ = @import("atomic/queue.zig");
    _ = @import("atomic/Atomic.zig");
}

pub inline fn fence(comptime ordering: Ordering) void {
    switch (ordering) {
        .Acquire, .Release, .AcqRel, .SeqCst => {
            @fence(ordering);
        },
        else => {
            @compileLog(ordering, " only applies to a given memory location");
        },
    }
}

pub inline fn compilerFence(comptime ordering: Ordering) void {
    switch (ordering) {
        .Acquire, .Release, .AcqRel, .SeqCst => asm volatile ("" ::: "memory"),
        else => @compileLog(ordering, " only applies to a given memory location"),
    }
}

test "fence/compilerFence" {
    inline for (.{ .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        compilerFence(ordering);
        fence(ordering);
    }
}

/// Signals to the processor that the caller is inside a busy-wait spin-loop.
pub inline fn spinLoopHint() void {
    switch (target.cpu.arch) {
        // No-op instruction that can hint to save (or share with a hardware-thread)
        // pipelining/power resources
        // https://software.intel.com/content/www/us/en/develop/articles/benefitting-power-and-performance-sleep-loops.html
        .i386, .x86_64 => asm volatile ("pause" ::: "memory"),

        // No-op instruction that serves as a hardware-thread resource yield hint.
        // https://stackoverflow.com/a/7588941
        .powerpc64, .powerpc64le => asm volatile ("or 27, 27, 27" ::: "memory"),

        // `isb` appears more reliable for releasing execution resources than `yield`
        // on common aarch64 CPUs.
        // https://bugs.java.com/bugdatabase/view_bug.do?bug_id=8258604
        // https://bugs.mysql.com/bug.php?id=100664
        .aarch64, .aarch64_be, .aarch64_32 => asm volatile ("isb" ::: "memory"),

        // `yield` was introduced in v6k but is also available on v6m.
        // https://www.keil.com/support/man/docs/armasm/armasm_dom1361289926796.htm
        .arm, .armeb, .thumb, .thumbeb => {
            const can_yield = comptime std.Target.arm.featureSetHasAny(target.cpu.features, .{
                .has_v6k, .has_v6m,
            });
            if (can_yield) {
                asm volatile ("yield" ::: "memory");
            } else {
                asm volatile ("" ::: "memory");
            }
        },
        // Memory barrier to prevent the compiler from optimizing away the spin-loop
        // even if no hint_instruction was provided.
        else => asm volatile ("" ::: "memory"),
    }
}

test "spinLoopHint" {
    var i: usize = 10;
    while (i > 0) : (i -= 1) {
        spinLoopHint();
    }
}
