/// This is a thin wrapper around a primitive value to prevent accidental data races.
pub fn Value(comptime T: type) type {
    return extern struct {
        /// Care must be taken to avoid data races when interacting with this field directly.
        raw: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .raw = value };
        }

        pub const fence = @compileError("@fence is deprecated, use other atomics to establish ordering");

        pub inline fn load(self: *const Self, comptime order: AtomicOrder) T {
            return @atomicLoad(T, &self.raw, order);
        }

        pub inline fn store(self: *Self, value: T, comptime order: AtomicOrder) void {
            @atomicStore(T, &self.raw, value, order);
        }

        pub inline fn swap(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Xchg, operand, order);
        }

        pub inline fn cmpxchgWeak(
            self: *Self,
            expected_value: T,
            new_value: T,
            comptime success_order: AtomicOrder,
            comptime fail_order: AtomicOrder,
        ) ?T {
            return @cmpxchgWeak(T, &self.raw, expected_value, new_value, success_order, fail_order);
        }

        pub inline fn cmpxchgStrong(
            self: *Self,
            expected_value: T,
            new_value: T,
            comptime success_order: AtomicOrder,
            comptime fail_order: AtomicOrder,
        ) ?T {
            return @cmpxchgStrong(T, &self.raw, expected_value, new_value, success_order, fail_order);
        }

        pub inline fn fetchAdd(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Add, operand, order);
        }

        pub inline fn fetchSub(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Sub, operand, order);
        }

        pub inline fn fetchMin(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Min, operand, order);
        }

        pub inline fn fetchMax(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Max, operand, order);
        }

        pub inline fn fetchAnd(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .And, operand, order);
        }

        pub inline fn fetchNand(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Nand, operand, order);
        }

        pub inline fn fetchXor(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Xor, operand, order);
        }

        pub inline fn fetchOr(self: *Self, operand: T, comptime order: AtomicOrder) T {
            return @atomicRmw(T, &self.raw, .Or, operand, order);
        }

        pub inline fn rmw(
            self: *Self,
            comptime op: std.builtin.AtomicRmwOp,
            operand: T,
            comptime order: AtomicOrder,
        ) T {
            return @atomicRmw(T, &self.raw, op, operand, order);
        }

        const Bit = std.math.Log2Int(T);

        /// Marked `inline` so that if `bit` is comptime-known, the instruction
        /// can be lowered to a more efficient machine code instruction if
        /// possible.
        pub inline fn bitSet(self: *Self, bit: Bit, comptime order: AtomicOrder) u1 {
            const mask = @as(T, 1) << bit;
            const value = self.fetchOr(mask, order);
            return @intFromBool(value & mask != 0);
        }

        /// Marked `inline` so that if `bit` is comptime-known, the instruction
        /// can be lowered to a more efficient machine code instruction if
        /// possible.
        pub inline fn bitReset(self: *Self, bit: Bit, comptime order: AtomicOrder) u1 {
            const mask = @as(T, 1) << bit;
            const value = self.fetchAnd(~mask, order);
            return @intFromBool(value & mask != 0);
        }

        /// Marked `inline` so that if `bit` is comptime-known, the instruction
        /// can be lowered to a more efficient machine code instruction if
        /// possible.
        pub inline fn bitToggle(self: *Self, bit: Bit, comptime order: AtomicOrder) u1 {
            const mask = @as(T, 1) << bit;
            const value = self.fetchXor(mask, order);
            return @intFromBool(value & mask != 0);
        }
    };
}

test Value {
    const RefCount = struct {
        count: Value(usize),
        dropFn: *const fn (*RefCount) void,

        const RefCount = @This();

        fn ref(rc: *RefCount) void {
            // no synchronization necessary; just updating a counter.
            _ = rc.count.fetchAdd(1, .monotonic);
        }

        fn unref(rc: *RefCount) void {
            // release ensures code before unref() happens-before the
            // count is decremented as dropFn could be called by then.
            if (rc.count.fetchSub(1, .release) == 1) {
                // seeing 1 in the counter means that other unref()s have happened,
                // but it doesn't mean that uses before each unref() are visible.
                // The load acquires the release-sequence created by previous unref()s
                // in order to ensure visibility of uses before dropping.
                _ = rc.count.load(.acquire);
                (rc.dropFn)(rc);
            }
        }

        fn noop(rc: *RefCount) void {
            _ = rc;
        }
    };

    var ref_count: RefCount = .{
        .count = Value(usize).init(0),
        .dropFn = RefCount.noop,
    };
    ref_count.ref();
    ref_count.unref();
}

