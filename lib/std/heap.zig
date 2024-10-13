const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const c = std.c;
const Allocator = std.mem.Allocator;
const windows = std.os.windows;

pub const LoggingAllocator = @import("heap/logging_allocator.zig").LoggingAllocator;
pub const loggingAllocator = @import("heap/logging_allocator.zig").loggingAllocator;
pub const ScopedLoggingAllocator = @import("heap/logging_allocator.zig").ScopedLoggingAllocator;
pub const LogToWriterAllocator = @import("heap/log_to_writer_allocator.zig").LogToWriterAllocator;
pub const logToWriterAllocator = @import("heap/log_to_writer_allocator.zig").logToWriterAllocator;
pub const ArenaAllocator = @import("heap/arena_allocator.zig").ArenaAllocator;
pub const GeneralPurposeAllocatorConfig = @import("heap/general_purpose_allocator.zig").Config;
pub const GeneralPurposeAllocator = @import("heap/general_purpose_allocator.zig").GeneralPurposeAllocator;
pub const Check = @import("heap/general_purpose_allocator.zig").Check;
pub const WasmAllocator = @import("heap/WasmAllocator.zig");
pub const WasmPageAllocator = @import("heap/WasmPageAllocator.zig");
pub const PageAllocator = @import("heap/PageAllocator.zig");
pub const ThreadSafeAllocator = @import("heap/ThreadSafeAllocator.zig");
pub const SbrkAllocator = @import("heap/sbrk_allocator.zig").SbrkAllocator;

const memory_pool = @import("heap/memory_pool.zig");
pub const MemoryPool = memory_pool.MemoryPool;
pub const MemoryPoolAligned = memory_pool.MemoryPoolAligned;
pub const MemoryPoolExtra = memory_pool.MemoryPoolExtra;
pub const MemoryPoolOptions = memory_pool.Options;

/// TODO Utilize this on Windows.
pub var next_mmap_addr_hint: ?[*]align(mem.page_size) u8 = null;

const CAllocator = struct {
    comptime {
        if (!builtin.link_libc) {
            @compileError("C allocator is only available when linking against libc");
        }
    }

    pub const supports_malloc_size = @TypeOf(malloc_size) != void;
    pub const malloc_size = if (@TypeOf(c.malloc_size) != void)
        c.malloc_size
    else if (@TypeOf(c.malloc_usable_size) != void)
        c.malloc_usable_size
    else if (@TypeOf(c._msize) != void)
        c._msize
    else {};

    pub const supports_posix_memalign = switch (builtin.os.tag) {
        .dragonfly, .netbsd, .freebsd, .solaris, .openbsd, .linux, .macos, .ios, .tvos, .watchos, .visionos => true,
        else => false,
    };

    fn getHeader(ptr: [*]u8) *[*]u8 {
        return @as(*[*]u8, @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)));
    }

    fn alignedAlloc(len: usize, log2_align: u8) ?[*]u8 {
        const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_align));
        if (supports_posix_memalign) {
            // The posix_memalign only accepts alignment values that are a
            // multiple of the pointer size
            const eff_alignment = @max(alignment, @sizeOf(usize));

            var aligned_ptr: ?*anyopaque = undefined;
            if (c.posix_memalign(&aligned_ptr, eff_alignment, len) != 0)
                return null;

            return @as([*]u8, @ptrCast(aligned_ptr));
        }

        // Thin wrapper around regular malloc, overallocate to account for
        // alignment padding and store the original malloc()'ed pointer before
        // the aligned address.
        const unaligned_ptr = @as([*]u8, @ptrCast(c.malloc(len + alignment - 1 + @sizeOf(usize)) orelse return null));
        const unaligned_addr = @intFromPtr(unaligned_ptr);
        const aligned_addr = mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment);
        const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
        getHeader(aligned_ptr).* = unaligned_ptr;

        return aligned_ptr;
    }

    fn alignedFree(ptr: [*]u8) void {
        if (supports_posix_memalign) {
            return c.free(ptr);
        }

        const unaligned_ptr = getHeader(ptr).*;
        c.free(unaligned_ptr);
    }

    fn alignedAllocSize(ptr: [*]u8) usize {
        if (supports_posix_memalign) {
            return CAllocator.malloc_size(ptr);
        }

        const unaligned_ptr = getHeader(ptr).*;
        const delta = @intFromPtr(ptr) - @intFromPtr(unaligned_ptr);
        return CAllocator.malloc_size(unaligned_ptr) - delta;
    }

    fn alloc(
        _: *anyopaque,
        len: usize,
        log2_align: u8,
        return_address: usize,
    ) ?[*]u8 {
        _ = return_address;
        assert(len > 0);
        return alignedAlloc(len, log2_align);
    }

    fn resize(
        _: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        new_len: usize,
        return_address: usize,
    ) bool {
        _ = log2_buf_align;
        _ = return_address;
        if (new_len <= buf.len) {
            return true;
        }
        if (CAllocator.supports_malloc_size) {
            const full_len = alignedAllocSize(buf.ptr);
            if (new_len <= full_len) {
                return true;
            }
        }
        return false;
    }

    fn free(
        _: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        return_address: usize,
    ) void {
        _ = log2_buf_align;
        _ = return_address;
        alignedFree(buf.ptr);
    }
};

