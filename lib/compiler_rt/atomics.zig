const std = @import("std");
const builtin = @import("builtin");
const cpu = builtin.cpu;
const arch = cpu.arch;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

// This parameter is true iff the target architecture supports the bare minimum
// to implement the atomic load/store intrinsics.
// Some architectures support atomic load/stores but no CAS, but we ignore this
// detail to keep the export logic clean and because we need some kind of CAS to
// implement the spinlocks.
const supports_atomic_ops = switch (arch) {
    .msp430, .avr, .bpfel, .bpfeb => false,
    .arm, .armeb, .thumb, .thumbeb =>
    // The ARM v6m ISA has no ldrex/strex and so it's impossible to do CAS
    // operations (unless we're targeting Linux, the kernel provides a way to
    // perform CAS operations).
    // XXX: The Linux code path is not implemented yet.
    !std.Target.arm.featureSetHas(builtin.cpu.features, .has_v6m),
    else => true,
};

// The size (in bytes) of the biggest object that the architecture can
// load/store atomically.
// Objects bigger than this threshold require the use of a lock.
const largest_atomic_size = switch (arch) {
    // On SPARC systems that lacks CAS and/or swap instructions, the only
    // available atomic operation is a test-and-set (`ldstub`), so we force
    // every atomic memory access to go through the lock.
    .sparc, .sparcel => if (cpu.features.featureSetHas(.hasleoncasa)) @sizeOf(usize) else 0,

    // XXX: On x86/x86_64 we could check the presence of cmpxchg8b/cmpxchg16b
    // and set this parameter accordingly.
    else => @sizeOf(usize),
};

const cache_line_size = 64;

