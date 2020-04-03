const std = @import("std");
const builtin = std.builtin;

const linkage: builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;

const cache_line_size = 64;

const SpinlockTable = struct {
    // Allocate ~4096 bytes of memory for the spinlock table
    const max_spinlocks = 64;

    const Spinlock = struct {
        // Prevent false sharing by providing enough padding between two
        // consecutive spinlock elements
        v: enum(usize) { Unlocked = 0, Locked } align(cache_line_size) = .Unlocked,

        fn acquire(self: *@This()) void {
            while (true) {
                switch (@atomicRmw(@TypeOf(self.v), &self.v, .Xchg, .Locked, .Acquire)) {
                    .Unlocked => break,
                    .Locked => {},
                }
            }
        }
        fn release(self: *@This()) void {
            @atomicStore(@TypeOf(self.v), &self.v, .Unlocked, .Release);
        }
    };

    list: [max_spinlocks]Spinlock = [_]Spinlock{.{}} ** max_spinlocks,

    // The spinlock table behaves as a really simple hash table, mapping
    // addresses to spinlocks. The mapping is not unique but that's only a
    // performance problem as the lock will be contended by more than a pair of
    // threads.
    fn get(self: *@This(), address: usize) *Spinlock {
        var sl = &self.list[(address >> 3) % max_spinlocks];
        sl.acquire();
        return sl;
    }
};

var spinlocks: SpinlockTable = SpinlockTable{};

// The following builtins do not respect the specified memory model and instead
// uses seq_cst, the strongest one, for simplicity sake.

// Generic version of GCC atomic builtin functions.
// Those work on any object no matter the pointer alignment nor its size.

fn __atomic_load(size: u32, src: [*]u8, dest: [*]u8, model: i32) callconv(.C) void {
    var sl = spinlocks.get(@ptrToInt(src));
    defer sl.release();
    @memcpy(dest, src, size);
}

fn __atomic_store(size: u32, dest: [*]u8, src: [*]u8, model: i32) callconv(.C) void {
    var sl = spinlocks.get(@ptrToInt(dest));
    defer sl.release();
    @memcpy(dest, src, size);
}

fn __atomic_exchange(size: u32, ptr: [*]u8, val: [*]u8, old: [*]u8, model: i32) callconv(.C) void {
    var sl = spinlocks.get(@ptrToInt(ptr));
    defer sl.release();
    @memcpy(old, ptr, size);
    @memcpy(ptr, val, size);
}

fn __atomic_compare_exchange(
    size: u32,
    ptr: [*]u8,
    expected: [*]u8,
    desired: [*]u8,
    success: i32,
    failure: i32,
) callconv(.C) i32 {
    var sl = spinlocks.get(@ptrToInt(ptr));
    defer sl.release();
    for (ptr[0..size]) |b, i| {
        if (expected[i] != b) break;
    } else {
        // The two objects, ptr and expected, are equal
        @memcpy(ptr, desired, size);
        return 1;
    }
    @memcpy(expected, ptr, size);
    return 0;
}

comptime {
    @export(__atomic_load, .{ .name = "__atomic_load", .linkage = linkage });
    @export(__atomic_store, .{ .name = "__atomic_store", .linkage = linkage });
    @export(__atomic_exchange, .{ .name = "__atomic_exchange", .linkage = linkage });
    @export(__atomic_compare_exchange, .{ .name = "__atomic_compare_exchange", .linkage = linkage });
}

// Specialized versions of the GCC atomic builtin functions.
// LLVM emits those iff the object size is known and the pointers are correctly
// aligned.

// The size (in bytes) of the biggest object that the architecture can access
// atomically. Objects bigger than this threshold require the use of a lock.
const largest_atomic_size = switch (builtin.arch) {
    .x86_64 => 16,
    else => @sizeOf(usize),
};

fn makeAtomicLoadFn(comptime T: type) type {
    return struct {
        fn atomic_load_N(src: *T, model: i32) callconv(.C) T {
            if (@sizeOf(T) > largest_atomic_size) {
                var sl = spinlocks.get(@ptrToInt(src));
                defer sl.release();
                return src.*;
            } else {
                return @atomicLoad(T, src, .SeqCst);
            }
        }
    };
}