/// Supports the full Allocator interface, including alignment, and exploiting
/// `malloc_usable_size` if available. For an allocator that directly calls
/// `malloc`/`free`, see `raw_c_allocator`.
pub const c_allocator = Allocator{
    .ptr = undefined,
    .vtable = &c_allocator_vtable,
};
const c_allocator_vtable = Allocator.VTable{
    .alloc = CAllocator.alloc,
    .resize = CAllocator.resize,
    .free = CAllocator.free,
};

/// Asserts allocations are within `@alignOf(std.c.max_align_t)` and directly calls
/// `malloc`/`free`. Does not attempt to utilize `malloc_usable_size`.
/// This allocator is safe to use as the backing allocator with
/// `ArenaAllocator` for example and is more optimal in such a case
/// than `c_allocator`.
pub const raw_c_allocator = Allocator{
    .ptr = undefined,
    .vtable = &raw_c_allocator_vtable,
};
const raw_c_allocator_vtable = Allocator.VTable{
    .alloc = rawCAlloc,
    .resize = rawCResize,
    .free = rawCFree,
};

fn rawCAlloc(
    _: *anyopaque,
    len: usize,
    log2_ptr_align: u8,
    ret_addr: usize,
) ?[*]u8 {
    _ = ret_addr;
    assert(log2_ptr_align <= comptime std.math.log2_int(usize, @alignOf(std.c.max_align_t)));
    // Note that this pointer cannot be aligncasted to max_align_t because if
    // len is < max_align_t then the alignment can be smaller. For example, if
    // max_align_t is 16, but the user requests 8 bytes, there is no built-in
    // type in C that is size 8 and has 16 byte alignment, so the alignment may
    // be 8 bytes rather than 16. Similarly if only 1 byte is requested, malloc
    // is allowed to return a 1-byte aligned pointer.
    return @as(?[*]u8, @ptrCast(c.malloc(len)));
}

fn rawCResize(
    _: *anyopaque,
    buf: []u8,
    log2_old_align: u8,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = log2_old_align;
    _ = ret_addr;

    if (new_len <= buf.len)
        return true;

    if (CAllocator.supports_malloc_size) {
        const full_len = CAllocator.malloc_size(buf.ptr);
        if (new_len <= full_len) return true;
    }

    return false;
}

fn rawCFree(
    _: *anyopaque,
    buf: []u8,
    log2_old_align: u8,
    ret_addr: usize,
) void {
    _ = log2_old_align;
    _ = ret_addr;
    c.free(buf.ptr);
}