test "Value.swap" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.swap(10, .seq_cst));
    try testing.expectEqual(@as(usize, 10), x.load(.seq_cst));

    const E = enum(usize) { a, b, c };
    var y = Value(E).init(.c);
    try testing.expectEqual(E.c, y.swap(.a, .seq_cst));
    try testing.expectEqual(E.a, y.load(.seq_cst));

    var z = Value(f32).init(5.0);
    try testing.expectEqual(@as(f32, 5.0), z.swap(10.0, .seq_cst));
    try testing.expectEqual(@as(f32, 10.0), z.load(.seq_cst));

    var a = Value(bool).init(false);
    try testing.expectEqual(false, a.swap(true, .seq_cst));
    try testing.expectEqual(true, a.load(.seq_cst));

    var b = Value(?*u8).init(null);
    try testing.expectEqual(@as(?*u8, null), b.swap(@as(?*u8, @ptrFromInt(@alignOf(u8))), .seq_cst));
    try testing.expectEqual(@as(?*u8, @ptrFromInt(@alignOf(u8))), b.load(.seq_cst));
}

test "Value.store" {
    var x = Value(usize).init(5);
    x.store(10, .seq_cst);
    try testing.expectEqual(@as(usize, 10), x.load(.seq_cst));
}

test "Value.cmpxchgWeak" {
    var x = Value(usize).init(0);

    try testing.expectEqual(@as(?usize, 0), x.cmpxchgWeak(1, 0, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(usize, 0), x.load(.seq_cst));

    while (x.cmpxchgWeak(0, 1, .seq_cst, .seq_cst)) |_| {}
    try testing.expectEqual(@as(usize, 1), x.load(.seq_cst));

    while (x.cmpxchgWeak(1, 0, .seq_cst, .seq_cst)) |_| {}
    try testing.expectEqual(@as(usize, 0), x.load(.seq_cst));
}

test "Value.cmpxchgStrong" {
    var x = Value(usize).init(0);
    try testing.expectEqual(@as(?usize, 0), x.cmpxchgStrong(1, 0, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(usize, 0), x.load(.seq_cst));
    try testing.expectEqual(@as(?usize, null), x.cmpxchgStrong(0, 1, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(usize, 1), x.load(.seq_cst));
    try testing.expectEqual(@as(?usize, null), x.cmpxchgStrong(1, 0, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(usize, 0), x.load(.seq_cst));
}

test "Value.fetchAdd" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchAdd(5, .seq_cst));
    try testing.expectEqual(@as(usize, 10), x.load(.seq_cst));
    try testing.expectEqual(@as(usize, 10), x.fetchAdd(std.math.maxInt(usize), .seq_cst));
    try testing.expectEqual(@as(usize, 9), x.load(.seq_cst));
}

test "Value.fetchSub" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchSub(5, .seq_cst));
    try testing.expectEqual(@as(usize, 0), x.load(.seq_cst));
    try testing.expectEqual(@as(usize, 0), x.fetchSub(1, .seq_cst));
    try testing.expectEqual(@as(usize, std.math.maxInt(usize)), x.load(.seq_cst));
}

test "Value.fetchMin" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchMin(0, .seq_cst));
    try testing.expectEqual(@as(usize, 0), x.load(.seq_cst));
    try testing.expectEqual(@as(usize, 0), x.fetchMin(10, .seq_cst));
    try testing.expectEqual(@as(usize, 0), x.load(.seq_cst));
}

test "Value.fetchMax" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchMax(10, .seq_cst));
    try testing.expectEqual(@as(usize, 10), x.load(.seq_cst));
    try testing.expectEqual(@as(usize, 10), x.fetchMax(5, .seq_cst));
    try testing.expectEqual(@as(usize, 10), x.load(.seq_cst));
}

test "Value.fetchAnd" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchAnd(0b10, .seq_cst));
    try testing.expectEqual(@as(usize, 0b10), x.load(.seq_cst));
    try testing.expectEqual(@as(usize, 0b10), x.fetchAnd(0b00, .seq_cst));
    try testing.expectEqual(@as(usize, 0b00), x.load(.seq_cst));
}

test "Value.fetchNand" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchNand(0b10, .seq_cst));
    try testing.expectEqual(~@as(usize, 0b10), x.load(.seq_cst));
    try testing.expectEqual(~@as(usize, 0b10), x.fetchNand(0b00, .seq_cst));
    try testing.expectEqual(~@as(usize, 0b00), x.load(.seq_cst));
}

test "Value.fetchOr" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchOr(0b100, .seq_cst));
    try testing.expectEqual(@as(usize, 0b111), x.load(.seq_cst));
    try testing.expectEqual(@as(usize, 0b111), x.fetchOr(0b010, .seq_cst));
    try testing.expectEqual(@as(usize, 0b111), x.load(.seq_cst));
}