comptime {
    @export(makeAtomicLoadFn(u8).atomic_load_N, .{ .name = "__atomic_load_1", .linkage = linkage });
    @export(makeAtomicLoadFn(u16).atomic_load_N, .{ .name = "__atomic_load_2", .linkage = linkage });
    @export(makeAtomicLoadFn(u32).atomic_load_N, .{ .name = "__atomic_load_4", .linkage = linkage });
    @export(makeAtomicLoadFn(u64).atomic_load_N, .{ .name = "__atomic_load_8", .linkage = linkage });
}

fn makeAtomicStoreFn(comptime T: type) type {
    return struct {
        fn atomic_store_N(dst: *T, value: T, model: i32) callconv(.C) void {
            if (@sizeOf(T) > largest_atomic_size) {
                var sl = spinlocks.get(@ptrToInt(dst));
                defer sl.release();
                dst.* = value;
            } else {
                @atomicStore(T, dst, value, .SeqCst);
            }
        }
    };
}

comptime {
    @export(makeAtomicStoreFn(u8).atomic_store_N, .{ .name = "__atomic_store_1", .linkage = linkage });
    @export(makeAtomicStoreFn(u16).atomic_store_N, .{ .name = "__atomic_store_2", .linkage = linkage });
    @export(makeAtomicStoreFn(u32).atomic_store_N, .{ .name = "__atomic_store_4", .linkage = linkage });
    @export(makeAtomicStoreFn(u64).atomic_store_N, .{ .name = "__atomic_store_8", .linkage = linkage });
}

fn makeAtomicExchangeFn(comptime T: type) type {
    return struct {
        fn atomic_exchange_N(ptr: *T, val: T, model: i32) callconv(.C) T {
            if (@sizeOf(T) > largest_atomic_size) {
                var sl = spinlocks.get(@ptrToInt(ptr));
                defer sl.release();
                var value = ptr.*;
                ptr.* = val;
                return value;
            } else {
                return @atomicRmw(T, ptr, .Xchg, val, .SeqCst);
            }
        }
    };
}

comptime {
    @export(makeAtomicExchangeFn(u8).atomic_exchange_N, .{ .name = "__atomic_exchange_1", .linkage = linkage });
    @export(makeAtomicExchangeFn(u16).atomic_exchange_N, .{ .name = "__atomic_exchange_2", .linkage = linkage });
    @export(makeAtomicExchangeFn(u32).atomic_exchange_N, .{ .name = "__atomic_exchange_4", .linkage = linkage });
    @export(makeAtomicExchangeFn(u64).atomic_exchange_N, .{ .name = "__atomic_exchange_8", .linkage = linkage });
}

fn makeAtomicCompareExchangeFn(comptime T: type) type {
    return struct {
        fn atomic_compare_exchange_N(ptr: *T, expected: *T, desired: T, success: i32, failure: i32) callconv(.C) i32 {
            if (@sizeOf(T) > largest_atomic_size) {
                var sl = spinlocks.get(@ptrToInt(ptr));
                defer sl.release();
                if (ptr.* == expected.*) {
                    ptr.* = desired;
                    return 1;
                }
                expected.* = ptr.*;
                return 0;
            } else {
                if (@cmpxchgStrong(T, ptr, expected.*, desired, .SeqCst, .SeqCst)) |old_value| {
                    expected.* = old_value;
                    return 0;
                }
                return 1;
            }
        }
    };
}

comptime {
    @export(makeAtomicCompareExchangeFn(u8).atomic_compare_exchange_N, .{ .name = "__atomic_compare_exchange_1", .linkage = linkage });
    @export(makeAtomicCompareExchangeFn(u16).atomic_compare_exchange_N, .{ .name = "__atomic_compare_exchange_2", .linkage = linkage });
    @export(makeAtomicCompareExchangeFn(u32).atomic_compare_exchange_N, .{ .name = "__atomic_compare_exchange_4", .linkage = linkage });
    @export(makeAtomicCompareExchangeFn(u64).atomic_compare_exchange_N, .{ .name = "__atomic_compare_exchange_8", .linkage = linkage });
}

