//! An allocator that is designed for ReleaseFast optimization mode, with
//! multi-threading enabled.
//!
//! This allocator is a singleton; it uses global state and only one should be
//! instantiated for the entire process.
//!
//! ## Basic Design
//!
//! Each thread gets a separate freelist, however, the data must be recoverable
//! when the thread exits. We do not directly learn when a thread exits, so
//! occasionally, one thread must attempt to reclaim another thread's
//! resources.
//!
//! Above a certain size, those allocations are memory mapped directly, with no
//! storage of allocation metadata. This works because the implementation
//! refuses resizes that would move an allocation from small category to large
//! category or vice versa.
//!
//! Each allocator operation checks the thread identifier from a threadlocal
//! variable to find out which metadata in the global state to access, and
//! attempts to grab its lock. This will usually succeed without contention,
//! unless another thread has been assigned the same id. In the case of such
//! contention, the thread moves on to the next thread metadata slot and
//! repeats the process of attempting to obtain the lock.
//!
//! By limiting the thread-local metadata array to the same number as the CPU
//! count, ensures that as threads are created and destroyed, they cycle
//! through the full set of freelists.

const builtin = @import("builtin");

const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const Allocator = std.mem.Allocator;
const SmpAllocator = @This();
const PageAllocator = std.heap.PageAllocator;

cpu_count: u32,
threads: [max_thread_count]Thread,

var global: SmpAllocator = .{
    .threads = @splat(.{}),
    .cpu_count = 0,
};
threadlocal var thread_index: u32 = 0;

const max_thread_count = 128;
const slab_len: usize = @max(std.heap.page_size_max, 64 * 1024);
/// Because of storing free list pointers, the minimum size class is 3.
const min_class = math.log2(@sizeOf(usize));
const size_class_count = math.log2(slab_len) - min_class;
/// When a freelist length exceeds this number, a `free` will rotate up to
/// `max_free_search` times before pushing.
const max_freelist_len: u8 = 16;
const max_free_search = 1;
/// Before mapping a fresh page, `alloc` will rotate this many times.
const max_alloc_search = 1;

const Thread = struct {
    /// Avoid false sharing.
    _: void align(std.atomic.cache_line) = {},

    /// Protects the state in this struct (per-thread state).
    ///
    /// Threads lock this before accessing their own state in order
    /// to support freelist reclamation.
    mutex: std.Thread.Mutex = .{},

    /// For each size class, tracks the next address to be returned from
    /// `alloc` when the freelist is empty.
    next_addrs: [size_class_count]usize = @splat(0),
    /// For each size class, points to the freed pointer.
    frees: [size_class_count]usize = @splat(0),
    /// For each size class, tracks the number of items in the freelist.
    freelist_lens: [size_class_count]u8 = @splat(0),

    fn lock() *Thread {
        var index = thread_index;
        {
            const t = &global.threads[index];
            if (t.mutex.tryLock()) {
                @branchHint(.likely);
                return t;
            }
        }
        const cpu_count = getCpuCount();
        assert(cpu_count != 0);
        while (true) {
            index = (index + 1) % cpu_count;
            const t = &global.threads[index];
            if (t.mutex.tryLock()) {
                thread_index = index;
                return t;
            }
        }
    }

    fn unlock(t: *Thread) void {
        t.mutex.unlock();
    }
};

fn getCpuCount() u32 {
    const cpu_count = @atomicLoad(u32, &global.cpu_count, .unordered);
    if (cpu_count != 0) return cpu_count;
    const n: u32 = @min(std.Thread.getCpuCount() catch max_thread_count, max_thread_count);
    return if (@cmpxchgStrong(u32, &global.cpu_count, 0, n, .monotonic, .monotonic)) |other| other else n;
}

pub const vtable: Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

comptime {
    assert(!builtin.single_threaded); // you're holding it wrong
}