test "Value.fetchXor" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchXor(0b10, .seq_cst));
    try testing.expectEqual(@as(usize, 0b01), x.load(.seq_cst));
    try testing.expectEqual(@as(usize, 0b01), x.fetchXor(0b01, .seq_cst));
    try testing.expectEqual(@as(usize, 0b00), x.load(.seq_cst));
}

test "Value.bitSet" {
    var x = Value(usize).init(0);

    for (0..@bitSizeOf(usize)) |bit_index| {
        const bit = @as(std.math.Log2Int(usize), @intCast(bit_index));
        const mask = @as(usize, 1) << bit;

        // setting the bit should change the bit
        try testing.expect(x.load(.seq_cst) & mask == 0);
        try testing.expectEqual(@as(u1, 0), x.bitSet(bit, .seq_cst));
        try testing.expect(x.load(.seq_cst) & mask != 0);

        // setting it again shouldn't change the bit
        try testing.expectEqual(@as(u1, 1), x.bitSet(bit, .seq_cst));
        try testing.expect(x.load(.seq_cst) & mask != 0);

        // all the previous bits should have not changed (still be set)
        for (0..bit_index) |prev_bit_index| {
            const prev_bit = @as(std.math.Log2Int(usize), @intCast(prev_bit_index));
            const prev_mask = @as(usize, 1) << prev_bit;
            try testing.expect(x.load(.seq_cst) & prev_mask != 0);
        }
    }
}

test "Value.bitReset" {
    var x = Value(usize).init(0);

    for (0..@bitSizeOf(usize)) |bit_index| {
        const bit = @as(std.math.Log2Int(usize), @intCast(bit_index));
        const mask = @as(usize, 1) << bit;
        x.raw |= mask;

        // unsetting the bit should change the bit
        try testing.expect(x.load(.seq_cst) & mask != 0);
        try testing.expectEqual(@as(u1, 1), x.bitReset(bit, .seq_cst));
        try testing.expect(x.load(.seq_cst) & mask == 0);

        // unsetting it again shouldn't change the bit
        try testing.expectEqual(@as(u1, 0), x.bitReset(bit, .seq_cst));
        try testing.expect(x.load(.seq_cst) & mask == 0);

        // all the previous bits should have not changed (still be reset)
        for (0..bit_index) |prev_bit_index| {
            const prev_bit = @as(std.math.Log2Int(usize), @intCast(prev_bit_index));
            const prev_mask = @as(usize, 1) << prev_bit;
            try testing.expect(x.load(.seq_cst) & prev_mask == 0);
        }
    }
}

test "Value.bitToggle" {
    var x = Value(usize).init(0);

    for (0..@bitSizeOf(usize)) |bit_index| {
        const bit = @as(std.math.Log2Int(usize), @intCast(bit_index));
        const mask = @as(usize, 1) << bit;

        // toggling the bit should change the bit
        try testing.expect(x.load(.seq_cst) & mask == 0);
        try testing.expectEqual(@as(u1, 0), x.bitToggle(bit, .seq_cst));
        try testing.expect(x.load(.seq_cst) & mask != 0);

        // toggling it again *should* change the bit
        try testing.expectEqual(@as(u1, 1), x.bitToggle(bit, .seq_cst));
        try testing.expect(x.load(.seq_cst) & mask == 0);

        // all the previous bits should have not changed (still be toggled back)
        for (0..bit_index) |prev_bit_index| {
            const prev_bit = @as(std.math.Log2Int(usize), @intCast(prev_bit_index));
            const prev_mask = @as(usize, 1) << prev_bit;
            try testing.expect(x.load(.seq_cst) & prev_mask == 0);
        }
    }
}

/// Signals to the processor that the caller is inside a busy-wait spin-loop.
pub inline fn spinLoopHint() void {
    switch (builtin.target.cpu.arch) {
        // No-op instruction that can hint to save (or share with a hardware-thread)
        // pipelining/power resources
        // https://software.intel.com/content/www/us/en/develop/articles/benefitting-power-and-performance-sleep-loops.html
        .x86,
        .x86_64,
        => asm volatile ("pause"),

        // No-op instruction that serves as a hardware-thread resource yield hint.
        // https://stackoverflow.com/a/7588941
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        => asm volatile ("or 27, 27, 27"),

        // `isb` appears more reliable for releasing execution resources than `yield`
        // on common aarch64 CPUs.
        // https://bugs.java.com/bugdatabase/view_bug.do?bug_id=8258604
        // https://bugs.mysql.com/bug.php?id=100664
        .aarch64,
        .aarch64_be,
        => asm volatile ("isb"),

        // `yield` was introduced in v6k but is also available on v6m.
        // https://www.keil.com/support/man/docs/armasm/armasm_dom1361289926796.htm
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        => {
            const can_yield = comptime std.Target.arm.featureSetHasAny(builtin.target.cpu.features, .{
                .has_v6k, .has_v6m,
            });
            if (can_yield) {
                asm volatile ("yield");
            }
        },

        // The 8-bit immediate specifies the amount of cycles to pause for. We can't really be too
        // opinionated here.
        .hexagon,
        => asm volatile ("pause(#1)"),

        .riscv32,
        .riscv64,
        => if (comptime std.Target.riscv.featureSetHas(builtin.target.cpu.features, .zihintpause)) {
            asm volatile ("pause");
        },

        else => {},
    }
}

