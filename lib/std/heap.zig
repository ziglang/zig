const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const c = std.c;
const Allocator = std.mem.Allocator;
const windows = std.os.windows;

pub const ArenaAllocator = @import("heap/arena_allocator.zig").ArenaAllocator;
pub const SmpAllocator = @import("heap/SmpAllocator.zig");
pub const FixedBufferAllocator = @import("heap/FixedBufferAllocator.zig");
pub const PageAllocator = @import("heap/PageAllocator.zig");
pub const SbrkAllocator = @import("heap/sbrk_allocator.zig").SbrkAllocator;
pub const ThreadSafeAllocator = @import("heap/ThreadSafeAllocator.zig");
pub const WasmAllocator = @import("heap/WasmAllocator.zig");

pub const DebugAllocatorConfig = @import("heap/debug_allocator.zig").Config;
pub const DebugAllocator = @import("heap/debug_allocator.zig").DebugAllocator;
pub const Check = enum { ok, leak };
/// Deprecated; to be removed after 0.14.0 is tagged.
pub const GeneralPurposeAllocatorConfig = DebugAllocatorConfig;
/// Deprecated; to be removed after 0.14.0 is tagged.
pub const GeneralPurposeAllocator = DebugAllocator;

const memory_pool = @import("heap/memory_pool.zig");
pub const MemoryPool = memory_pool.MemoryPool;
pub const MemoryPoolAligned = memory_pool.MemoryPoolAligned;
pub const MemoryPoolExtra = memory_pool.MemoryPoolExtra;
pub const MemoryPoolOptions = memory_pool.Options;

/// TODO Utilize this on Windows.
pub var next_mmap_addr_hint: ?[*]align(page_size_min) u8 = null;

/// comptime-known minimum page size of the target.
///
/// All pointers from `mmap` or `VirtualAlloc` are aligned to at least
/// `page_size_min`, but their actual alignment may be bigger.
///
/// This value can be overridden via `std.options.page_size_min`.
///
/// On many systems, the actual page size can only be determined at runtime
/// with `pageSize`.
pub const page_size_min: usize = std.options.page_size_min orelse (page_size_min_default orelse if (builtin.os.tag == .freestanding or builtin.os.tag == .other)
    @compileError("freestanding/other page_size_min must provided with std.options.page_size_min")
else
    @compileError(@tagName(builtin.cpu.arch) ++ "-" ++ @tagName(builtin.os.tag) ++ " has unknown page_size_min; populate std.options.page_size_min"));

/// comptime-known maximum page size of the target.
///
/// Targeting a system with a larger page size may require overriding
/// `std.options.page_size_max`, as well as providing a corresponding linker
/// option.
///
/// The actual page size can only be determined at runtime with `pageSize`.
pub const page_size_max: usize = std.options.page_size_max orelse (page_size_max_default orelse if (builtin.os.tag == .freestanding or builtin.os.tag == .other)
    @compileError("freestanding/other page_size_max must provided with std.options.page_size_max")
else
    @compileError(@tagName(builtin.cpu.arch) ++ "-" ++ @tagName(builtin.os.tag) ++ " has unknown page_size_max; populate std.options.page_size_max"));

/// If the page size is comptime-known, return value is comptime.
/// Otherwise, calls `std.options.queryPageSize` which by default queries the
/// host operating system at runtime.
pub inline fn pageSize() usize {
    if (page_size_min == page_size_max) return page_size_min;
    return std.options.queryPageSize();
}

test pageSize {
    assert(std.math.isPowerOfTwo(pageSize()));
}