/// This allocator makes a syscall directly for every allocation and free.
/// Thread-safe and lock-free.
pub const page_allocator = if (@hasDecl(root, "os") and
    @hasDecl(root.os, "heap") and
    @hasDecl(root.os.heap, "page_allocator"))
    root.os.heap.page_allocator
else if (builtin.target.isWasm())
    Allocator{
        .ptr = undefined,
        .vtable = &WasmPageAllocator.vtable,
    }
else if (builtin.target.os.tag == .plan9)
    Allocator{
        .ptr = undefined,
        .vtable = &SbrkAllocator(std.os.plan9.sbrk).vtable,
    }
else
    Allocator{
        .ptr = undefined,
        .vtable = &PageAllocator.vtable,
    };

/// This allocator is fast, small, and specific to WebAssembly. In the future,
/// this will be the implementation automatically selected by
/// `GeneralPurposeAllocator` when compiling in `ReleaseSmall` mode for wasm32
/// and wasm64 architectures.
/// Until then, it is available here to play with.
pub const wasm_allocator = Allocator{
    .ptr = undefined,
    .vtable = &std.heap.WasmAllocator.vtable,
};

/// Verifies that the adjusted length will still map to the full length
pub fn alignPageAllocLen(full_len: usize, len: usize) usize {
    const aligned_len = mem.alignAllocLen(full_len, len);
    assert(mem.alignForward(usize, aligned_len, mem.page_size) == full_len);
    return aligned_len;
}

pub const HeapAllocator = switch (builtin.os.tag) {
    .windows => struct {
        heap_handle: ?HeapHandle,

        const HeapHandle = windows.HANDLE;

        pub fn init() HeapAllocator {
            return HeapAllocator{
                .heap_handle = null,
            };
        }

        pub fn allocator(self: *HeapAllocator) Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        pub fn deinit(self: *HeapAllocator) void {
            if (self.heap_handle) |heap_handle| {
                windows.HeapDestroy(heap_handle);
            }
        }

        fn getRecordPtr(buf: []u8) *align(1) usize {
            return @as(*align(1) usize, @ptrFromInt(@intFromPtr(buf.ptr) + buf.len));
        }

        fn alloc(
            ctx: *anyopaque,
            n: usize,
            log2_ptr_align: u8,
            return_address: usize,
        ) ?[*]u8 {
            _ = return_address;
            const self: *HeapAllocator = @ptrCast(@alignCast(ctx));

            const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));
            const amt = n + ptr_align - 1 + @sizeOf(usize);
            const optional_heap_handle = @atomicLoad(?HeapHandle, &self.heap_handle, .seq_cst);
            const heap_handle = optional_heap_handle orelse blk: {
                const options = if (builtin.single_threaded) windows.HEAP_NO_SERIALIZE else 0;
                const hh = windows.kernel32.HeapCreate(options, amt, 0) orelse return null;
                const other_hh = @cmpxchgStrong(?HeapHandle, &self.heap_handle, null, hh, .seq_cst, .seq_cst) orelse break :blk hh;
                windows.HeapDestroy(hh);
                break :blk other_hh.?; // can't be null because of the cmpxchg
            };
            const ptr = windows.kernel32.HeapAlloc(heap_handle, 0, amt) orelse return null;
            const root_addr = @intFromPtr(ptr);
            const aligned_addr = mem.alignForward(usize, root_addr, ptr_align);
            const buf = @as([*]u8, @ptrFromInt(aligned_addr))[0..n];
            getRecordPtr(buf).* = root_addr;
            return buf.ptr;
        }

        fn resize(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            new_size: usize,
            return_address: usize,
        ) bool {
            _ = log2_buf_align;
            _ = return_address;
            const self: *HeapAllocator = @ptrCast(@alignCast(ctx));

            const root_addr = getRecordPtr(buf).*;
            const align_offset = @intFromPtr(buf.ptr) - root_addr;
            const amt = align_offset + new_size + @sizeOf(usize);
            const new_ptr = windows.kernel32.HeapReAlloc(
                self.heap_handle.?,
                windows.HEAP_REALLOC_IN_PLACE_ONLY,
                @as(*anyopaque, @ptrFromInt(root_addr)),
                amt,
            ) orelse return false;
            assert(new_ptr == @as(*anyopaque, @ptrFromInt(root_addr)));
            getRecordPtr(buf.ptr[0..new_size]).* = root_addr;
            return true;
        }

        fn free(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            return_address: usize,
        ) void {
            _ = log2_buf_align;
            _ = return_address;
            const self: *HeapAllocator = @ptrCast(@alignCast(ctx));
            windows.HeapFree(self.heap_handle.?, 0, @as(*anyopaque, @ptrFromInt(getRecordPtr(buf).*)));
        }
    },
    else => @compileError("Unsupported OS"),
};

