const std = @import("std.zig");
const builtin = @import("builtin");

pub const Ordering = std.builtin.AtomicOrder;

pub const Stack = @import("atomic/stack.zig").Stack;
pub const Queue = @import("atomic/queue.zig").Queue;
pub const Atomic = @import("atomic/Atomic.zig").Atomic;

test {
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
    switch (builtin.target.cpu.arch) {
        // No-op instruction that can hint to save (or share with a hardware-thread)
        // pipelining/power resources
        // https://software.intel.com/content/www/us/en/develop/articles/benefitting-power-and-performance-sleep-loops.html
        .x86, .x86_64 => asm volatile ("pause" ::: "memory"),

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
            const can_yield = comptime std.Target.arm.featureSetHasAny(builtin.target.cpu.features, .{
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

/// The estimated size of the CPU's cache line when atomically updating memory.
/// Add this much padding or align to this boundary to avoid atomically-updated
/// memory from forcing cache invalidations on near, but non-atomic, memory.
///
// https://en.wikipedia.org/wiki/False_sharing
// https://github.com/golang/go/search?q=CacheLinePadSize
pub const cache_line = switch (builtin.cpu.arch) {
    // x86_64: Starting from Intel's Sandy Bridge, the spatial prefetcher pulls in pairs of 64-byte cache lines at a time.
    // - https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-optimization-manual.pdf
    // - https://github.com/facebook/folly/blob/1b5288e6eea6df074758f877c849b6e73bbb9fbb/folly/lang/Align.h#L107
    //
    // aarch64: Some big.LITTLE ARM archs have "big" cores with 128-byte cache lines:
    // - https://www.mono-project.com/news/2016/09/12/arm64-icache/
    // - https://cpufun.substack.com/p/more-m1-fun-hardware-information
    //
    // powerpc64: PPC has 128-byte cache lines
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_ppc64x.go#L9
    .x86_64, .aarch64, .powerpc64 => 128,

    // These platforms reportedly have 32-byte cache lines
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_arm.go#L7
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_mips.go#L7
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_mipsle.go#L7
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_mips64x.go#L9
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_riscv64.go#L7
    .arm, .mips, .mips64, .riscv64 => 32,

    // This platform reportedly has 256-byte cache lines
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_s390x.go#L7
    .s390x => 256,

    // Other x86 and WASM platforms have 64-byte cache lines.
    // The rest of the architectures are assumed to be similar.
    // - https://github.com/golang/go/blob/dda2991c2ea0c5914714469c4defc2562a907230/src/internal/cpu/cpu_x86.go#L9
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_wasm.go#L7
    else => 64,
};
