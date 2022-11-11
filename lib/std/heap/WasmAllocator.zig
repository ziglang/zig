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
const ushift = math.Log2Int(usize);
const bigpage_size = 512 * 1024;
const pages_per_bigpage = bigpage_size / wasm.page_size;
const bigpage_count = max_usize / bigpage_size;

/// We have a small size class for all sizes up to 512kb.
const size_class_count = math.log2(bigpage_size);
/// 0 - 1 bigpage
/// 1 - 2 bigpages
/// 2 - 4 bigpages
/// etc.
const big_size_class_count = math.log2(bigpage_count);

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

const Bucket = struct {
    ptr: usize,
    end: usize,

    const init: Bucket = .{
        .ptr = 0,
        .end = 0,
    };
};

var next_addrs = [1]Bucket{Bucket.init} ** size_class_count;
var frees = [1]FreeList{FreeList.init} ** size_class_count;
var big_frees = [1]FreeList{FreeList.init} ** big_size_class_count;

fn alloc(ctx: *anyopaque, len: usize, alignment: u29, len_align: u29, ra: usize) Error![]u8 {
    _ = ctx;
    _ = len_align;
    _ = ra;
    const aligned_len = @max(len, alignment);
    const slot_size = math.ceilPowerOfTwoAssert(usize, aligned_len);
    const class = math.log2(slot_size);
    if (class < size_class_count) {
        const addr = a: {
            const free_list = &frees[class];
            if (free_list.len > 0) {
                free_list.len -= 1;
                break :a free_list.ptr[free_list.len];
            }

            // This prevents memory allocation within free().
            try ensureFreeListCapacity(free_list);

            const next_addr = next_addrs[class];
            if (next_addr.ptr == next_addr.end) {
                const addr = try allocBigPages(1);
                //std.debug.print("allocated fresh slot_size={d} class={d} addr=0x{x}\n", .{
                //    slot_size, class, addr,
                //});
                next_addrs[class] = .{
                    .ptr = addr + slot_size,
                    .end = addr + bigpage_size,
                };
                break :a addr;
            } else {
                next_addrs[class].ptr = next_addr.ptr + slot_size;
                break :a next_addr.ptr;
            }
        };
        return @intToPtr([*]u8, addr)[0..len];
    }
    const bigpages_needed = (aligned_len + (bigpage_size - 1)) / bigpage_size;
    const addr = try allocBigPages(bigpages_needed);
    return @intToPtr([*]u8, addr)[0..len];
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
    const aligned_len = @max(buf.len, buf_align);
    const slot_size = math.ceilPowerOfTwoAssert(usize, aligned_len);
    const class = math.log2(slot_size);
    if (class < size_class_count) {
        const free_list = &frees[class];
        assert(free_list.len < free_list.cap);
        free_list.ptr[free_list.len] = @ptrToInt(buf.ptr);
        free_list.len += 1;
    } else {
        const bigpages_needed = (aligned_len + (bigpage_size - 1)) / bigpage_size;
        const big_slot_size = math.ceilPowerOfTwoAssert(usize, bigpages_needed);
        const big_class = math.log2(big_slot_size);
        const free_list = &big_frees[big_class];
        assert(free_list.len < free_list.cap);
        free_list.ptr[free_list.len] = @ptrToInt(buf.ptr);
        free_list.len += 1;
    }
}

fn allocBigPages(n: usize) !usize {
    const slot_size = math.ceilPowerOfTwoAssert(usize, n);
    const class = math.log2(slot_size);

    const free_list = &big_frees[class];
    if (free_list.len > 0) {
        free_list.len -= 1;
        return free_list.ptr[free_list.len];
    }

    //std.debug.print("ensureFreeListCapacity slot_size={d} big_class={d}\n", .{
    //    slot_size, class,
    //});
    // This prevents memory allocation within free().
    try ensureFreeListCapacity(free_list);

    const page_index = @wasmMemoryGrow(0, slot_size * pages_per_bigpage);
    if (page_index <= 0) return error.OutOfMemory;
    const addr = @intCast(u32, page_index) * wasm.page_size;
    //std.debug.print("got 0x{x}..0x{x} from memory.grow\n", .{
    //    addr, addr + wasm.page_size * slot_size * pages_per_bigpage,
    //});
    return addr;
}

fn ensureFreeListCapacity(free_list: *FreeList) Allocator.Error!void {
    if (free_list.len < free_list.cap) return;
    const old_bigpage_count = free_list.cap / bigpage_size;
    free_list.cap = math.maxInt(usize); // Prevent recursive calls.
    const new_bigpage_count = @max(old_bigpage_count * 2, 1);
    const addr = try allocBigPages(new_bigpage_count);
    //std.debug.print("allocated {d} big pages: 0x{x}\n", .{ new_bigpage_count, addr });
    const new_ptr = @intToPtr([*]usize, addr);
    @memcpy(
        @ptrCast([*]u8, new_ptr),
        @ptrCast([*]u8, free_list.ptr),
        @sizeOf(usize) * free_list.len,
    );
    free_list.ptr = new_ptr;
    free_list.cap = new_bigpage_count * (bigpage_size / @sizeOf(usize));
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
    const ptr1 = try test_ally.alloc(u64, 42768);
    const ptr2 = try test_ally.alloc(u64, 52768);
    test_ally.free(ptr1);
    const ptr3 = try test_ally.alloc(u64, 62768);
    test_ally.free(ptr3);
    test_ally.free(ptr2);
}
