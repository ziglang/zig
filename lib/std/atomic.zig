/// This is a thin wrapper around a primitive value to prevent accidental data races.
pub fn Value(comptime T: type) type {
    return extern struct {
        /// Care must be taken to avoid data races when interacting with this field directly.
        raw: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .raw = value };
        }

        /// Perform an atomic fence which uses the atomic value as a hint for
        /// the modification order. Use this when you want to imply a fence on
        /// an atomic variable without necessarily performing a memory access.
        pub inline fn fence(self: *Self, comptime order: AtomicOrder) void {
            // LLVM's ThreadSanitizer doesn't support the normal fences so we specialize for it.
            if (builtin.sanitize_thread) {
                const tsan = struct {
                    extern "c" fn __tsan_acquire(addr: *anyopaque) void;
                    extern "c" fn __tsan_release(addr: *anyopaque) void;
                };

                const addr: *anyopaque = self;
                return switch (order) {
                    .Unordered, .Monotonic => @compileError(@tagName(order) ++ " only applies to atomic loads and stores"),
                    .Acquire => tsan.__tsan_acquire(addr),
                    .Release => tsan.__tsan_release(addr),
                    .AcqRel, .SeqCst => {
                        tsan.__tsan_acquire(addr);
                        tsan.__tsan_release(addr);
                    },
                };
            }

            return @fence(order);
        }

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
            // No ordering necessary; just updating a counter.
            _ = rc.count.fetchAdd(1, .Monotonic);
        }

        fn unref(rc: *RefCount) void {
            // Release ensures code before unref() happens-before the
            // count is decremented as dropFn could be called by then.
            if (rc.count.fetchSub(1, .Release) == 1) {
                // Acquire ensures count decrement and code before
                // previous unrefs()s happens-before we call dropFn
                // below.
                // Another alternative is to use .AcqRel on the
                // fetchSub count decrement but it's extra barrier in
                // possibly hot path.
                rc.count.fence(.Acquire);
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
    try testing.expectEqual(@as(usize, 5), x.swap(10, .SeqCst));
    try testing.expectEqual(@as(usize, 10), x.load(.SeqCst));

    const E = enum(usize) { a, b, c };
    var y = Value(E).init(.c);
    try testing.expectEqual(E.c, y.swap(.a, .SeqCst));
    try testing.expectEqual(E.a, y.load(.SeqCst));

    var z = Value(f32).init(5.0);
    try testing.expectEqual(@as(f32, 5.0), z.swap(10.0, .SeqCst));
    try testing.expectEqual(@as(f32, 10.0), z.load(.SeqCst));

    var a = Value(bool).init(false);
    try testing.expectEqual(false, a.swap(true, .SeqCst));
    try testing.expectEqual(true, a.load(.SeqCst));

    var b = Value(?*u8).init(null);
    try testing.expectEqual(@as(?*u8, null), b.swap(@as(?*u8, @ptrFromInt(@alignOf(u8))), .SeqCst));
    try testing.expectEqual(@as(?*u8, @ptrFromInt(@alignOf(u8))), b.load(.SeqCst));
}

test "Value.store" {
    var x = Value(usize).init(5);
    x.store(10, .SeqCst);
    try testing.expectEqual(@as(usize, 10), x.load(.SeqCst));
}

test "Value.cmpxchgWeak" {
    var x = Value(usize).init(0);

    try testing.expectEqual(@as(?usize, 0), x.cmpxchgWeak(1, 0, .SeqCst, .SeqCst));
    try testing.expectEqual(@as(usize, 0), x.load(.SeqCst));

    while (x.cmpxchgWeak(0, 1, .SeqCst, .SeqCst)) |_| {}
    try testing.expectEqual(@as(usize, 1), x.load(.SeqCst));

    while (x.cmpxchgWeak(1, 0, .SeqCst, .SeqCst)) |_| {}
    try testing.expectEqual(@as(usize, 0), x.load(.SeqCst));
}

test "Value.cmpxchgStrong" {
    var x = Value(usize).init(0);
    try testing.expectEqual(@as(?usize, 0), x.cmpxchgStrong(1, 0, .SeqCst, .SeqCst));
    try testing.expectEqual(@as(usize, 0), x.load(.SeqCst));
    try testing.expectEqual(@as(?usize, null), x.cmpxchgStrong(0, 1, .SeqCst, .SeqCst));
    try testing.expectEqual(@as(usize, 1), x.load(.SeqCst));
    try testing.expectEqual(@as(?usize, null), x.cmpxchgStrong(1, 0, .SeqCst, .SeqCst));
    try testing.expectEqual(@as(usize, 0), x.load(.SeqCst));
}

test "Value.fetchAdd" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchAdd(5, .SeqCst));
    try testing.expectEqual(@as(usize, 10), x.load(.SeqCst));
    try testing.expectEqual(@as(usize, 10), x.fetchAdd(std.math.maxInt(usize), .SeqCst));
    try testing.expectEqual(@as(usize, 9), x.load(.SeqCst));
}

test "Value.fetchSub" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchSub(5, .SeqCst));
    try testing.expectEqual(@as(usize, 0), x.load(.SeqCst));
    try testing.expectEqual(@as(usize, 0), x.fetchSub(1, .SeqCst));
    try testing.expectEqual(@as(usize, std.math.maxInt(usize)), x.load(.SeqCst));
}

