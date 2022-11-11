//! This is intended to be merged into GeneralPurposeAllocator at some point.

const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const assert = std.debug.assert;
const wasm = std.wasm;
const math = std.math;

comptime {
    if (!builtin.target.isWasm()) {
        @compileError("WasmPageAllocator is only available for wasm32 arch");
    }
}

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

pub const Error = Allocator.Error;

const max_usize = math.maxInt(usize);
const bigpage_size = 512 * 1024;
const pages_per_bigpage = bigpage_size / wasm.page_size;
const bigpage_count = max_usize / bigpage_size;

//// This has a length of 1024 usizes.
//var bigpages_used = [1]usize{0} ** (bigpage_count / @bitSizeOf(usize));

/// We have a small size class for all sizes up to 512kb.
const size_class_count = math.log2(bigpage_size);

const FreeList = struct {
    /// Each element is the address of a freed pointer.
    ptr: [*]usize,
    len: usize,
    cap: usize,

    const init: FreeList = .{
        .ptr = undefined,
        .len = 0,
        .cap = 0,
    };
};

var next_addrs = [1]usize{0} ** size_class_count;
var frees = [1]FreeList{FreeList.init} ** size_class_count;
var bigpage_free_list: FreeList = .{
    .ptr = &bigpage_free_buf,
    .len = 0,
    .cap = bigpage_free_buf.len,
};
var bigpage_free_buf: [16]usize = undefined;

fn alloc(ctx: *anyopaque, len: usize, alignment: u29, len_align: u29, ra: usize) Error![]u8 {
    _ = ctx;
    _ = len_align;
    _ = ra;
    const slot_size = math.ceilPowerOfTwoAssert(usize, @max(len, alignment));
    const class = math.log2(slot_size);
    if (class < size_class_count) {
        const addr = a: {
            const free_list = &frees[class];
            if (free_list.len > 0) {
                free_list.len -= 1;
                break :a free_list.ptr[free_list.len];
            }

            // Ensure unused capacity in the corresponding free list.
            // This prevents memory allocation within free().
            if (free_list.len >= free_list.cap) {
                const old_bigpage_count = free_list.cap / bigpage_size;
                if (bigpage_free_list.cap - bigpage_free_list.len < old_bigpage_count) {
                    return error.OutOfMemory;
                }
                const new_bigpage_count = old_bigpage_count + 1;
                const addr = try allocBigPages(new_bigpage_count);
                const new_ptr = @intToPtr([*]usize, addr);
                const old_ptr = free_list.ptr;
                @memcpy(
                    @ptrCast([*]u8, new_ptr),
                    @ptrCast([*]u8, old_ptr),
                    @sizeOf(usize) * free_list.len,
                );
                free_list.ptr = new_ptr;
                free_list.cap = new_bigpage_count * (bigpage_size / @sizeOf(usize));

                var i: usize = 0;
                while (i < old_bigpage_count) : (i += 1) {
                    bigpage_free_list.ptr[bigpage_free_list.len] = @ptrToInt(old_ptr) +
                        i * bigpage_size;
                    bigpage_free_list.len += 1;
                }
            }

            const next_addr = next_addrs[class];
            if (next_addr % bigpage_size == 0) {
                //std.debug.print("alloc big page len={d} class={d} slot_size={d}\n", .{
                //    len, class, slot_size,
                //});
                const addr = try allocBigPages(1);
                next_addrs[class] = addr + slot_size;
                break :a addr;
            } else {
                //std.debug.print("easy! len={d} class={d} slot_size={d}\n", .{
                //    len, class, slot_size,
                //});
                next_addrs[class] = next_addr + slot_size;
                break :a next_addr;
            }
        };
        return @intToPtr([*]u8, addr)[0..len];
    } else {
        std.debug.panic("big alloc: len={d} align={d} slot_size={d} class={d}", .{
            len, alignment, slot_size, class,
        });
    }
}

fn resize(
    ctx: *anyopaque,
    buf: []u8,
    buf_align: u29,
    new_len: usize,
    len_align: u29,
    return_address: usize,
) ?usize {
    _ = ctx;
    _ = buf_align;
    _ = return_address;
    _ = len_align;
    _ = new_len;
    _ = buf;
    @panic("handle resize");
}

fn free(
    ctx: *anyopaque,
    buf: []u8,
    buf_align: u29,
    return_address: usize,
) void {
    _ = ctx;
    _ = return_address;
    const class_size = @max(buf.len, buf_align);
    const class = math.log2(class_size);
    if (class < size_class_count) {
        const free_list = &frees[class];
        assert(free_list.len < free_list.cap);
        free_list.ptr[free_list.len] = @ptrToInt(buf.ptr);
        free_list.len += 1;
    } else {
        std.debug.panic("big free: len={d} align={d}", .{
            buf.len, buf_align,
        });
    }
}

inline fn allocBigPages(n: usize) !usize {
    if (n == 1 and bigpage_free_list.len > 0) {
        bigpage_free_list.len -= 1;
        return bigpage_free_list.ptr[bigpage_free_list.len];
    }
    const page_index = @wasmMemoryGrow(0, n * pages_per_bigpage);
    if (page_index <= 0)
        return error.OutOfMemory;
    return @intCast(u32, page_index) * wasm.page_size;
}

const test_ally = Allocator{
    .ptr = undefined,
    .vtable = &vtable,
};

test "small allocations - free in same order" {
    var list: [513]*u64 = undefined;

    var i: usize = 0;
    while (i < 513) : (i += 1) {
        const ptr = try test_ally.create(u64);
        list[i] = ptr;
    }

    for (list) |ptr| {
        test_ally.destroy(ptr);
    }
}

test "small allocations - free in reverse order" {
    var list: [513]*u64 = undefined;

    var i: usize = 0;
    while (i < 513) : (i += 1) {
        const ptr = try test_ally.create(u64);
        list[i] = ptr;
    }

    i = list.len;
    while (i > 0) {
        i -= 1;
        const ptr = list[i];
        test_ally.destroy(ptr);
    }
}

test "large allocations" {
    std.debug.print("alloc ptr1\n", .{});
    const ptr1 = try test_ally.alloc(u64, 42768);
    std.debug.print("alloc ptr2\n", .{});
    const ptr2 = try test_ally.alloc(u64, 52768);
    std.debug.print("free ptr1\n", .{});
    test_ally.free(ptr1);
    std.debug.print("alloc ptr3\n", .{});
    const ptr3 = try test_ally.alloc(u64, 62768);
    std.debug.print("free ptr3\n", .{});
    test_ally.free(ptr3);
    std.debug.print("free ptr2\n", .{});
    test_ally.free(ptr2);
}
