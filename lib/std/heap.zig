const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const c = std.c;
const Allocator = std.mem.Allocator;
const windows = std.os.windows;

pub const alloc = @import("alloc.zig");

/// This has moved into std.alloc and is provided here only for compatibility
pub const LoggingAllocator = alloc.Logging.Allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const loggingAllocator = alloc.Logging.allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const ScopedLoggingAllocator = alloc.Logging.ScopedAllocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const LogToWriterAllocator = alloc.LogToWriter.Allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const logToWriterAllocator = alloc.LogToWriter.allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const ArenaAllocator = alloc.Arena;
/// This has moved into std.alloc and is provided here only for compatibility
pub const GeneralPurposeAllocatorConfig = alloc.GeneralPurpose.Config;
/// This has moved into std.alloc and is provided here only for compatibility
pub const GeneralPurposeAllocator = alloc.GeneralPurpose.Allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const Check = alloc.GeneralPurpose.Check;
/// This has moved into std.alloc and is provided here only for compatibility
pub const WasmAllocator = alloc.Wasm;
/// This has moved into std.alloc and is provided here only for compatibility
pub const WasmPageAllocator = alloc.WasmPage;
/// This has moved into std.alloc and is provided here only for compatibility
pub const PageAllocator = alloc.Page;
/// This has moved into std.alloc and is provided here only for compatibility
pub const ThreadSafeAllocator = alloc.ThreadSafe;
/// This has moved into std.alloc and is provided here only for compatibility
pub const SbrkAllocator = alloc.Sbrk.Allocator;

/// This has moved into std.alloc and is provided here only for compatibility
pub const MemoryPool = alloc.MemoryPool.Auto;
/// This has moved into std.alloc and is provided here only for compatibility
pub const MemoryPoolAligned = alloc.MemoryPool.Aligned;
/// This has moved into std.alloc and is provided here only for compatibility
pub const MemoryPoolExtra = alloc.MemoryPool.Extra;
/// This has moved into std.alloc and is provided here only for compatibility
pub const MemoryPoolOptions = alloc.MemoryPool.Options;

/// This has moved into std.alloc and is provided here only for compatibility
const CAllocator = alloc.CAllocator;

/// This has moved into std.alloc and is provided here only for compatibility
pub const c_allocator = alloc.c_allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const raw_c_allocator = alloc.raw_c_allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const page_allocator = alloc.page_allocator;
/// This has moved into std.alloc and is provided here only for compatibility
pub const wasm_allocator = alloc.wasm_allocator;

/// This has moved into std.alloc and is provided here only for compatibility
pub const FixedBufferAllocator = alloc.FixedBuffer;
/// This has moved into std.alloc and is provided here only for compatibility
pub const stackFallback = alloc.stackFallback;
/// This has moved into std.alloc and is provided here only for compatibility
pub const StackFallbackAllocator = alloc.StackFallbackAllocator;

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
                    .alloc = HeapAllocator.alloc,
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
    if (builtin.target.isWasm()) {
        _ = WasmAllocator;
    }
}