test "Value.fetchMin" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchMin(0, .SeqCst));
    try testing.expectEqual(@as(usize, 0), x.load(.SeqCst));
    try testing.expectEqual(@as(usize, 0), x.fetchMin(10, .SeqCst));
    try testing.expectEqual(@as(usize, 0), x.load(.SeqCst));
}

test "Value.fetchMax" {
    var x = Value(usize).init(5);
    try testing.expectEqual(@as(usize, 5), x.fetchMax(10, .SeqCst));
    try testing.expectEqual(@as(usize, 10), x.load(.SeqCst));
    try testing.expectEqual(@as(usize, 10), x.fetchMax(5, .SeqCst));
    try testing.expectEqual(@as(usize, 10), x.load(.SeqCst));
}

test "Value.fetchAnd" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchAnd(0b10, .SeqCst));
    try testing.expectEqual(@as(usize, 0b10), x.load(.SeqCst));
    try testing.expectEqual(@as(usize, 0b10), x.fetchAnd(0b00, .SeqCst));
    try testing.expectEqual(@as(usize, 0b00), x.load(.SeqCst));
}

test "Value.fetchNand" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchNand(0b10, .SeqCst));
    try testing.expectEqual(~@as(usize, 0b10), x.load(.SeqCst));
    try testing.expectEqual(~@as(usize, 0b10), x.fetchNand(0b00, .SeqCst));
    try testing.expectEqual(~@as(usize, 0b00), x.load(.SeqCst));
}

test "Value.fetchOr" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchOr(0b100, .SeqCst));
    try testing.expectEqual(@as(usize, 0b111), x.load(.SeqCst));
    try testing.expectEqual(@as(usize, 0b111), x.fetchOr(0b010, .SeqCst));
    try testing.expectEqual(@as(usize, 0b111), x.load(.SeqCst));
}

test "Value.fetchXor" {
    var x = Value(usize).init(0b11);
    try testing.expectEqual(@as(usize, 0b11), x.fetchXor(0b10, .SeqCst));
    try testing.expectEqual(@as(usize, 0b01), x.load(.SeqCst));
    try testing.expectEqual(@as(usize, 0b01), x.fetchXor(0b01, .SeqCst));
    try testing.expectEqual(@as(usize, 0b00), x.load(.SeqCst));
}

test "Value.bitSet" {
    var x = Value(usize).init(0);

    for (0..@bitSizeOf(usize)) |bit_index| {
        const bit = @as(std.math.Log2Int(usize), @intCast(bit_index));
        const mask = @as(usize, 1) << bit;

        // setting the bit should change the bit
        try testing.expect(x.load(.SeqCst) & mask == 0);
        try testing.expectEqual(@as(u1, 0), x.bitSet(bit, .SeqCst));
        try testing.expect(x.load(.SeqCst) & mask != 0);

        // setting it again shouldn't change the bit
        try testing.expectEqual(@as(u1, 1), x.bitSet(bit, .SeqCst));
        try testing.expect(x.load(.SeqCst) & mask != 0);

        // all the previous bits should have not changed (still be set)
        for (0..bit_index) |prev_bit_index| {
            const prev_bit = @as(std.math.Log2Int(usize), @intCast(prev_bit_index));
            const prev_mask = @as(usize, 1) << prev_bit;
            try testing.expect(x.load(.SeqCst) & prev_mask != 0);
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
        try testing.expect(x.load(.SeqCst) & mask != 0);
        try testing.expectEqual(@as(u1, 1), x.bitReset(bit, .SeqCst));
        try testing.expect(x.load(.SeqCst) & mask == 0);

        // unsetting it again shouldn't change the bit
        try testing.expectEqual(@as(u1, 0), x.bitReset(bit, .SeqCst));
        try testing.expect(x.load(.SeqCst) & mask == 0);

        // all the previous bits should have not changed (still be reset)
        for (0..bit_index) |prev_bit_index| {
            const prev_bit = @as(std.math.Log2Int(usize), @intCast(prev_bit_index));
            const prev_mask = @as(usize, 1) << prev_bit;
            try testing.expect(x.load(.SeqCst) & prev_mask == 0);
        }
    }
}

test "Value.bitToggle" {
    var x = Value(usize).init(0);

    for (0..@bitSizeOf(usize)) |bit_index| {
        const bit = @as(std.math.Log2Int(usize), @intCast(bit_index));
        const mask = @as(usize, 1) << bit;

        // toggling the bit should change the bit
        try testing.expect(x.load(.SeqCst) & mask == 0);
        try testing.expectEqual(@as(u1, 0), x.bitToggle(bit, .SeqCst));
        try testing.expect(x.load(.SeqCst) & mask != 0);

        // toggling it again *should* change the bit
        try testing.expectEqual(@as(u1, 1), x.bitToggle(bit, .SeqCst));
        try testing.expect(x.load(.SeqCst) & mask == 0);

        // all the previous bits should have not changed (still be toggled back)
        for (0..bit_index) |prev_bit_index| {
            const prev_bit = @as(std.math.Log2Int(usize), @intCast(prev_bit_index));
            const prev_mask = @as(usize, 1) << prev_bit;
            try testing.expect(x.load(.SeqCst) & prev_mask == 0);
        }
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

const std = @import("std.zig");
const builtin = @import("builtin");
const AtomicOrder = std.builtin.AtomicOrder;
const testing = std.testing;
