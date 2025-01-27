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

        try alloc.testAllocator(allocator);
        try alloc.testAllocatorAligned(allocator);
        try alloc.testAllocatorLargeAlignment(allocator);
        try alloc.testAllocatorAlignedShrink(allocator);
    }
}
