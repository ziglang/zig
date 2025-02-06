//! An allocator that is designed for ReleaseFast optimization mode, with
//! multi-threading enabled.
//!
//! This allocator is a singleton; it uses global state and only one should be
//! instantiated for the entire process.
//!
//! ## Basic Design
//!
//! Avoid locking the global mutex as much as possible.
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
const native_os = builtin.os.tag;

const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const Allocator = std.mem.Allocator;
const SmpAllocator = @This();
const PageAllocator = std.heap.PageAllocator;

/// Protects the state in this struct (global state), except for `threads`
/// which each have their own mutex.
mutex: std.Thread.Mutex,
next_thread_index: u32,
cpu_count: u32,
threads: [max_thread_count]Thread,

var global: SmpAllocator = .{
    .mutex = .{},
    .next_thread_index = 0,
    .threads = @splat(.{}),
    .cpu_count = 0,
};
threadlocal var thread_id: Thread.Id = .none;

const max_thread_count = 128;
const slab_len: usize = @max(std.heap.page_size_max, switch (builtin.os.tag) {
    .windows => 64 * 1024, // Makes `std.heap.PageAllocator` take the happy path.
    .wasi => 64 * 1024, // Max alignment supported by `std.heap.WasmAllocator`.
    else => 256 * 1024, // Avoids too many active mappings when `page_size_max` is low.
});
/// Because of storing free list pointers, the minimum size class is 3.
const min_class = math.log2(math.ceilPowerOfTwoAssert(usize, 1 + @sizeOf(usize)));
const size_class_count = math.log2(slab_len) - min_class;

const Thread = struct {
    /// Avoid false sharing.
    _: void align(std.atomic.cache_line) = {},

    /// Protects the state in this struct (per-thread state).
    ///
    /// Threads lock this before accessing their own state in order
    /// to support freelist reclamation.
    mutex: std.Thread.Mutex = .{},

    next_addrs: [size_class_count]usize = @splat(0),
    /// For each size class, points to the freed pointer.
    frees: [size_class_count]usize = @splat(0),

    /// Index into `SmpAllocator.threads`.
    const Id = enum(usize) {
        none = 0,
        first = 1,
        _,

        fn fromIndex(index: usize) Id {
            return @enumFromInt(index + 1);
        }

        fn toIndex(id: Id) usize {
            return @intFromEnum(id) - 1;
        }
    };

    fn lock() *Thread {
        const id = thread_id;
        if (id != .none) {
            var index = id.toIndex();
            {
                const t = &global.threads[index];
                if (t.mutex.tryLock()) return t;
            }
            const cpu_count = global.cpu_count;
            assert(cpu_count != 0);
            while (true) {
                index = (index + 1) % cpu_count;
                const t = &global.threads[index];
                if (t.mutex.tryLock()) {
                    thread_id = .fromIndex(index);
                    return t;
                }
            }
        }
        while (true) {
            const thread_index = i: {
                global.mutex.lock();
                defer global.mutex.unlock();
                const cpu_count = c: {
                    const cpu_count = global.cpu_count;
                    if (cpu_count == 0) {
                        const n: u32 = @intCast(@max(std.Thread.getCpuCount() catch max_thread_count, max_thread_count));
                        global.cpu_count = n;
                        break :c n;
                    }
                    break :c cpu_count;
                };
                const thread_index = global.next_thread_index;
                global.next_thread_index = @intCast((thread_index + 1) % cpu_count);
                break :i thread_index;
            };
            const t = &global.threads[thread_index];
            if (t.mutex.tryLock()) {
                thread_id = .fromIndex(thread_index);
                return t;
            }
        }
    }

    fn unlock(t: *Thread) void {
        t.mutex.unlock();
    }
};

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

    const t = Thread.lock();
    defer t.unlock();

    const slot_size = slotSize(class);

    const top_free_ptr = t.frees[class];
    if (top_free_ptr != 0) {
        const node: *usize = @ptrFromInt(top_free_ptr + (slot_size - @sizeOf(usize)));
        t.frees[class] = node.*;
        return @ptrFromInt(top_free_ptr);
    }

    const next_addr = t.next_addrs[class];
    if (next_addr % slab_len == 0) {
        const slab = PageAllocator.map(slab_len, .fromByteUnits(std.heap.pageSize())) orelse return null;
        t.next_addrs[class] = @intFromPtr(slab) + slot_size;
        return slab;
    }

    t.next_addrs[class] = next_addr + slot_size;
    return @ptrFromInt(next_addr);
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

    const t = Thread.lock();
    defer t.unlock();

    const slot_size = slotSize(class);
    const addr = @intFromPtr(memory.ptr);
    const node: *usize = @ptrFromInt(addr + (slot_size - @sizeOf(usize)));
    node.* = t.frees[class];
    t.frees[class] = addr;
}

fn sizeClassIndex(len: usize, alignment: mem.Alignment) usize {
    return @max(
        @bitSizeOf(usize) - @clz(len - 1),
        @intFromEnum(alignment),
        min_class,
    );
}

fn slotSize(class: usize) usize {
    const Log2USize = std.math.Log2Int(usize);
    return @as(usize, 1) << @as(Log2USize, @intCast(class));
}