fn sliceContainsPtr(container: []u8, ptr: [*]u8) bool {
    return @intFromPtr(ptr) >= @intFromPtr(container.ptr) and
        @intFromPtr(ptr) < (@intFromPtr(container.ptr) + container.len);
}

fn sliceContainsSlice(container: []u8, slice: []u8) bool {
    return @intFromPtr(slice.ptr) >= @intFromPtr(container.ptr) and
        (@intFromPtr(slice.ptr) + slice.len) <= (@intFromPtr(container.ptr) + container.len);
}

pub const FixedBufferAllocator = struct {
    end_index: usize,
    buffer: []u8,

    pub fn init(buffer: []u8) FixedBufferAllocator {
        return FixedBufferAllocator{
            .buffer = buffer,
            .end_index = 0,
        };
    }

    /// *WARNING* using this at the same time as the interface returned by `threadSafeAllocator` is not thread safe
    pub fn allocator(self: *FixedBufferAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    /// Provides a lock free thread safe `Allocator` interface to the underlying `FixedBufferAllocator`
    /// *WARNING* using this at the same time as the interface returned by `allocator` is not thread safe
    pub fn threadSafeAllocator(self: *FixedBufferAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = threadSafeAlloc,
                .resize = Allocator.noResize,
                .free = Allocator.noFree,
            },
        };
    }

    pub fn ownsPtr(self: *FixedBufferAllocator, ptr: [*]u8) bool {
        return sliceContainsPtr(self.buffer, ptr);
    }

    pub fn ownsSlice(self: *FixedBufferAllocator, slice: []u8) bool {
        return sliceContainsSlice(self.buffer, slice);
    }

    /// NOTE: this will not work in all cases, if the last allocation had an adjusted_index
    ///       then we won't be able to determine what the last allocation was.  This is because
    ///       the alignForward operation done in alloc is not reversible.
    pub fn isLastAllocation(self: *FixedBufferAllocator, buf: []u8) bool {
        return buf.ptr + buf.len == self.buffer.ptr + self.end_index;
    }

    fn alloc(ctx: *anyopaque, n: usize, log2_ptr_align: u8, ra: usize) ?[*]u8 {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = ra;
        const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));
        const adjust_off = mem.alignPointerOffset(self.buffer.ptr + self.end_index, ptr_align) orelse return null;
        const adjusted_index = self.end_index + adjust_off;
        const new_end_index = adjusted_index + n;
        if (new_end_index > self.buffer.len) return null;
        self.end_index = new_end_index;
        return self.buffer.ptr + adjusted_index;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        new_size: usize,
        return_address: usize,
    ) bool {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = log2_buf_align;
        _ = return_address;
        assert(@inComptime() or self.ownsSlice(buf));

        if (!self.isLastAllocation(buf)) {
            if (new_size > buf.len) return false;
            return true;
        }

        if (new_size <= buf.len) {
            const sub = buf.len - new_size;
            self.end_index -= sub;
            return true;
        }

        const add = new_size - buf.len;
        if (add + self.end_index > self.buffer.len) return false;

        self.end_index += add;
        return true;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        return_address: usize,
    ) void {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = log2_buf_align;
        _ = return_address;
        assert(@inComptime() or self.ownsSlice(buf));

        if (self.isLastAllocation(buf)) {
            self.end_index -= buf.len;
        }
    }

    fn threadSafeAlloc(ctx: *anyopaque, n: usize, log2_ptr_align: u8, ra: usize) ?[*]u8 {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = ra;
        const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));
        var end_index = @atomicLoad(usize, &self.end_index, .seq_cst);
        while (true) {
            const adjust_off = mem.alignPointerOffset(self.buffer.ptr + end_index, ptr_align) orelse return null;
            const adjusted_index = end_index + adjust_off;
            const new_end_index = adjusted_index + n;
            if (new_end_index > self.buffer.len) return null;
            end_index = @cmpxchgWeak(usize, &self.end_index, end_index, new_end_index, .seq_cst, .seq_cst) orelse
                return self.buffer[adjusted_index..new_end_index].ptr;
        }
    }

    pub fn reset(self: *FixedBufferAllocator) void {
        self.end_index = 0;
    }
};