/// The default implementation of `std.options.queryPageSize`.
/// Asserts that the page size is within `page_size_min` and `page_size_max`
pub fn defaultQueryPageSize() usize {
    const global = struct {
        var cached_result: std.atomic.Value(usize) = .init(0);
    };
    var size = global.cached_result.load(.unordered);
    if (size > 0) return size;
    size = switch (builtin.os.tag) {
        .linux => if (builtin.link_libc) @intCast(std.c.sysconf(@intFromEnum(std.c._SC.PAGESIZE))) else std.os.linux.getauxval(std.elf.AT_PAGESZ),
        .driverkit, .ios, .macos, .tvos, .visionos, .watchos => blk: {
            const task_port = std.c.mach_task_self();
            // mach_task_self may fail "if there are any resource failures or other errors".
            if (task_port == std.c.TASK_NULL)
                break :blk 0;
            var info_count = std.c.TASK_VM_INFO_COUNT;
            var vm_info: std.c.task_vm_info_data_t = undefined;
            vm_info.page_size = 0;
            _ = std.c.task_info(
                task_port,
                std.c.TASK_VM_INFO,
                @as(std.c.task_info_t, @ptrCast(&vm_info)),
                &info_count,
            );
            assert(vm_info.page_size != 0);
            break :blk @intCast(vm_info.page_size);
        },
        .windows => blk: {
            var info: std.os.windows.SYSTEM_INFO = undefined;
            std.os.windows.kernel32.GetSystemInfo(&info);
            break :blk info.dwPageSize;
        },
        else => if (builtin.link_libc)
            @intCast(std.c.sysconf(@intFromEnum(std.c._SC.PAGESIZE)))
        else if (builtin.os.tag == .freestanding or builtin.os.tag == .other)
            @compileError("unsupported target: freestanding/other")
        else
            @compileError("pageSize on " ++ @tagName(builtin.cpu.arch) ++ "-" ++ @tagName(builtin.os.tag) ++ " is not supported without linking libc, using the default implementation"),
    };

    assert(size >= page_size_min);
    assert(size <= page_size_max);
    global.cached_result.store(size, .unordered);

    return size;
}

test defaultQueryPageSize {
    if (builtin.cpu.arch.isWasm()) return error.SkipZigTest;
    assert(std.math.isPowerOfTwo(defaultQueryPageSize()));
}

const CAllocator = struct {
    comptime {
        if (!builtin.link_libc) {
            @compileError("C allocator is only available when linking against libc");
        }
    }

    const vtable: Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

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
        return @alignCast(@ptrCast(ptr - @sizeOf(usize)));
    }

    fn alignedAlloc(len: usize, alignment: mem.Alignment) ?[*]u8 {
        const alignment_bytes = alignment.toByteUnits();
        if (supports_posix_memalign) {
            // The posix_memalign only accepts alignment values that are a
            // multiple of the pointer size
            const effective_alignment = @max(alignment_bytes, @sizeOf(usize));

            var aligned_ptr: ?*anyopaque = undefined;
            if (c.posix_memalign(&aligned_ptr, effective_alignment, len) != 0)
                return null;

            return @ptrCast(aligned_ptr);
        }

        // Thin wrapper around regular malloc, overallocate to account for
        // alignment padding and store the original malloc()'ed pointer before
        // the aligned address.
        const unaligned_ptr = @as([*]u8, @ptrCast(c.malloc(len + alignment_bytes - 1 + @sizeOf(usize)) orelse return null));
        const unaligned_addr = @intFromPtr(unaligned_ptr);
        const aligned_addr = mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment_bytes);
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
        alignment: mem.Alignment,
        return_address: usize,
    ) ?[*]u8 {
        _ = return_address;
        assert(len > 0);
        return alignedAlloc(len, alignment);
    }

    fn resize(
        _: *anyopaque,
        buf: []u8,
        alignment: mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) bool {
        _ = alignment;
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

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) ?[*]u8 {
        // realloc would potentially return a new allocation that does not
        // respect the original alignment.
        return if (resize(context, memory, alignment, new_len, return_address)) memory.ptr else null;
    }

    fn free(
        _: *anyopaque,
        buf: []u8,
        alignment: mem.Alignment,
        return_address: usize,
    ) void {
        _ = alignment;
        _ = return_address;
        alignedFree(buf.ptr);
    }
};

/// Supports the full Allocator interface, including alignment, and exploiting
/// `malloc_usable_size` if available. For an allocator that directly calls
/// `malloc`/`free`, see `raw_c_allocator`.
pub const c_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &CAllocator.vtable,
};

/// Asserts allocations are within `@alignOf(std.c.max_align_t)` and directly
/// calls `malloc`/`free`. Does not attempt to utilize `malloc_usable_size`.
/// This allocator is safe to use as the backing allocator with
/// `ArenaAllocator` for example and is more optimal in such a case than
/// `c_allocator`.
pub const raw_c_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &raw_c_allocator_vtable,
};
const raw_c_allocator_vtable: Allocator.VTable = .{
    .alloc = rawCAlloc,
    .resize = rawCResize,
    .remap = rawCRemap,
    .free = rawCFree,
};

