//! The standard memory allocation interface.

const std = @import("../std.zig");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = @This();
const builtin = @import("builtin");

pub const Error = error{OutOfMemory};
pub const Log2Align = math.Log2Int(usize);

// The type erased pointer to the allocator implementation
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Attempt to allocate exactly `len` bytes aligned to `1 << ptr_align`.
    ///
    /// `ret_addr` is optionally provided as the first return address of the
    /// allocation call stack. If the value is `0` it means no return address
    /// has been provided.
    alloc: *const fn (ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8,

    /// Attempt to expand or shrink memory in place. `buf.len` must equal the
    /// length requested from the most recent successful call to `alloc` or
    /// `resize`. `buf_align` must equal the same value that was passed as the
    /// `ptr_align` parameter to the original `alloc` call.
    ///
    /// A result of `true` indicates the resize was successful and the
    /// allocation now has the same address but a size of `new_len`. `false`
    /// indicates the resize could not be completed without moving the
    /// allocation to a different address.
    ///
    /// `new_len` must be greater than zero.
    ///
    /// `ret_addr` is optionally provided as the first return address of the
    /// allocation call stack. If the value is `0` it means no return address
    /// has been provided.
    resize: *const fn (ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool,

    /// Free and invalidate a buffer.
    ///
    /// `buf.len` must equal the most recent length returned by `alloc` or
    /// given to a successful `resize` call.
    ///
    /// `buf_align` must equal the same value that was passed as the
    /// `ptr_align` parameter to the original `alloc` call.
    ///
    /// `ret_addr` is optionally provided as the first return address of the
    /// allocation call stack. If the value is `0` it means no return address
    /// has been provided.
    free: *const fn (ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void,
};

pub fn noResize(
    self: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = self;
    _ = buf;
    _ = log2_buf_align;
    _ = new_len;
    _ = ret_addr;
    return false;
}

pub fn noFree(
    self: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    ret_addr: usize,
) void {
    _ = self;
    _ = buf;
    _ = log2_buf_align;
    _ = ret_addr;
}

/// This function is not intended to be called except from within the
/// implementation of an Allocator
pub inline fn rawAlloc(self: Allocator, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
    return self.vtable.alloc(self.ptr, len, ptr_align, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an Allocator
pub inline fn rawResize(self: Allocator, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
    return self.vtable.resize(self.ptr, buf, log2_buf_align, new_len, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an Allocator
pub inline fn rawFree(self: Allocator, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
    return self.vtable.free(self.ptr, buf, log2_buf_align, ret_addr);
}

/// Returns a pointer to undefined memory.
/// Call `destroy` with the result to free the memory.
pub fn create(self: Allocator, comptime T: type) Error!*T {
    if (@sizeOf(T) == 0) return @as(*T, @ptrFromInt(math.maxInt(usize)));
    const ptr: *T = @ptrCast(try self.allocBytesWithAlignment(@alignOf(T), @sizeOf(T), @returnAddress()));
    return ptr;
}

/// `ptr` should be the return value of `create`, or otherwise
/// have the same address and alignment property.
pub fn destroy(self: Allocator, ptr: anytype) void {
    const info = @typeInfo(@TypeOf(ptr)).Pointer;
    if (info.size != .One) @compileError("ptr must be a single item pointer");
    const T = info.child;
    if (@sizeOf(T) == 0) return;
    const non_const_ptr = @as([*]u8, @ptrCast(@constCast(ptr)));
    self.rawFree(non_const_ptr[0..@sizeOf(T)], log2a(info.alignment), @returnAddress());
}

/// Allocates an array of `n` items of type `T` and sets all the
/// items to `undefined`. Depending on the Allocator
/// implementation, it may be required to call `free` once the
/// memory is no longer needed, to avoid a resource leak. If the
/// `Allocator` implementation is unknown, then correct code will
/// call `free` when done.
///
/// For allocating a single item, see `create`.
pub fn alloc(self: Allocator, comptime T: type, n: usize) Error![]T {
    return self.allocAdvancedWithRetAddr(T, null, n, @returnAddress());
}

pub fn allocWithOptions(
    self: Allocator,
    comptime Elem: type,
    n: usize,
    /// null means naturally aligned
    comptime optional_alignment: ?u29,
    comptime optional_sentinel: ?Elem,
) Error!AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
    return self.allocWithOptionsRetAddr(Elem, n, optional_alignment, optional_sentinel, @returnAddress());
}

pub fn allocWithOptionsRetAddr(
    self: Allocator,
    comptime Elem: type,
    n: usize,
    /// null means naturally aligned
    comptime optional_alignment: ?u29,
    comptime optional_sentinel: ?Elem,
    return_address: usize,
) Error!AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
    if (optional_sentinel) |sentinel| {
        const ptr = try self.allocAdvancedWithRetAddr(Elem, optional_alignment, n + 1, return_address);
        ptr[n] = sentinel;
        return ptr[0..n :sentinel];
    } else {
        return self.allocAdvancedWithRetAddr(Elem, optional_alignment, n, return_address);
    }
}

fn AllocWithOptionsPayload(comptime Elem: type, comptime alignment: ?u29, comptime sentinel: ?Elem) type {
    if (sentinel) |s| {
        return [:s]align(alignment orelse @alignOf(Elem)) Elem;
    } else {
        return []align(alignment orelse @alignOf(Elem)) Elem;
    }
}

/// Allocates an array of `n + 1` items of type `T` and sets the first `n`
/// items to `undefined` and the last item to `sentinel`. Depending on the
/// Allocator implementation, it may be required to call `free` once the
/// memory is no longer needed, to avoid a resource leak. If the
/// `Allocator` implementation is unknown, then correct code will
/// call `free` when done.
///
/// For allocating a single item, see `create`.
pub fn allocSentinel(
    self: Allocator,
    comptime Elem: type,
    n: usize,
    comptime sentinel: Elem,
) Error![:sentinel]Elem {
    return self.allocWithOptionsRetAddr(Elem, n, null, sentinel, @returnAddress());
}

pub fn alignedAlloc(
    self: Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?u29,
    n: usize,
) Error![]align(alignment orelse @alignOf(T)) T {
    return self.allocAdvancedWithRetAddr(T, alignment, n, @returnAddress());
}

pub inline fn allocAdvancedWithRetAddr(
    self: Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?u29,
    n: usize,
    return_address: usize,
) Error![]align(alignment orelse @alignOf(T)) T {
    const a = alignment orelse @alignOf(T);
    const ptr: [*]align(a) T = @ptrCast(try self.allocWithSizeAndAlignment(@sizeOf(T), a, n, return_address));
    return ptr[0..n];
}

fn allocWithSizeAndAlignment(self: Allocator, comptime size: usize, comptime alignment: u29, n: usize, return_address: usize) Error![*]align(alignment) u8 {
    const byte_count = math.mul(usize, size, n) catch return Error.OutOfMemory;
    return self.allocBytesWithAlignment(alignment, byte_count, return_address);
}

fn allocBytesWithAlignment(self: Allocator, comptime alignment: u29, byte_count: usize, return_address: usize) Error![*]align(alignment) u8 {
    // The Zig Allocator interface is not intended to solve alignments beyond
    // the minimum OS page size. For these use cases, the caller must use OS
    // APIs directly.
    comptime assert(alignment <= mem.page_size);

    if (byte_count == 0) {
        const ptr = comptime std.mem.alignBackward(usize, math.maxInt(usize), alignment);
        return @as([*]align(alignment) u8, @ptrFromInt(ptr));
    }

    const byte_ptr = self.rawAlloc(byte_count, log2a(alignment), return_address) orelse return Error.OutOfMemory;
    // TODO: https://github.com/ziglang/zig/issues/4298
    @memset(byte_ptr[0..byte_count], undefined);
    return @as([*]align(alignment) u8, @alignCast(byte_ptr));
}

/// Requests to modify the size of an allocation. It is guaranteed to not move
/// the pointer, however the allocator implementation may refuse the resize
/// request by returning `false`.
pub fn resize(self: Allocator, old_mem: anytype, new_n: usize) bool {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    const T = Slice.child;
    if (new_n == 0) {
        self.free(old_mem);
        return true;
    }
    if (old_mem.len == 0) {
        return false;
    }
    const old_byte_slice = mem.sliceAsBytes(old_mem);
    // I would like to use saturating multiplication here, but LLVM cannot lower it
    // on WebAssembly: https://github.com/ziglang/zig/issues/9660
    //const new_byte_count = new_n *| @sizeOf(T);
    const new_byte_count = math.mul(usize, @sizeOf(T), new_n) catch return false;
    return self.rawResize(old_byte_slice, log2a(Slice.alignment), new_byte_count, @returnAddress());
}

/// This function requests a new byte size for an existing allocation, which
/// can be larger, smaller, or the same size as the old memory allocation.
/// If `new_n` is 0, this is the same as `free` and it always succeeds.
pub fn realloc(self: Allocator, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    break :t Error![]align(Slice.alignment) Slice.child;
} {
    return self.reallocAdvanced(old_mem, new_n, @returnAddress());
}

pub fn reallocAdvanced(
    self: Allocator,
    old_mem: anytype,
    new_n: usize,
    return_address: usize,
) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    break :t Error![]align(Slice.alignment) Slice.child;
} {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    const T = Slice.child;
    if (old_mem.len == 0) {
        return self.allocAdvancedWithRetAddr(T, Slice.alignment, new_n, return_address);
    }
    if (new_n == 0) {
        self.free(old_mem);
        const ptr = comptime std.mem.alignBackward(usize, math.maxInt(usize), Slice.alignment);
        return @as([*]align(Slice.alignment) T, @ptrFromInt(ptr))[0..0];
    }

    const old_byte_slice = mem.sliceAsBytes(old_mem);
    const byte_count = math.mul(usize, @sizeOf(T), new_n) catch return Error.OutOfMemory;
    // Note: can't set shrunk memory to undefined as memory shouldn't be modified on realloc failure
    if (mem.isAligned(@intFromPtr(old_byte_slice.ptr), Slice.alignment)) {
        if (self.rawResize(old_byte_slice, log2a(Slice.alignment), byte_count, return_address)) {
            const new_bytes: []align(Slice.alignment) u8 = @alignCast(old_byte_slice.ptr[0..byte_count]);
            return mem.bytesAsSlice(T, new_bytes);
        }
    }

    const new_mem = self.rawAlloc(byte_count, log2a(Slice.alignment), return_address) orelse
        return error.OutOfMemory;
    const copy_len = @min(byte_count, old_byte_slice.len);
    @memcpy(new_mem[0..copy_len], old_byte_slice[0..copy_len]);
    // TODO https://github.com/ziglang/zig/issues/4298
    @memset(old_byte_slice, undefined);
    self.rawFree(old_byte_slice, log2a(Slice.alignment), return_address);

    const new_bytes: []align(Slice.alignment) u8 = @alignCast(new_mem[0..byte_count]);
    return mem.bytesAsSlice(T, new_bytes);
}

/// Free an array allocated with `alloc`. To free a single item,
/// see `destroy`.
pub fn free(self: Allocator, memory: anytype) void {
    const Slice = @typeInfo(@TypeOf(memory)).Pointer;
    const bytes = mem.sliceAsBytes(memory);
    const bytes_len = bytes.len + if (Slice.sentinel != null) @sizeOf(Slice.child) else 0;
    if (bytes_len == 0) return;
    const non_const_ptr = @constCast(bytes.ptr);
    // TODO: https://github.com/ziglang/zig/issues/4298
    @memset(non_const_ptr[0..bytes_len], undefined);
    self.rawFree(non_const_ptr[0..bytes_len], log2a(Slice.alignment), @returnAddress());
}

/// Copies `m` to newly allocated memory. Caller owns the memory.
pub fn dupe(allocator: Allocator, comptime T: type, m: []const T) Error![]T {
    const new_buf = try allocator.alloc(T, m.len);
    @memcpy(new_buf, m);
    return new_buf;
}

/// Copies `m` to newly allocated memory, with a null-terminated element. Caller owns the memory.
pub fn dupeZ(allocator: Allocator, comptime T: type, m: []const T) Error![:0]T {
    const new_buf = try allocator.alloc(T, m.len + 1);
    @memcpy(new_buf[0..m.len], m);
    new_buf[m.len] = 0;
    return new_buf[0..m.len :0];
}

/// TODO replace callsites with `@log2` after this proposal is implemented:
/// https://github.com/ziglang/zig/issues/13642
inline fn log2a(x: anytype) switch (@typeInfo(@TypeOf(x))) {
    .Int => math.Log2Int(@TypeOf(x)),
    .ComptimeInt => comptime_int,
    else => @compileError("int please"),
} {
    switch (@typeInfo(@TypeOf(x))) {
        .Int => return math.log2_int(@TypeOf(x), x),
        .ComptimeInt => return math.log2(x),
        else => @compileError("bad"),
    }
}