/// Returns a `StackFallbackAllocator` allocating using either a
/// `FixedBufferAllocator` on an array of size `size` and falling back to
/// `fallback_allocator` if that fails.
pub fn stackFallback(comptime size: usize, fallback_allocator: Allocator) StackFallbackAllocator(size) {
    return StackFallbackAllocator(size){
        .buffer = undefined,
        .fallback_allocator = fallback_allocator,
        .fixed_buffer_allocator = undefined,
    };
}

/// An allocator that attempts to allocate using a
/// `FixedBufferAllocator` using an array of size `size`. If the
/// allocation fails, it will fall back to using
/// `fallback_allocator`. Easily created with `stackFallback`.
pub fn StackFallbackAllocator(comptime size: usize) type {
    return struct {
        const Self = @This();

        buffer: [size]u8,
        fallback_allocator: Allocator,
        fixed_buffer_allocator: FixedBufferAllocator,
        get_called: if (std.debug.runtime_safety) bool else void =
            if (std.debug.runtime_safety) false else {},

        /// This function both fetches a `Allocator` interface to this
        /// allocator *and* resets the internal buffer allocator.
        pub fn get(self: *Self) Allocator {
            if (std.debug.runtime_safety) {
                assert(!self.get_called); // `get` called multiple times; instead use `const allocator = stackFallback(N).get();`
                self.get_called = true;
            }
            self.fixed_buffer_allocator = FixedBufferAllocator.init(self.buffer[0..]);
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        /// Unlike most std allocators `StackFallbackAllocator` modifies
        /// its internal state before returning an implementation of
        /// the`Allocator` interface and therefore also doesn't use
        /// the usual `.allocator()` method.
        pub const allocator = @compileError("use 'const allocator = stackFallback(N).get();' instead");

        fn alloc(
            ctx: *anyopaque,
            len: usize,
            log2_ptr_align: u8,
            ra: usize,
        ) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return FixedBufferAllocator.alloc(&self.fixed_buffer_allocator, len, log2_ptr_align, ra) orelse
                return self.fallback_allocator.rawAlloc(len, log2_ptr_align, ra);
        }

        fn resize(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            new_len: usize,
            ra: usize,
        ) bool {
            const self: *Self = @ptrCast(@alignCast(ctx));
            if (self.fixed_buffer_allocator.ownsPtr(buf.ptr)) {
                return FixedBufferAllocator.resize(&self.fixed_buffer_allocator, buf, log2_buf_align, new_len, ra);
            } else {
                return self.fallback_allocator.rawResize(buf, log2_buf_align, new_len, ra);
            }
        }

        fn free(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            ra: usize,
        ) void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            if (self.fixed_buffer_allocator.ownsPtr(buf.ptr)) {
                return FixedBufferAllocator.free(&self.fixed_buffer_allocator, buf, log2_buf_align, ra);
            } else {
                return self.fallback_allocator.rawFree(buf, log2_buf_align, ra);
            }
        }
    };
}