fn rawCAlloc(
    context: *anyopaque,
    len: usize,
    alignment: mem.Alignment,
    return_address: usize,
) ?[*]u8 {
    _ = context;
    _ = return_address;
    assert(alignment.compare(.lte, comptime .fromByteUnits(@alignOf(std.c.max_align_t))));
    // Note that this pointer cannot be aligncasted to max_align_t because if
    // len is < max_align_t then the alignment can be smaller. For example, if
    // max_align_t is 16, but the user requests 8 bytes, there is no built-in
    // type in C that is size 8 and has 16 byte alignment, so the alignment may
    // be 8 bytes rather than 16. Similarly if only 1 byte is requested, malloc
    // is allowed to return a 1-byte aligned pointer.
    return @ptrCast(c.malloc(len));
}

fn rawCResize(
    context: *anyopaque,
    memory: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    return_address: usize,
) bool {
    _ = context;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = return_address;
    return false;
}

fn rawCRemap(
    context: *anyopaque,
    memory: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    return_address: usize,
) ?[*]u8 {
    _ = context;
    _ = alignment;
    _ = return_address;
    return @ptrCast(c.realloc(memory.ptr, new_len));
}

fn rawCFree(
    context: *anyopaque,
    memory: []u8,
    alignment: mem.Alignment,
    return_address: usize,
) void {
    _ = context;
    _ = alignment;
    _ = return_address;
    c.free(memory.ptr);
}

/// On operating systems that support memory mapping, this allocator makes a
/// syscall directly for every allocation and free.
///
/// Otherwise, it falls back to the preferred singleton for the target.
///
/// Thread-safe.
pub const page_allocator: Allocator = if (@hasDecl(root, "os") and
    @hasDecl(root.os, "heap") and
    @hasDecl(root.os.heap, "page_allocator"))
    root.os.heap.page_allocator
else if (builtin.target.isWasm()) .{
    .ptr = undefined,
    .vtable = &WasmAllocator.vtable,
} else if (builtin.target.os.tag == .plan9) .{
    .ptr = undefined,
    .vtable = &SbrkAllocator(std.os.plan9.sbrk).vtable,
} else .{
    .ptr = undefined,
    .vtable = &PageAllocator.vtable,
};

pub const smp_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &SmpAllocator.vtable,
};

/// This allocator is fast, small, and specific to WebAssembly. In the future,
/// this will be the implementation automatically selected by
/// `GeneralPurposeAllocator` when compiling in `ReleaseSmall` mode for wasm32
/// and wasm64 architectures.
/// Until then, it is available here to play with.
pub const wasm_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &WasmAllocator.vtable,
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
                    .remap = remap,
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
            alignment: mem.Alignment,
            ra: usize,
        ) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return FixedBufferAllocator.alloc(&self.fixed_buffer_allocator, len, alignment, ra) orelse
                return self.fallback_allocator.rawAlloc(len, alignment, ra);
        }

        fn resize(
            ctx: *anyopaque,
            buf: []u8,
            alignment: mem.Alignment,
            new_len: usize,
            ra: usize,
        ) bool {
            const self: *Self = @ptrCast(@alignCast(ctx));
            if (self.fixed_buffer_allocator.ownsPtr(buf.ptr)) {
                return FixedBufferAllocator.resize(&self.fixed_buffer_allocator, buf, alignment, new_len, ra);
            } else {
                return self.fallback_allocator.rawResize(buf, alignment, new_len, ra);
            }
        }

        fn remap(
            context: *anyopaque,
            memory: []u8,
            alignment: mem.Alignment,
            new_len: usize,
            return_address: usize,
        ) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(context));
            if (self.fixed_buffer_allocator.ownsPtr(memory.ptr)) {
                return FixedBufferAllocator.remap(&self.fixed_buffer_allocator, memory, alignment, new_len, return_address);
            } else {
                return self.fallback_allocator.rawRemap(memory, alignment, new_len, return_address);
            }
        }

        fn free(
            ctx: *anyopaque,
            buf: []u8,
            alignment: mem.Alignment,
            ra: usize,
        ) void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            if (self.fixed_buffer_allocator.ownsPtr(buf.ptr)) {
                return FixedBufferAllocator.free(&self.fixed_buffer_allocator, buf, alignment, ra);
            } else {
                return self.fallback_allocator.rawFree(buf, alignment, ra);
            }
        }
    };
}

test c_allocator {
    if (builtin.link_libc) {
        try testAllocator(c_allocator);
        try testAllocatorAligned(c_allocator);
        try testAllocatorLargeAlignment(c_allocator);
        try testAllocatorAlignedShrink(c_allocator);
    }
}