fn makeFetchFn(comptime T: type, comptime op: builtin.AtomicRmwOp) type {
    return struct {
        pub fn fetch_op_N(ptr: *T, val: T, model: i32) callconv(.C) T {
            if (@sizeOf(T) > largest_atomic_size) {
                var sl = spinlocks.get(@ptrToInt(ptr));
                defer sl.release();

                var value = ptr.*;
                ptr.* = switch (op) {
                    .Add => ptr.* +% val,
                    .Sub => ptr.* -% val,
                    .And => ptr.* & val,
                    .Nand => ~(ptr.* & val),
                    .Or => ptr.* | val,
                    .Xor => ptr.* ^ val,
                    else => @compileError("unsupported atomic op"),
                };

                return value;
            }

            return @atomicRmw(T, ptr, op, val, .SeqCst);
        }
    };
}

comptime {
    @export(makeFetchFn(u8, .Add).fetch_op_N, .{ .name = "__atomic_fetch_add_1", .linkage = linkage });
    @export(makeFetchFn(u16, .Add).fetch_op_N, .{ .name = "__atomic_fetch_add_2", .linkage = linkage });
    @export(makeFetchFn(u32, .Add).fetch_op_N, .{ .name = "__atomic_fetch_add_4", .linkage = linkage });
    @export(makeFetchFn(u64, .Add).fetch_op_N, .{ .name = "__atomic_fetch_add_8", .linkage = linkage });

    @export(makeFetchFn(u8, .Sub).fetch_op_N, .{ .name = "__atomic_fetch_sub_1", .linkage = linkage });
    @export(makeFetchFn(u16, .Sub).fetch_op_N, .{ .name = "__atomic_fetch_sub_2", .linkage = linkage });
    @export(makeFetchFn(u32, .Sub).fetch_op_N, .{ .name = "__atomic_fetch_sub_4", .linkage = linkage });
    @export(makeFetchFn(u64, .Sub).fetch_op_N, .{ .name = "__atomic_fetch_sub_8", .linkage = linkage });

    @export(makeFetchFn(u8, .And).fetch_op_N, .{ .name = "__atomic_fetch_and_1", .linkage = linkage });
    @export(makeFetchFn(u16, .And).fetch_op_N, .{ .name = "__atomic_fetch_and_2", .linkage = linkage });
    @export(makeFetchFn(u32, .And).fetch_op_N, .{ .name = "__atomic_fetch_and_4", .linkage = linkage });
    @export(makeFetchFn(u64, .And).fetch_op_N, .{ .name = "__atomic_fetch_and_8", .linkage = linkage });

    @export(makeFetchFn(u8, .Or).fetch_op_N, .{ .name = "__atomic_fetch_or_1", .linkage = linkage });
    @export(makeFetchFn(u16, .Or).fetch_op_N, .{ .name = "__atomic_fetch_or_2", .linkage = linkage });
    @export(makeFetchFn(u32, .Or).fetch_op_N, .{ .name = "__atomic_fetch_or_4", .linkage = linkage });
    @export(makeFetchFn(u64, .Or).fetch_op_N, .{ .name = "__atomic_fetch_or_8", .linkage = linkage });

    @export(makeFetchFn(u8, .Xor).fetch_op_N, .{ .name = "__atomic_fetch_xor_1", .linkage = linkage });
    @export(makeFetchFn(u16, .Xor).fetch_op_N, .{ .name = "__atomic_fetch_xor_2", .linkage = linkage });
    @export(makeFetchFn(u32, .Xor).fetch_op_N, .{ .name = "__atomic_fetch_xor_4", .linkage = linkage });
    @export(makeFetchFn(u64, .Xor).fetch_op_N, .{ .name = "__atomic_fetch_xor_8", .linkage = linkage });

    @export(makeFetchFn(u8, .Nand).fetch_op_N, .{ .name = "__atomic_fetch_nand_1", .linkage = linkage });
    @export(makeFetchFn(u16, .Nand).fetch_op_N, .{ .name = "__atomic_fetch_nand_2", .linkage = linkage });
    @export(makeFetchFn(u32, .Nand).fetch_op_N, .{ .name = "__atomic_fetch_nand_4", .linkage = linkage });
    @export(makeFetchFn(u64, .Nand).fetch_op_N, .{ .name = "__atomic_fetch_nand_8", .linkage = linkage });
}