test "c_allocator" {
    if (builtin.link_libc) {
        try testAllocator(c_allocator);
        try testAllocatorAligned(c_allocator);
        try testAllocatorLargeAlignment(c_allocator);
        try testAllocatorAlignedShrink(c_allocator);
    }
}

test "raw_c_allocator" {
    if (builtin.link_libc) {
        try testAllocator(raw_c_allocator);
    }
}

test "PageAllocator" {
    const allocator = page_allocator;
    try testAllocator(allocator);
    try testAllocatorAligned(allocator);
    if (!builtin.target.isWasm()) {
        try testAllocatorLargeAlignment(allocator);
        try testAllocatorAlignedShrink(allocator);
    }

    if (builtin.os.tag == .windows) {
        const slice = try allocator.alignedAlloc(u8, mem.page_size, 128);
        slice[0] = 0x12;
        slice[127] = 0x34;
        allocator.free(slice);
    }
    {
        var buf = try allocator.alloc(u8, mem.page_size + 1);
        defer allocator.free(buf);
        buf = try allocator.realloc(buf, 1); // shrink past the page boundary
    }
}

test "HeapAllocator" {
    if (builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/13702
        if (builtin.cpu.arch == .aarch64) return error.SkipZigTest;

        var heap_allocator = HeapAllocator.init();
        defer heap_allocator.deinit();
        const allocator = heap_allocator.allocator();

        try testAllocator(allocator);
        try testAllocatorAligned(allocator);
        try testAllocatorLargeAlignment(allocator);
        try testAllocatorAlignedShrink(allocator);
    }
}