test raw_c_allocator {
    if (builtin.link_libc) {
        try testAllocator(raw_c_allocator);
    }
}

test smp_allocator {
    if (builtin.single_threaded) return;
    try testAllocator(smp_allocator);
    try testAllocatorAligned(smp_allocator);
    try testAllocatorLargeAlignment(smp_allocator);
    try testAllocatorAlignedShrink(smp_allocator);
}

test PageAllocator {
    const allocator = page_allocator;
    try testAllocator(allocator);
    try testAllocatorAligned(allocator);
    if (!builtin.target.isWasm()) {
        try testAllocatorLargeAlignment(allocator);
        try testAllocatorAlignedShrink(allocator);
    }

    if (builtin.os.tag == .windows) {
        const slice = try allocator.alignedAlloc(u8, page_size_min, 128);
        slice[0] = 0x12;
        slice[127] = 0x34;
        allocator.free(slice);
    }
    {
        var buf = try allocator.alloc(u8, pageSize() + 1);
        defer allocator.free(buf);
        buf = try allocator.realloc(buf, 1); // shrink past the page boundary
    }
}

test ArenaAllocator {
    var arena_allocator = ArenaAllocator.init(page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    try testAllocator(allocator);
    try testAllocatorAligned(allocator);
    try testAllocatorLargeAlignment(allocator);
    try testAllocatorAlignedShrink(allocator);
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

    const large_align: usize = page_size_min / 2;

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

    const alloc_size = pageSize() * 2 + 50;
    var slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    defer allocator.free(slice);

    var stuff_to_free = std.ArrayList([]align(16) u8).init(debug_allocator);
    // On Windows, VirtualAlloc returns addresses aligned to a 64K boundary,
    // which is 16 pages, hence the 32. This test may require to increase
    // the size of the allocations feeding the `allocator` parameter if they
    // fail, because of this high over-alignment we want to have.
    while (@intFromPtr(slice.ptr) == mem.alignForward(usize, @intFromPtr(slice.ptr), pageSize() * 32)) {
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

const page_size_min_default: ?usize = switch (builtin.os.tag) {
    .driverkit, .ios, .macos, .tvos, .visionos, .watchos => switch (builtin.cpu.arch) {
        .x86_64 => 4 << 10,
        .aarch64 => 16 << 10,
        else => null,
    },
    .windows => switch (builtin.cpu.arch) {
        // -- <https://devblogs.microsoft.com/oldnewthing/20210510-00/?p=105200>
        .x86, .x86_64 => 4 << 10,
        // SuperH => 4 << 10,
        .mips, .mipsel, .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => 4 << 10,
        // DEC Alpha => 8 << 10,
        // Itanium => 8 << 10,
        .thumb, .thumbeb, .arm, .armeb, .aarch64, .aarch64_be => 4 << 10,
        else => null,
    },
    .wasi => switch (builtin.cpu.arch) {
        .wasm32, .wasm64 => 64 << 10,
        else => null,
    },
    // https://github.com/tianocore/edk2/blob/b158dad150bf02879668f72ce306445250838201/MdePkg/Include/Uefi/UefiBaseType.h#L180-L187
    .uefi => 4 << 10,
    .freebsd => switch (builtin.cpu.arch) {
        // FreeBSD/sys/*
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .riscv32, .riscv64 => 4 << 10,
        else => null,
    },
    .netbsd => switch (builtin.cpu.arch) {
        // NetBSD/sys/arch/*
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .mips, .mipsel, .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .sparc => 4 << 10,
        .sparc64 => 8 << 10,
        .riscv32, .riscv64 => 4 << 10,
        // Sun-2
        .m68k => 2 << 10,
        else => null,
    },
    .dragonfly => switch (builtin.cpu.arch) {
        .x86, .x86_64 => 4 << 10,
        else => null,
    },
    .openbsd => switch (builtin.cpu.arch) {
        // OpenBSD/sys/arch/*
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb, .aarch64, .aarch64_be => 4 << 10,
        .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .riscv64 => 4 << 10,
        .sparc64 => 8 << 10,
        else => null,
    },
    .solaris, .illumos => switch (builtin.cpu.arch) {
        // src/uts/*/sys/machparam.h
        .x86, .x86_64 => 4 << 10,
        .sparc, .sparc64 => 8 << 10,
        else => null,
    },
    .fuchsia => switch (builtin.cpu.arch) {
        // fuchsia/kernel/arch/*/include/arch/defines.h
        .x86_64 => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .riscv64 => 4 << 10,
        else => null,
    },
    // https://github.com/SerenityOS/serenity/blob/62b938b798dc009605b5df8a71145942fc53808b/Kernel/API/POSIX/sys/limits.h#L11-L13
    .serenity => 4 << 10,
    .haiku => switch (builtin.cpu.arch) {
        // haiku/headers/posix/arch/*/limits.h
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .m68k => 4 << 10,
        .mips, .mipsel, .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .riscv64 => 4 << 10,
        .sparc64 => 8 << 10,
        .x86, .x86_64 => 4 << 10,
        else => null,
    },
    .hurd => switch (builtin.cpu.arch) {
        // gnumach/*/include/mach/*/vm_param.h
        .x86, .x86_64 => 4 << 10,
        .aarch64 => null,
        else => null,
    },
    .plan9 => switch (builtin.cpu.arch) {
        // 9front/sys/src/9/*/mem.h
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .mips, .mipsel, .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => 4 << 10,
        .sparc => 4 << 10,
        else => null,
    },
    .ps3 => switch (builtin.cpu.arch) {
        // cell/SDK_doc/en/html/C_and_C++_standard_libraries/stdlib.html
        .powerpc64 => 1 << 20, // 1 MiB
        else => null,
    },
    .ps4 => switch (builtin.cpu.arch) {
        // https://github.com/ps4dev/ps4sdk/blob/4df9d001b66ae4ec07d9a51b62d1e4c5e270eecc/include/machine/param.h#L95
        .x86, .x86_64 => 4 << 10,
        else => null,
    },
    .ps5 => switch (builtin.cpu.arch) {
        // https://github.com/PS5Dev/PS5SDK/blob/a2e03a2a0231a3a3397fa6cd087a01ca6d04f273/include/machine/param.h#L95
        .x86, .x86_64 => 16 << 10,
        else => null,
    },
    // system/lib/libc/musl/arch/emscripten/bits/limits.h
    .emscripten => 64 << 10,
    .linux => switch (builtin.cpu.arch) {
        // Linux/arch/*/Kconfig
        .arc => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .csky => 4 << 10,
        .hexagon => 4 << 10,
        .loongarch32, .loongarch64 => 4 << 10,
        .m68k => 4 << 10,
        .mips, .mipsel, .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .riscv32, .riscv64 => 4 << 10,
        .s390x => 4 << 10,
        .sparc => 4 << 10,
        .sparc64 => 8 << 10,
        .x86, .x86_64 => 4 << 10,
        .xtensa => 4 << 10,
        else => null,
    },
    .freestanding => switch (builtin.cpu.arch) {
        .wasm32, .wasm64 => 64 << 10,
        else => null,
    },
    else => null,
};

const page_size_max_default: ?usize = switch (builtin.os.tag) {
    .driverkit, .ios, .macos, .tvos, .visionos, .watchos => switch (builtin.cpu.arch) {
        .x86_64 => 4 << 10,
        .aarch64 => 16 << 10,
        else => null,
    },
    .windows => switch (builtin.cpu.arch) {
        // -- <https://devblogs.microsoft.com/oldnewthing/20210510-00/?p=105200>
        .x86, .x86_64 => 4 << 10,
        // SuperH => 4 << 10,
        .mips, .mipsel, .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => 4 << 10,
        // DEC Alpha => 8 << 10,
        // Itanium => 8 << 10,
        .thumb, .thumbeb, .arm, .armeb, .aarch64, .aarch64_be => 4 << 10,
        else => null,
    },
    .wasi => switch (builtin.cpu.arch) {
        .wasm32, .wasm64 => 64 << 10,
        else => null,
    },
    // https://github.com/tianocore/edk2/blob/b158dad150bf02879668f72ce306445250838201/MdePkg/Include/Uefi/UefiBaseType.h#L180-L187
    .uefi => 4 << 10,
    .freebsd => switch (builtin.cpu.arch) {
        // FreeBSD/sys/*
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .riscv32, .riscv64 => 4 << 10,
        else => null,
    },
    .netbsd => switch (builtin.cpu.arch) {
        // NetBSD/sys/arch/*
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 64 << 10,
        .mips, .mipsel, .mips64, .mips64el => 16 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 16 << 10,
        .sparc => 8 << 10,
        .sparc64 => 8 << 10,
        .riscv32, .riscv64 => 4 << 10,
        .m68k => 8 << 10,
        else => null,
    },
    .dragonfly => switch (builtin.cpu.arch) {
        .x86, .x86_64 => 4 << 10,
        else => null,
    },
    .openbsd => switch (builtin.cpu.arch) {
        // OpenBSD/sys/arch/*
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb, .aarch64, .aarch64_be => 4 << 10,
        .mips64, .mips64el => 16 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .riscv64 => 4 << 10,
        .sparc64 => 8 << 10,
        else => null,
    },
    .solaris, .illumos => switch (builtin.cpu.arch) {
        // src/uts/*/sys/machparam.h
        .x86, .x86_64 => 4 << 10,
        .sparc, .sparc64 => 8 << 10,
        else => null,
    },
    .fuchsia => switch (builtin.cpu.arch) {
        // fuchsia/kernel/arch/*/include/arch/defines.h
        .x86_64 => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .riscv64 => 4 << 10,
        else => null,
    },
    // https://github.com/SerenityOS/serenity/blob/62b938b798dc009605b5df8a71145942fc53808b/Kernel/API/POSIX/sys/limits.h#L11-L13
    .serenity => 4 << 10,
    .haiku => switch (builtin.cpu.arch) {
        // haiku/headers/posix/arch/*/limits.h
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 4 << 10,
        .m68k => 4 << 10,
        .mips, .mipsel, .mips64, .mips64el => 4 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 4 << 10,
        .riscv64 => 4 << 10,
        .sparc64 => 8 << 10,
        .x86, .x86_64 => 4 << 10,
        else => null,
    },
    .hurd => switch (builtin.cpu.arch) {
        // gnumach/*/include/mach/*/vm_param.h
        .x86, .x86_64 => 4 << 10,
        .aarch64 => null,
        else => null,
    },
    .plan9 => switch (builtin.cpu.arch) {
        // 9front/sys/src/9/*/mem.h
        .x86, .x86_64 => 4 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 64 << 10,
        .mips, .mipsel, .mips64, .mips64el => 16 << 10,
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => 4 << 10,
        .sparc => 4 << 10,
        else => null,
    },
    .ps3 => switch (builtin.cpu.arch) {
        // cell/SDK_doc/en/html/C_and_C++_standard_libraries/stdlib.html
        .powerpc64 => 1 << 20, // 1 MiB
        else => null,
    },
    .ps4 => switch (builtin.cpu.arch) {
        // https://github.com/ps4dev/ps4sdk/blob/4df9d001b66ae4ec07d9a51b62d1e4c5e270eecc/include/machine/param.h#L95
        .x86, .x86_64 => 4 << 10,
        else => null,
    },
    .ps5 => switch (builtin.cpu.arch) {
        // https://github.com/PS5Dev/PS5SDK/blob/a2e03a2a0231a3a3397fa6cd087a01ca6d04f273/include/machine/param.h#L95
        .x86, .x86_64 => 16 << 10,
        else => null,
    },
    // system/lib/libc/musl/arch/emscripten/bits/limits.h
    .emscripten => 64 << 10,
    .linux => switch (builtin.cpu.arch) {
        // Linux/arch/*/Kconfig
        .arc => 16 << 10,
        .thumb, .thumbeb, .arm, .armeb => 4 << 10,
        .aarch64, .aarch64_be => 64 << 10,
        .csky => 4 << 10,
        .hexagon => 256 << 10,
        .loongarch32, .loongarch64 => 64 << 10,
        .m68k => 8 << 10,
        .mips, .mipsel, .mips64, .mips64el => 64 << 10,
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => 256 << 10,
        .riscv32, .riscv64 => 4 << 10,
        .s390x => 4 << 10,
        .sparc => 4 << 10,
        .sparc64 => 8 << 10,
        .x86, .x86_64 => 4 << 10,
        .xtensa => 4 << 10,
        else => null,
    },
    .freestanding => switch (builtin.cpu.arch) {
        .wasm32, .wasm64 => 64 << 10,
        else => null,
    },
    else => null,
};

test {
    _ = @import("heap/memory_pool.zig");
    _ = ArenaAllocator;
    _ = GeneralPurposeAllocator;
    _ = FixedBufferAllocator;
    _ = ThreadSafeAllocator;
    if (builtin.target.isWasm()) {
        _ = WasmAllocator;
    }
    if (!builtin.single_threaded) _ = smp_allocator;
}