test spinLoopHint {
    for (0..10) |_| {
        spinLoopHint();
    }
}

/// The estimated size of the CPU's cache line when atomically updating memory.
/// Add this much padding or align to this boundary to avoid atomically-updated
/// memory from forcing cache invalidations on near, but non-atomic, memory.
///
/// https://en.wikipedia.org/wiki/False_sharing
/// https://github.com/golang/go/search?q=CacheLinePadSize
pub const cache_line = switch (builtin.cpu.arch) {
    // x86_64: Starting from Intel's Sandy Bridge, the spatial prefetcher pulls in pairs of 64-byte cache lines at a time.
    // - https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-optimization-manual.pdf
    // - https://github.com/facebook/folly/blob/1b5288e6eea6df074758f877c849b6e73bbb9fbb/folly/lang/Align.h#L107
    //
    // aarch64: Some big.LITTLE ARM archs have "big" cores with 128-byte cache lines:
    // - https://www.mono-project.com/news/2016/09/12/arm64-icache/
    // - https://cpufun.substack.com/p/more-m1-fun-hardware-information
    //
    // - https://github.com/torvalds/linux/blob/3a7e02c040b130b5545e4b115aada7bacd80a2b6/arch/arc/Kconfig#L212
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_ppc64x.go#L9
    .x86_64,
    .aarch64,
    .aarch64_be,
    .arc,
    .powerpc64,
    .powerpc64le,
    => 128,

    // https://github.com/llvm/llvm-project/blob/e379094328e49731a606304f7e3559d4f1fa96f9/clang/lib/Basic/Targets/Hexagon.h#L145-L151
    .hexagon,
    => if (std.Target.hexagon.featureSetHas(builtin.target.cpu.features, .v73)) 64 else 32,

    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_arm.go#L7
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_mips.go#L7
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_mipsle.go#L7
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_mips64x.go#L9
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_riscv64.go#L7
    // - https://github.com/torvalds/linux/blob/3a7e02c040b130b5545e4b115aada7bacd80a2b6/arch/sparc/include/asm/cache.h#L14
    .arm,
    .armeb,
    .thumb,
    .thumbeb,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .riscv32,
    .riscv64,
    .sparc,
    .sparc64,
    => 32,

    // - https://github.com/torvalds/linux/blob/3a7e02c040b130b5545e4b115aada7bacd80a2b6/arch/m68k/include/asm/cache.h#L10
    .m68k,
    => 16,

    // - https://www.ti.com/lit/pdf/slaa498
    .msp430,
    => 8,

    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_s390x.go#L7
    // - https://sxauroratsubasa.sakura.ne.jp/documents/guide/pdfs/Aurora_ISA_guide.pdf
    .s390x,
    .ve,
    => 256,

    // Other x86 and WASM platforms have 64-byte cache lines.
    // The rest of the architectures are assumed to be similar.
    // - https://github.com/golang/go/blob/dda2991c2ea0c5914714469c4defc2562a907230/src/internal/cpu/cpu_x86.go#L9
    // - https://github.com/golang/go/blob/0a9321ad7f8c91e1b0c7184731257df923977eb9/src/internal/cpu/cpu_loong64.go#L11
    // - https://github.com/golang/go/blob/3dd58676054223962cd915bb0934d1f9f489d4d2/src/internal/cpu/cpu_wasm.go#L7
    // - https://github.com/torvalds/linux/blob/3a7e02c040b130b5545e4b115aada7bacd80a2b6/arch/xtensa/variants/csp/include/variant/core.h#L209
    // - https://github.com/torvalds/linux/blob/3a7e02c040b130b5545e4b115aada7bacd80a2b6/arch/csky/Kconfig#L183
    // - https://www.xmos.com/download/The-XMOS-XS3-Architecture.pdf
    else => 64,
};

const std = @import("std.zig");
const builtin = @import("builtin");
const AtomicOrder = std.builtin.AtomicOrder;
const testing = std.testing;