test "ArenaAllocator" {
    var arena_allocator = ArenaAllocator.init(page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    try testAllocator(allocator);
    try testAllocatorAligned(allocator);
    try testAllocatorLargeAlignment(allocator);
    try testAllocatorAlignedShrink(allocator);
}

var test_fixed_buffer_allocator_memory: [800000 * @sizeOf(u64)]u8 = undefined;
test "FixedBufferAllocator" {
    var fixed_buffer_allocator = mem.validationWrap(FixedBufferAllocator.init(test_fixed_buffer_allocator_memory[0..]));
    const allocator = fixed_buffer_allocator.allocator();

    try testAllocator(allocator);
    try testAllocatorAligned(allocator);
    try testAllocatorLargeAlignment(allocator);
    try testAllocatorAlignedShrink(allocator);
}

test "FixedBufferAllocator.reset" {
    var buf: [8]u8 align(@alignOf(u64)) = undefined;
    var fba = FixedBufferAllocator.init(buf[0..]);
    const allocator = fba.allocator();

    const X = 0xeeeeeeeeeeeeeeee;
    const Y = 0xffffffffffffffff;

    const x = try allocator.create(u64);
    x.* = X;
    try testing.expectError(error.OutOfMemory, allocator.create(u64));

    fba.reset();
    const y = try allocator.create(u64);
    y.* = Y;

    // we expect Y to have overwritten X.
    try testing.expect(x.* == y.*);
    try testing.expect(y.* == Y);
}

test "StackFallbackAllocator" {
    {
        var stack_allocator = stackFallback(4096, std.testing.allocator);
        try testAllocator(stack_allocator.get());
    }
    {
        var stack_allocator = stackFallback(4096, std.testing.allocator);
        try testAllocatorAligned(stack_allocator.get());
    }
    {
        var stack_allocator = stackFallback(4096, std.testing.allocator);
        try testAllocatorLargeAlignment(stack_allocator.get());
    }
    {
        var stack_allocator = stackFallback(4096, std.testing.allocator);
        try testAllocatorAlignedShrink(stack_allocator.get());
    }
}

test "FixedBufferAllocator Reuse memory on realloc" {
    var small_fixed_buffer: [10]u8 = undefined;
    // check if we re-use the memory
    {
        var fixed_buffer_allocator = FixedBufferAllocator.init(small_fixed_buffer[0..]);
        const allocator = fixed_buffer_allocator.allocator();

        const slice0 = try allocator.alloc(u8, 5);
        try testing.expect(slice0.len == 5);
        const slice1 = try allocator.realloc(slice0, 10);
        try testing.expect(slice1.ptr == slice0.ptr);
        try testing.expect(slice1.len == 10);
        try testing.expectError(error.OutOfMemory, allocator.realloc(slice1, 11));
    }
    // check that we don't re-use the memory if it's not the most recent block
    {
        var fixed_buffer_allocator = FixedBufferAllocator.init(small_fixed_buffer[0..]);
        const allocator = fixed_buffer_allocator.allocator();

        var slice0 = try allocator.alloc(u8, 2);
        slice0[0] = 1;
        slice0[1] = 2;
        const slice1 = try allocator.alloc(u8, 2);
        const slice2 = try allocator.realloc(slice0, 4);
        try testing.expect(slice0.ptr != slice2.ptr);
        try testing.expect(slice1.ptr != slice2.ptr);
        try testing.expect(slice2[0] == 1);
        try testing.expect(slice2[1] == 2);
    }
}

test "Thread safe FixedBufferAllocator" {
    var fixed_buffer_allocator = FixedBufferAllocator.init(test_fixed_buffer_allocator_memory[0..]);

    try testAllocator(fixed_buffer_allocator.threadSafeAllocator());
    try testAllocatorAligned(fixed_buffer_allocator.threadSafeAllocator());
    try testAllocatorLargeAlignment(fixed_buffer_allocator.threadSafeAllocator());
    try testAllocatorAlignedShrink(fixed_buffer_allocator.threadSafeAllocator());
}

/// This one should not try alignments that exceed what C malloc can handle.
pub fn testAllocator(base_allocator: mem.Allocator) !void {
    var validationAllocator = mem.validationWrap(base_allocator);
    const allocator = validationAllocator.allocator();

    var slice = try allocator.alloc(*i32, 100);
    try testing.expect(slice.len == 100);
    for (slice, 0..) |*item, i| {
        item.* = try allocator.create(i32);
        item.*.* = @as(i32, @intCast(i));
    }

    slice = try allocator.realloc(slice, 20000);
    try testing.expect(slice.len == 20000);

    for (slice[0..100], 0..) |item, i| {
        try testing.expect(item.* == @as(i32, @intCast(i)));
        allocator.destroy(item);
    }

    if (allocator.resize(slice, 50)) {
        slice = slice[0..50];
        if (allocator.resize(slice, 25)) {
            slice = slice[0..25];
            try testing.expect(allocator.resize(slice, 0));
            slice = slice[0..0];
            slice = try allocator.realloc(slice, 10);
            try testing.expect(slice.len == 10);
        }
    }
    allocator.free(slice);

    // Zero-length allocation
    const empty = try allocator.alloc(u8, 0);
    allocator.free(empty);
    // Allocation with zero-sized types
    const zero_bit_ptr = try allocator.create(u0);
    zero_bit_ptr.* = 0;
    allocator.destroy(zero_bit_ptr);

    const oversize = try allocator.alignedAlloc(u32, null, 5);
    try testing.expect(oversize.len >= 5);
    for (oversize) |*item| {
        item.* = 0xDEADBEEF;
    }
    allocator.free(oversize);
}

pub fn testAllocatorAligned(base_allocator: mem.Allocator) !void {
    var validationAllocator = mem.validationWrap(base_allocator);
    const allocator = validationAllocator.allocator();

    // Test a few alignment values, smaller and bigger than the type's one
    inline for ([_]u29{ 1, 2, 4, 8, 16, 32, 64 }) |alignment| {
        // initial
        var slice = try allocator.alignedAlloc(u8, alignment, 10);
        try testing.expect(slice.len == 10);
        // grow
        slice = try allocator.realloc(slice, 100);
        try testing.expect(slice.len == 100);
        if (allocator.resize(slice, 10)) {
            slice = slice[0..10];
        }
        try testing.expect(allocator.resize(slice, 0));
        slice = slice[0..0];
        // realloc from zero
        slice = try allocator.realloc(slice, 100);
        try testing.expect(slice.len == 100);
        if (allocator.resize(slice, 10)) {
            slice = slice[0..10];
        }
        try testing.expect(allocator.resize(slice, 0));
    }
}

pub fn testAllocatorLargeAlignment(base_allocator: mem.Allocator) !void {
    var validationAllocator = mem.validationWrap(base_allocator);
    const allocator = validationAllocator.allocator();

    const large_align: usize = mem.page_size / 2;

    var align_mask: usize = undefined;
    align_mask = @shlWithOverflow(~@as(usize, 0), @as(Allocator.Log2Align, @ctz(large_align)))[0];

    var slice = try allocator.alignedAlloc(u8, large_align, 500);
    try testing.expect(@intFromPtr(slice.ptr) & align_mask == @intFromPtr(slice.ptr));

    if (allocator.resize(slice, 100)) {
        slice = slice[0..100];
    }

    slice = try allocator.realloc(slice, 5000);
    try testing.expect(@intFromPtr(slice.ptr) & align_mask == @intFromPtr(slice.ptr));

    if (allocator.resize(slice, 10)) {
        slice = slice[0..10];
    }

    slice = try allocator.realloc(slice, 20000);
    try testing.expect(@intFromPtr(slice.ptr) & align_mask == @intFromPtr(slice.ptr));

    allocator.free(slice);
}

pub fn testAllocatorAlignedShrink(base_allocator: mem.Allocator) !void {
    var validationAllocator = mem.validationWrap(base_allocator);
    const allocator = validationAllocator.allocator();

    var debug_buffer: [1000]u8 = undefined;
    var fib = FixedBufferAllocator.init(&debug_buffer);
    const debug_allocator = fib.allocator();

    const alloc_size = mem.page_size * 2 + 50;
    var slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    defer allocator.free(slice);

    var stuff_to_free = std.ArrayList([]align(16) u8).init(debug_allocator);
    // On Windows, VirtualAlloc returns addresses aligned to a 64K boundary,
    // which is 16 pages, hence the 32. This test may require to increase
    // the size of the allocations feeding the `allocator` parameter if they
    // fail, because of this high over-alignment we want to have.
    while (@intFromPtr(slice.ptr) == mem.alignForward(usize, @intFromPtr(slice.ptr), mem.page_size * 32)) {
        try stuff_to_free.append(slice);
        slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    }
    while (stuff_to_free.popOrNull()) |item| {
        allocator.free(item);
    }
    slice[0] = 0x12;
    slice[60] = 0x34;

    slice = try allocator.reallocAdvanced(slice, alloc_size / 2, 0);
    try testing.expect(slice[0] == 0x12);
    try testing.expect(slice[60] == 0x34);
}

test {
    _ = LoggingAllocator;
    _ = LogToWriterAllocator;
    _ = ScopedLoggingAllocator;
    _ = @import("heap/memory_pool.zig");
    _ = ArenaAllocator;
    _ = GeneralPurposeAllocator;
    if (comptime builtin.target.isWasm()) {
        _ = WasmAllocator;
        _ = WasmPageAllocator;
    }
}
