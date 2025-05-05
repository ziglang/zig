//! The standard memory allocation interface.

const std = @import("../std.zig");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = @This();
const builtin = @import("builtin");
const Alignment = std.mem.Alignment;

pub const Error = error{OutOfMemory};
pub const Log2Align = math.Log2Int(usize);

/// The type erased pointer to the allocator implementation.
///
/// Any comparison of this field may result in illegal behavior, since it may
/// be set to `undefined` in cases where the allocator implementation does not
/// have any associated state.
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Return a pointer to `len` bytes with specified `alignment`, or return
    /// `null` indicating the allocation failed.
    ///
    /// `ret_addr` is optionally provided as the first return address of the
    /// allocation call stack. If the value is `0` it means no return address
    /// has been provided.
    alloc: *const fn (*anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8,

    /// Attempt to expand or shrink memory in place.
    ///
    /// `memory.len` must equal the length requested from the most recent
    /// successful call to `alloc`, `resize`, or `remap`. `alignment` must
    /// equal the same value that was passed as the `alignment` parameter to
    /// the original `alloc` call.
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
    resize: *const fn (*anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool,

    /// Attempt to expand or shrink memory, allowing relocation.
    ///
    /// `memory.len` must equal the length requested from the most recent
    /// successful call to `alloc`, `resize`, or `remap`. `alignment` must
    /// equal the same value that was passed as the `alignment` parameter to
    /// the original `alloc` call.
    ///
    /// A non-`null` return value indicates the resize was successful. The
    /// allocation may have same address, or may have been relocated. In either
    /// case, the allocation now has size of `new_len`. A `null` return value
    /// indicates that the resize would be equivalent to allocating new memory,
    /// copying the bytes from the old memory, and then freeing the old memory.
    /// In such case, it is more efficient for the caller to perform the copy.
    ///
    /// `new_len` must be greater than zero.
    ///
    /// `ret_addr` is optionally provided as the first return address of the
    /// allocation call stack. If the value is `0` it means no return address
    /// has been provided.
    remap: *const fn (*anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8,

    /// Free and invalidate a region of memory.
    ///
    /// `memory.len` must equal the length requested from the most recent
    /// successful call to `alloc`, `resize`, or `remap`. `alignment` must
    /// equal the same value that was passed as the `alignment` parameter to
    /// the original `alloc` call.
    ///
    /// `ret_addr` is optionally provided as the first return address of the
    /// allocation call stack. If the value is `0` it means no return address
    /// has been provided.
    free: *const fn (*anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void,
};

pub fn noResize(
    self: *anyopaque,
    memory: []u8,
    alignment: Alignment,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = ret_addr;
    return false;
}

pub fn noRemap(
    self: *anyopaque,
    memory: []u8,
    alignment: Alignment,
    new_len: usize,
    ret_addr: usize,
) ?[*]u8 {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = ret_addr;
    return null;
}

pub fn noFree(
    self: *anyopaque,
    memory: []u8,
    alignment: Alignment,
    ret_addr: usize,
) void {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = ret_addr;
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawAlloc(a: Allocator, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
    return a.vtable.alloc(a.ptr, len, alignment, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawResize(a: Allocator, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
    return a.vtable.resize(a.ptr, memory, alignment, new_len, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawRemap(a: Allocator, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    return a.vtable.remap(a.ptr, memory, alignment, new_len, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawFree(a: Allocator, memory: []u8, alignment: Alignment, ret_addr: usize) void {
    return a.vtable.free(a.ptr, memory, alignment, ret_addr);
}

/// Returns a pointer to undefined memory.
/// Call `destroy` with the result to free the memory.
pub fn create(a: Allocator, comptime T: type) Error!*T {
    if (@sizeOf(T) == 0) {
        const ptr = comptime std.mem.alignBackward(usize, math.maxInt(usize), @alignOf(T));
        return @ptrFromInt(ptr);
    }
    const ptr: *T = @ptrCast(try a.allocBytesWithAlignment(.of(T), @sizeOf(T), @returnAddress()));
    return ptr;
}

/// `ptr` should be the return value of `create`, or otherwise
/// have the same address and alignment property.
pub fn destroy(self: Allocator, ptr: anytype) void {
    const info = @typeInfo(@TypeOf(ptr)).pointer;
    if (info.size != .one) @compileError("ptr must be a single item pointer");
    const T = info.child;
    if (@sizeOf(T) == 0) return;
    const non_const_ptr = @as([*]u8, @ptrCast(@constCast(ptr)));
    self.rawFree(non_const_ptr[0..@sizeOf(T)], .fromByteUnits(info.alignment), @returnAddress());
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
    comptime optional_alignment: ?Alignment,
    comptime optional_sentinel: ?Elem,
) Error!AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
    return self.allocWithOptionsRetAddr(Elem, n, optional_alignment, optional_sentinel, @returnAddress());
}

pub fn allocWithOptionsRetAddr(
    self: Allocator,
    comptime Elem: type,
    n: usize,
    /// null means naturally aligned
    comptime optional_alignment: ?Alignment,
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

fn AllocWithOptionsPayload(comptime Elem: type, comptime alignment: ?Alignment, comptime sentinel: ?Elem) type {
    if (sentinel) |s| {
        return [:s]align(if (alignment) |a| a.toByteUnits() else @alignOf(Elem)) Elem;
    } else {
        return []align(if (alignment) |a| a.toByteUnits() else @alignOf(Elem)) Elem;
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
    comptime alignment: ?Alignment,
    n: usize,
) Error![]align(if (alignment) |a| a.toByteUnits() else @alignOf(T)) T {
    return self.allocAdvancedWithRetAddr(T, alignment, n, @returnAddress());
}

pub inline fn allocAdvancedWithRetAddr(
    self: Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?Alignment,
    n: usize,
    return_address: usize,
) Error![]align(if (alignment) |a| a.toByteUnits() else @alignOf(T)) T {
    const a = comptime (alignment orelse Alignment.fromByteUnits(@alignOf(T)));
    const ptr: [*]align(a.toByteUnits()) T = @ptrCast(try self.allocWithSizeAndAlignment(@sizeOf(T), a, n, return_address));
    return ptr[0..n];
}

fn allocWithSizeAndAlignment(
    self: Allocator,
    comptime size: usize,
    comptime alignment: Alignment,
    n: usize,
    return_address: usize,
) Error![*]align(alignment.toByteUnits()) u8 {
    const byte_count = math.mul(usize, size, n) catch return Error.OutOfMemory;
    return self.allocBytesWithAlignment(alignment, byte_count, return_address);
}

fn allocBytesWithAlignment(
    self: Allocator,
    comptime alignment: Alignment,
    byte_count: usize,
    return_address: usize,
) Error![*]align(alignment.toByteUnits()) u8 {
    if (byte_count == 0) {
        const ptr = comptime alignment.backward(math.maxInt(usize));
        return @as([*]align(alignment.toByteUnits()) u8, @ptrFromInt(ptr));
    }

    const byte_ptr = self.rawAlloc(byte_count, alignment, return_address) orelse return Error.OutOfMemory;
    @memset(byte_ptr[0..byte_count], undefined);
    return @alignCast(byte_ptr);
}

/// Request to modify the size of an allocation.
///
/// It is guaranteed to not move the pointer, however the allocator
/// implementation may refuse the resize request by returning `false`.
///
/// `allocation` may be an empty slice, in which case a new allocation is made.
///
/// `new_len` may be zero, in which case the allocation is freed.
pub fn resize(self: Allocator, allocation: anytype, new_len: usize) bool {
    const Slice = @typeInfo(@TypeOf(allocation)).pointer;
    const T = Slice.child;
    const alignment = Slice.alignment;
    if (new_len == 0) {
        self.free(allocation);
        return true;
    }
    if (allocation.len == 0) {
        return false;
    }
    const old_memory = mem.sliceAsBytes(allocation);
    // I would like to use saturating multiplication here, but LLVM cannot lower it
    // on WebAssembly: https://github.com/ziglang/zig/issues/9660
    //const new_len_bytes = new_len *| @sizeOf(T);
    const new_len_bytes = math.mul(usize, @sizeOf(T), new_len) catch return false;
    return self.rawResize(old_memory, .fromByteUnits(alignment), new_len_bytes, @returnAddress());
}

/// Request to modify the size of an allocation, allowing relocation.
///
/// A non-`null` return value indicates the resize was successful. The
/// allocation may have same address, or may have been relocated. In either
/// case, the allocation now has size of `new_len`. A `null` return value
/// indicates that the resize would be equivalent to allocating new memory,
/// copying the bytes from the old memory, and then freeing the old memory.
/// In such case, it is more efficient for the caller to perform those
/// operations.
///
/// `allocation` may be an empty slice, in which case `null` is returned,
/// unless `new_len` is also 0, in which case `allocation` is returned.
///
/// `new_len` may be zero, in which case the allocation is freed.
///
/// If the allocation's elements' type is zero bytes sized, `allocation.len` is set to `new_len`.
pub fn remap(self: Allocator, allocation: anytype, new_len: usize) t: {
    const Slice = @typeInfo(@TypeOf(allocation)).pointer;
    break :t ?[]align(Slice.alignment) Slice.child;
} {
    const Slice = @typeInfo(@TypeOf(allocation)).pointer;
    const T = Slice.child;

    const alignment = Slice.alignment;
    if (new_len == 0) {
        self.free(allocation);
        return allocation[0..0];
    }
    if (allocation.len == 0) {
        return null;
    }
    if (@sizeOf(T) == 0) {
        var new_memory = allocation;
        new_memory.len = new_len;
        return new_memory;
    }
    const old_memory = mem.sliceAsBytes(allocation);
    // I would like to use saturating multiplication here, but LLVM cannot lower it
    // on WebAssembly: https://github.com/ziglang/zig/issues/9660
    //const new_len_bytes = new_len *| @sizeOf(T);
    const new_len_bytes = math.mul(usize, @sizeOf(T), new_len) catch return null;
    const new_ptr = self.rawRemap(old_memory, .fromByteUnits(alignment), new_len_bytes, @returnAddress()) orelse return null;
    const new_memory: []align(alignment) u8 = @alignCast(new_ptr[0..new_len_bytes]);
    return mem.bytesAsSlice(T, new_memory);
}

/// This function requests a new byte size for an existing allocation, which
/// can be larger, smaller, or the same size as the old memory allocation.
///
/// If `new_n` is 0, this is the same as `free` and it always succeeds.
///
/// `old_mem` may have length zero, which makes a new allocation.
///
/// This function only fails on out-of-memory conditions, unlike:
/// * `remap` which returns `null` when the `Allocator` implementation cannot
///   do the realloc more efficiently than the caller
/// * `resize` which returns `false` when the `Allocator` implementation cannot
///   change the size without relocating the allocation.
pub fn realloc(self: Allocator, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
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
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    break :t Error![]align(Slice.alignment) Slice.child;
} {
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    const T = Slice.child;
    if (old_mem.len == 0) {
        return self.allocAdvancedWithRetAddr(T, .fromByteUnits(Slice.alignment), new_n, return_address);
    }
    if (new_n == 0) {
        self.free(old_mem);
        const ptr = comptime std.mem.alignBackward(usize, math.maxInt(usize), Slice.alignment);
        return @as([*]align(Slice.alignment) T, @ptrFromInt(ptr))[0..0];
    }

    const old_byte_slice = mem.sliceAsBytes(old_mem);
    const byte_count = math.mul(usize, @sizeOf(T), new_n) catch return Error.OutOfMemory;
    // Note: can't set shrunk memory to undefined as memory shouldn't be modified on realloc failure
    if (self.rawRemap(old_byte_slice, .fromByteUnits(Slice.alignment), byte_count, return_address)) |p| {
        const new_bytes: []align(Slice.alignment) u8 = @alignCast(p[0..byte_count]);
        return mem.bytesAsSlice(T, new_bytes);
    }

    const new_mem = self.rawAlloc(byte_count, .fromByteUnits(Slice.alignment), return_address) orelse
        return error.OutOfMemory;
    const copy_len = @min(byte_count, old_byte_slice.len);
    @memcpy(new_mem[0..copy_len], old_byte_slice[0..copy_len]);
    @memset(old_byte_slice, undefined);
    self.rawFree(old_byte_slice, .fromByteUnits(Slice.alignment), return_address);

    const new_bytes: []align(Slice.alignment) u8 = @alignCast(new_mem[0..byte_count]);
    return mem.bytesAsSlice(T, new_bytes);
}

/// Free an array allocated with `alloc`.
/// If memory has length 0, free is a no-op.
/// To free a single item, see `destroy`.
pub fn free(self: Allocator, memory: anytype) void {
    const Slice = @typeInfo(@TypeOf(memory)).pointer;
    const bytes = mem.sliceAsBytes(memory);
    const bytes_len = bytes.len + if (Slice.sentinel() != null) @sizeOf(Slice.child) else 0;
    if (bytes_len == 0) return;
    const non_const_ptr = @constCast(bytes.ptr);
    @memset(non_const_ptr[0..bytes_len], undefined);
    self.rawFree(non_const_ptr[0..bytes_len], .fromByteUnits(Slice.alignment), @returnAddress());
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