const SpinlockTable = struct {
    // Allocate ~4096 bytes of memory for the spinlock table
    const max_spinlocks = 64;

    const Spinlock = struct {
        // SPARC ldstub instruction will write a 255 into the memory location.
        // We'll use that as a sign that the lock is currently held.
        // See also: Section B.7 in SPARCv8 spec & A.29 in SPARCv9 spec.
        const sparc_lock: type = enum(u8) { Unlocked = 0, Locked = 255 };
        const other_lock: type = enum(usize) { Unlocked = 0, Locked };

        // Prevent false sharing by providing enough padding between two
        // consecutive spinlock elements
        v: if (arch.isSPARC()) sparc_lock else other_lock align(cache_line_size) = .Unlocked,

        fn acquire(self: *@This()) void {
            while (true) {
                const flag = if (comptime arch.isSPARC()) flag: {
                    break :flag asm volatile ("ldstub [%[addr]], %[flag]"
                        : [flag] "=r" (-> @TypeOf(self.v)),
                        : [addr] "r" (&self.v),
                        : "memory"
                    );
                } else flag: {
                    break :flag @atomicRmw(@TypeOf(self.v), &self.v, .Xchg, .Locked, .Acquire);
                };

                switch (flag) {
                    .Unlocked => break,
                    .Locked => {},
                }
            }
        }
        fn release(self: *@This()) void {
            if (comptime arch.isSPARC()) {
                _ = asm volatile ("clrb [%[addr]]"
                    :
                    : [addr] "r" (&self.v),
                    : "memory"
                );
            } else {
                @atomicStore(@TypeOf(self.v), &self.v, .Unlocked, .Release);
            }
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
    _ = model;
    var sl = spinlocks.get(@ptrToInt(src));
    defer sl.release();
    @memcpy(dest, src, size);
}

fn __atomic_store(size: u32, dest: [*]u8, src: [*]u8, model: i32) callconv(.C) void {
    _ = model;
    var sl = spinlocks.get(@ptrToInt(dest));
    defer sl.release();
    @memcpy(dest, src, size);
}

fn __atomic_exchange(size: u32, ptr: [*]u8, val: [*]u8, old: [*]u8, model: i32) callconv(.C) void {
    _ = model;
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
    _ = success;
    _ = failure;
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

// Specialized versions of the GCC atomic builtin functions.
// LLVM emits those iff the object size is known and the pointers are correctly
// aligned.
inline fn atomic_load_N(comptime T: type, src: *T, model: i32) T {
    _ = model;
    if (@sizeOf(T) > largest_atomic_size) {
        var sl = spinlocks.get(@ptrToInt(src));
        defer sl.release();
        return src.*;
    } else {
        return @atomicLoad(T, src, .SeqCst);
    }
}

fn __atomic_load_1(src: *u8, model: i32) callconv(.C) u8 {
    return atomic_load_N(u8, src, model);
}

fn __atomic_load_2(src: *u16, model: i32) callconv(.C) u16 {
    return atomic_load_N(u16, src, model);
}

fn __atomic_load_4(src: *u32, model: i32) callconv(.C) u32 {
    return atomic_load_N(u32, src, model);
}

fn __atomic_load_8(src: *u64, model: i32) callconv(.C) u64 {
    return atomic_load_N(u64, src, model);
}

inline fn atomic_store_N(comptime T: type, dst: *T, value: T, model: i32) void {
    _ = model;
    if (@sizeOf(T) > largest_atomic_size) {
        var sl = spinlocks.get(@ptrToInt(dst));
        defer sl.release();
        dst.* = value;
    } else {
        @atomicStore(T, dst, value, .SeqCst);
    }
}

fn __atomic_store_1(dst: *u8, value: u8, model: i32) callconv(.C) void {
    return atomic_store_N(u8, dst, value, model);
}

fn __atomic_store_2(dst: *u16, value: u16, model: i32) callconv(.C) void {
    return atomic_store_N(u16, dst, value, model);
}

fn __atomic_store_4(dst: *u32, value: u32, model: i32) callconv(.C) void {
    return atomic_store_N(u32, dst, value, model);
}

fn __atomic_store_8(dst: *u64, value: u64, model: i32) callconv(.C) void {
    return atomic_store_N(u64, dst, value, model);
}

inline fn atomic_exchange_N(comptime T: type, ptr: *T, val: T, model: i32) T {
    _ = model;
    if (@sizeOf(T) > largest_atomic_size) {
        var sl = spinlocks.get(@ptrToInt(ptr));
        defer sl.release();
        const value = ptr.*;
        ptr.* = val;
        return value;
    } else {
        return @atomicRmw(T, ptr, .Xchg, val, .SeqCst);
    }
}

fn __atomic_exchange_1(ptr: *u8, val: u8, model: i32) callconv(.C) u8 {
    return atomic_exchange_N(u8, ptr, val, model);
}

fn __atomic_exchange_2(ptr: *u16, val: u16, model: i32) callconv(.C) u16 {
    return atomic_exchange_N(u16, ptr, val, model);
}

fn __atomic_exchange_4(ptr: *u32, val: u32, model: i32) callconv(.C) u32 {
    return atomic_exchange_N(u32, ptr, val, model);
}

fn __atomic_exchange_8(ptr: *u64, val: u64, model: i32) callconv(.C) u64 {
    return atomic_exchange_N(u64, ptr, val, model);
}

inline fn atomic_compare_exchange_N(
    comptime T: type,
    ptr: *T,
    expected: *T,
    desired: T,
    success: i32,
    failure: i32,
) i32 {
    _ = success;
    _ = failure;
    if (@sizeOf(T) > largest_atomic_size) {
        var sl = spinlocks.get(@ptrToInt(ptr));
        defer sl.release();
        const value = ptr.*;
        if (value == expected.*) {
            ptr.* = desired;
            return 1;
        }
        expected.* = value;
        return 0;
    } else {
        if (@cmpxchgStrong(T, ptr, expected.*, desired, .SeqCst, .SeqCst)) |old_value| {
            expected.* = old_value;
            return 0;
        }
        return 1;
    }
}

fn __atomic_compare_exchange_1(ptr: *u8, expected: *u8, desired: u8, success: i32, failure: i32) callconv(.C) i32 {
    return atomic_compare_exchange_N(u8, ptr, expected, desired, success, failure);
}

fn __atomic_compare_exchange_2(ptr: *u16, expected: *u16, desired: u16, success: i32, failure: i32) callconv(.C) i32 {
    return atomic_compare_exchange_N(u16, ptr, expected, desired, success, failure);
}

fn __atomic_compare_exchange_4(ptr: *u32, expected: *u32, desired: u32, success: i32, failure: i32) callconv(.C) i32 {
    return atomic_compare_exchange_N(u32, ptr, expected, desired, success, failure);
}

fn __atomic_compare_exchange_8(ptr: *u64, expected: *u64, desired: u64, success: i32, failure: i32) callconv(.C) i32 {
    return atomic_compare_exchange_N(u64, ptr, expected, desired, success, failure);
}

inline fn fetch_op_N(comptime T: type, comptime op: std.builtin.AtomicRmwOp, ptr: *T, val: T, model: i32) T {
    _ = model;
    if (@sizeOf(T) > largest_atomic_size) {
        var sl = spinlocks.get(@ptrToInt(ptr));
        defer sl.release();

        const value = ptr.*;
        ptr.* = switch (op) {
            .Add => value +% val,
            .Sub => value -% val,
            .And => value & val,
            .Nand => ~(value & val),
            .Or => value | val,
            .Xor => value ^ val,
            else => @compileError("unsupported atomic op"),
        };

        return value;
    }

    return @atomicRmw(T, ptr, op, val, .SeqCst);
}

fn __atomic_fetch_add_1(ptr: *u8, val: u8, model: i32) callconv(.C) u8 {
    return fetch_op_N(u8, .Add, ptr, val, model);
}

fn __atomic_fetch_add_2(ptr: *u16, val: u16, model: i32) callconv(.C) u16 {
    return fetch_op_N(u16, .Add, ptr, val, model);
}

fn __atomic_fetch_add_4(ptr: *u32, val: u32, model: i32) callconv(.C) u32 {
    return fetch_op_N(u32, .Add, ptr, val, model);
}

fn __atomic_fetch_add_8(ptr: *u64, val: u64, model: i32) callconv(.C) u64 {
    return fetch_op_N(u64, .Add, ptr, val, model);
}

fn __atomic_fetch_sub_1(ptr: *u8, val: u8, model: i32) callconv(.C) u8 {
    return fetch_op_N(u8, .Sub, ptr, val, model);
}

fn __atomic_fetch_sub_2(ptr: *u16, val: u16, model: i32) callconv(.C) u16 {
    return fetch_op_N(u16, .Sub, ptr, val, model);
}

fn __atomic_fetch_sub_4(ptr: *u32, val: u32, model: i32) callconv(.C) u32 {
    return fetch_op_N(u32, .Sub, ptr, val, model);
}

fn __atomic_fetch_sub_8(ptr: *u64, val: u64, model: i32) callconv(.C) u64 {
    return fetch_op_N(u64, .Sub, ptr, val, model);
}

fn __atomic_fetch_and_1(ptr: *u8, val: u8, model: i32) callconv(.C) u8 {
    return fetch_op_N(u8, .And, ptr, val, model);
}

fn __atomic_fetch_and_2(ptr: *u16, val: u16, model: i32) callconv(.C) u16 {
    return fetch_op_N(u16, .And, ptr, val, model);
}

fn __atomic_fetch_and_4(ptr: *u32, val: u32, model: i32) callconv(.C) u32 {
    return fetch_op_N(u32, .And, ptr, val, model);
}

fn __atomic_fetch_and_8(ptr: *u64, val: u64, model: i32) callconv(.C) u64 {
    return fetch_op_N(u64, .And, ptr, val, model);
}

fn __atomic_fetch_or_1(ptr: *u8, val: u8, model: i32) callconv(.C) u8 {
    return fetch_op_N(u8, .Or, ptr, val, model);
}

fn __atomic_fetch_or_2(ptr: *u16, val: u16, model: i32) callconv(.C) u16 {
    return fetch_op_N(u16, .Or, ptr, val, model);
}

fn __atomic_fetch_or_4(ptr: *u32, val: u32, model: i32) callconv(.C) u32 {
    return fetch_op_N(u32, .Or, ptr, val, model);
}

fn __atomic_fetch_or_8(ptr: *u64, val: u64, model: i32) callconv(.C) u64 {
    return fetch_op_N(u64, .Or, ptr, val, model);
}

fn __atomic_fetch_xor_1(ptr: *u8, val: u8, model: i32) callconv(.C) u8 {
    return fetch_op_N(u8, .Xor, ptr, val, model);
}

fn __atomic_fetch_xor_2(ptr: *u16, val: u16, model: i32) callconv(.C) u16 {
    return fetch_op_N(u16, .Xor, ptr, val, model);
}

fn __atomic_fetch_xor_4(ptr: *u32, val: u32, model: i32) callconv(.C) u32 {
    return fetch_op_N(u32, .Xor, ptr, val, model);
}

fn __atomic_fetch_xor_8(ptr: *u64, val: u64, model: i32) callconv(.C) u64 {
    return fetch_op_N(u64, .Xor, ptr, val, model);
}

fn __atomic_fetch_nand_1(ptr: *u8, val: u8, model: i32) callconv(.C) u8 {
    return fetch_op_N(u8, .Nand, ptr, val, model);
}

fn __atomic_fetch_nand_2(ptr: *u16, val: u16, model: i32) callconv(.C) u16 {
    return fetch_op_N(u16, .Nand, ptr, val, model);
}

fn __atomic_fetch_nand_4(ptr: *u32, val: u32, model: i32) callconv(.C) u32 {
    return fetch_op_N(u32, .Nand, ptr, val, model);
}

fn __atomic_fetch_nand_8(ptr: *u64, val: u64, model: i32) callconv(.C) u64 {
    return fetch_op_N(u64, .Nand, ptr, val, model);
}

comptime {
    if (supports_atomic_ops) {
        @export(__atomic_load, .{ .name = "__atomic_load", .linkage = linkage });
        @export(__atomic_store, .{ .name = "__atomic_store", .linkage = linkage });
        @export(__atomic_exchange, .{ .name = "__atomic_exchange", .linkage = linkage });
        @export(__atomic_compare_exchange, .{ .name = "__atomic_compare_exchange", .linkage = linkage });

        @export(__atomic_fetch_add_1, .{ .name = "__atomic_fetch_add_1", .linkage = linkage });
        @export(__atomic_fetch_add_2, .{ .name = "__atomic_fetch_add_2", .linkage = linkage });
        @export(__atomic_fetch_add_4, .{ .name = "__atomic_fetch_add_4", .linkage = linkage });
        @export(__atomic_fetch_add_8, .{ .name = "__atomic_fetch_add_8", .linkage = linkage });

        @export(__atomic_fetch_sub_1, .{ .name = "__atomic_fetch_sub_1", .linkage = linkage });
        @export(__atomic_fetch_sub_2, .{ .name = "__atomic_fetch_sub_2", .linkage = linkage });
        @export(__atomic_fetch_sub_4, .{ .name = "__atomic_fetch_sub_4", .linkage = linkage });
        @export(__atomic_fetch_sub_8, .{ .name = "__atomic_fetch_sub_8", .linkage = linkage });

        @export(__atomic_fetch_and_1, .{ .name = "__atomic_fetch_and_1", .linkage = linkage });
        @export(__atomic_fetch_and_2, .{ .name = "__atomic_fetch_and_2", .linkage = linkage });
        @export(__atomic_fetch_and_4, .{ .name = "__atomic_fetch_and_4", .linkage = linkage });
        @export(__atomic_fetch_and_8, .{ .name = "__atomic_fetch_and_8", .linkage = linkage });

        @export(__atomic_fetch_or_1, .{ .name = "__atomic_fetch_or_1", .linkage = linkage });
        @export(__atomic_fetch_or_2, .{ .name = "__atomic_fetch_or_2", .linkage = linkage });
        @export(__atomic_fetch_or_4, .{ .name = "__atomic_fetch_or_4", .linkage = linkage });
        @export(__atomic_fetch_or_8, .{ .name = "__atomic_fetch_or_8", .linkage = linkage });

        @export(__atomic_fetch_xor_1, .{ .name = "__atomic_fetch_xor_1", .linkage = linkage });
        @export(__atomic_fetch_xor_2, .{ .name = "__atomic_fetch_xor_2", .linkage = linkage });
        @export(__atomic_fetch_xor_4, .{ .name = "__atomic_fetch_xor_4", .linkage = linkage });
        @export(__atomic_fetch_xor_8, .{ .name = "__atomic_fetch_xor_8", .linkage = linkage });

        @export(__atomic_fetch_nand_1, .{ .name = "__atomic_fetch_nand_1", .linkage = linkage });
        @export(__atomic_fetch_nand_2, .{ .name = "__atomic_fetch_nand_2", .linkage = linkage });
        @export(__atomic_fetch_nand_4, .{ .name = "__atomic_fetch_nand_4", .linkage = linkage });
        @export(__atomic_fetch_nand_8, .{ .name = "__atomic_fetch_nand_8", .linkage = linkage });

        @export(__atomic_load_1, .{ .name = "__atomic_load_1", .linkage = linkage });
        @export(__atomic_load_2, .{ .name = "__atomic_load_2", .linkage = linkage });
        @export(__atomic_load_4, .{ .name = "__atomic_load_4", .linkage = linkage });
        @export(__atomic_load_8, .{ .name = "__atomic_load_8", .linkage = linkage });

        @export(__atomic_store_1, .{ .name = "__atomic_store_1", .linkage = linkage });
        @export(__atomic_store_2, .{ .name = "__atomic_store_2", .linkage = linkage });
        @export(__atomic_store_4, .{ .name = "__atomic_store_4", .linkage = linkage });
        @export(__atomic_store_8, .{ .name = "__atomic_store_8", .linkage = linkage });

        @export(__atomic_exchange_1, .{ .name = "__atomic_exchange_1", .linkage = linkage });
        @export(__atomic_exchange_2, .{ .name = "__atomic_exchange_2", .linkage = linkage });
        @export(__atomic_exchange_4, .{ .name = "__atomic_exchange_4", .linkage = linkage });
        @export(__atomic_exchange_8, .{ .name = "__atomic_exchange_8", .linkage = linkage });

        @export(__atomic_compare_exchange_1, .{ .name = "__atomic_compare_exchange_1", .linkage = linkage });
        @export(__atomic_compare_exchange_2, .{ .name = "__atomic_compare_exchange_2", .linkage = linkage });
        @export(__atomic_compare_exchange_4, .{ .name = "__atomic_compare_exchange_4", .linkage = linkage });
        @export(__atomic_compare_exchange_8, .{ .name = "__atomic_compare_exchange_8", .linkage = linkage });
    }
}