fn alloc(context: *anyopaque, len: usize, alignment: mem.Alignment, ra: usize) ?[*]u8 {
    _ = context;
    _ = ra;
    const class = sizeClassIndex(len, alignment);
    if (class >= size_class_count) {
        @branchHint(.unlikely);
        return PageAllocator.map(len, alignment);
    }

    const slot_size = slotSize(class);
    assert(slab_len % slot_size == 0);
    var search_count: u8 = 0;

    var t = Thread.lock();

    outer: while (true) {
        const top_free_ptr = t.frees[class];
        if (top_free_ptr != 0) {
            @branchHint(.likely);
            defer t.unlock();
            const node: *usize = @ptrFromInt(top_free_ptr);
            t.frees[class] = node.*;
            t.freelist_lens[class] -|= 1;
            return @ptrFromInt(top_free_ptr);
        }

        const next_addr = t.next_addrs[class];
        if ((next_addr % slab_len) != 0) {
            @branchHint(.likely);
            defer t.unlock();
            t.next_addrs[class] = next_addr + slot_size;
            return @ptrFromInt(next_addr);
        }

        if (search_count >= max_alloc_search) {
            @branchHint(.likely);
            defer t.unlock();
            // slab alignment here ensures the % slab len earlier catches the end of slots.
            const slab = PageAllocator.map(slab_len, .fromByteUnits(slab_len)) orelse return null;
            t.next_addrs[class] = @intFromPtr(slab) + slot_size;
            t.freelist_lens[class] = 0;
            return slab;
        }

        t.unlock();
        const cpu_count = getCpuCount();
        assert(cpu_count != 0);
        var index = thread_index;
        while (true) {
            index = (index + 1) % cpu_count;
            t = &global.threads[index];
            if (t.mutex.tryLock()) {
                thread_index = index;
                search_count += 1;
                continue :outer;
            }
        }
    }
}

fn resize(context: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ra: usize) bool {
    _ = context;
    _ = ra;
    const class = sizeClassIndex(memory.len, alignment);
    const new_class = sizeClassIndex(new_len, alignment);
    if (class >= size_class_count) {
        if (new_class < size_class_count) return false;
        return PageAllocator.realloc(memory, new_len, false) != null;
    }
    return new_class == class;
}

fn remap(context: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
    _ = context;
    _ = ra;
    const class = sizeClassIndex(memory.len, alignment);
    const new_class = sizeClassIndex(new_len, alignment);
    if (class >= size_class_count) {
        if (new_class < size_class_count) return null;
        return PageAllocator.realloc(memory, new_len, true);
    }
    return if (new_class == class) memory.ptr else null;
}

fn free(context: *anyopaque, memory: []u8, alignment: mem.Alignment, ra: usize) void {
    _ = context;
    _ = ra;
    const class = sizeClassIndex(memory.len, alignment);
    if (class >= size_class_count) {
        @branchHint(.unlikely);
        return PageAllocator.unmap(@alignCast(memory));
    }

    const node: *usize = @alignCast(@ptrCast(memory.ptr));
    var search_count: u8 = 0;

    var t = Thread.lock();

    outer: while (true) {
        const freelist_len = t.freelist_lens[class];
        if (freelist_len < max_freelist_len) {
            @branchHint(.likely);
            defer t.unlock();
            node.* = t.frees[class];
            t.frees[class] = @intFromPtr(node);
            return;
        }

        if (search_count >= max_free_search) {
            defer t.unlock();
            t.freelist_lens[class] = freelist_len +| 1;
            node.* = t.frees[class];
            t.frees[class] = @intFromPtr(node);
            return;
        }

        t.unlock();
        const cpu_count = getCpuCount();
        assert(cpu_count != 0);
        var index = thread_index;
        while (true) {
            index = (index + 1) % cpu_count;
            t = &global.threads[index];
            if (t.mutex.tryLock()) {
                thread_index = index;
                search_count += 1;
                continue :outer;
            }
        }
    }
}

fn sizeClassIndex(len: usize, alignment: mem.Alignment) usize {
    return @max(@bitSizeOf(usize) - @clz(len - 1), @intFromEnum(alignment), min_class) - min_class;
}

fn slotSize(class: usize) usize {
    return @as(usize, 1) << @intCast(class + min_class);
}
