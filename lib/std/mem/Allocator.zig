//! The standard memory allocation interface.

const std = @import("../std.zig");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = @This();
const builtin = @import("builtin");

pub const Error = error{OutOfMemory};

// The type erased pointer to the allocator implementation
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Attempt to allocate at least `len` bytes aligned to `ptr_align`.
    ///
    /// If `len_align` is `0`, then the length returned MUST be exactly `len` bytes,
    /// otherwise, the length must be aligned to `len_align`.
    ///
    /// `len` must be greater than or equal to `len_align` and must be aligned by `len_align`.
    ///
    /// `ret_addr` is optionally provided as the first return address of the allocation call stack.
    /// If the value is `0` it means no return address has been provided.
    alloc: fn (ptr: *anyopaque, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Error![]u8,

    /// Attempt to expand or shrink memory in place. `buf.len` must equal the most recent
    /// length returned by `alloc` or `resize`. `buf_align` must equal the same value
    /// that was passed as the `ptr_align` parameter to the original `alloc` call.
    ///
    /// `null` can only be returned if `new_len` is greater than `buf.len`.
    /// If `buf` cannot be expanded to accomodate `new_len`, then the allocation MUST be
    /// unmodified and `null` MUST be returned.
    ///
    /// If `len_align` is `0`, then the length returned MUST be exactly `len` bytes,
    /// otherwise, the length must be aligned to `len_align`. Note that `len_align` does *not*
    /// provide a way to modify the alignment of a pointer. Rather it provides an API for
    /// accepting more bytes of memory from the allocator than requested.
    ///
    /// `new_len` must be greater than zero, greater than or equal to `len_align` and must be aligned by `len_align`.
    ///
    /// `ret_addr` is optionally provided as the first return address of the allocation call stack.
    /// If the value is `0` it means no return address has been provided.
    resize: fn (ptr: *anyopaque, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize,

    /// Free and invalidate a buffer. `buf.len` must equal the most recent length returned by `alloc` or `resize`. 
    /// `buf_align` must equal the same value that was passed as the `ptr_align` parameter to the original `alloc` call.
    ///
    /// `ret_addr` is optionally provided as the first return address of the allocation call stack.
    /// If the value is `0` it means no return address has been provided.
    free: fn (ptr: *anyopaque, buf: []u8, buf_align: u29, ret_addr: usize) void,
};

pub fn init(
    pointer: anytype,
    comptime allocFn: fn (ptr: @TypeOf(pointer), len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Error![]u8,
    comptime resizeFn: fn (ptr: @TypeOf(pointer), buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize,
    comptime freeFn: fn (ptr: @TypeOf(pointer), buf: []u8, buf_align: u29, ret_addr: usize) void,
) Allocator {
    const Ptr = @TypeOf(pointer);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer); // Must be a pointer
    assert(ptr_info.Pointer.size == .One); // Must be a single-item pointer

    const alignment = ptr_info.Pointer.alignment;

    const gen = struct {
        fn allocImpl(ptr: *anyopaque, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Error![]u8 {
            const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
            return @call(.{ .modifier = .always_inline }, allocFn, .{ self, len, ptr_align, len_align, ret_addr });
        }
        fn resizeImpl(ptr: *anyopaque, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize {
            assert(new_len != 0);
            const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
            return @call(.{ .modifier = .always_inline }, resizeFn, .{ self, buf, buf_align, new_len, len_align, ret_addr });
        }
        fn freeImpl(ptr: *anyopaque, buf: []u8, buf_align: u29, ret_addr: usize) void {
            const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
            @call(.{ .modifier = .always_inline }, freeFn, .{ self, buf, buf_align, ret_addr });
        }

        const vtable = VTable{
            .alloc = allocImpl,
            .resize = resizeImpl,
            .free = freeImpl,
        };
    };

    return .{
        .ptr = pointer,
        .vtable = &gen.vtable,
    };
}

/// Set resizeFn to `NoResize(AllocatorType).noResize` if in-place resize is not supported.
pub fn NoResize(comptime AllocatorType: type) type {
    return struct {
        pub fn noResize(
            self: *AllocatorType,
            buf: []u8,
            buf_align: u29,
            new_len: usize,
            len_align: u29,
            ret_addr: usize,
        ) ?usize {
            _ = self;
            _ = buf_align;
            _ = len_align;
            _ = ret_addr;
            return if (new_len > buf.len) null else new_len;
        }
    };
}

/// Set freeFn to `NoOpFree(AllocatorType).noOpFree` if free is a no-op.
pub fn NoOpFree(comptime AllocatorType: type) type {
    return struct {
        pub fn noOpFree(
            self: *AllocatorType,
            buf: []u8,
            buf_align: u29,
            ret_addr: usize,
        ) void {
            _ = self;
            _ = buf;
            _ = buf_align;
            _ = ret_addr;
        }
    };
}

/// Set freeFn to `PanicFree(AllocatorType).noOpFree` if free is not a supported operation.
pub fn PanicFree(comptime AllocatorType: type) type {
    return struct {
        pub fn noOpFree(
            self: *AllocatorType,
            buf: []u8,
            buf_align: u29,
            ret_addr: usize,
        ) void {
            _ = self;
            _ = buf;
            _ = buf_align;
            _ = ret_addr;
            @panic("free is not a supported operation for the allocator: " ++ @typeName(AllocatorType));
        }
    };
}

/// This function is not intended to be called except from within the implementation of an Allocator
pub inline fn rawAlloc(self: Allocator, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Error![]u8 {
    return self.vtable.alloc(self.ptr, len, ptr_align, len_align, ret_addr);
}

/// This function is not intended to be called except from within the implementation of an Allocator
pub inline fn rawResize(self: Allocator, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize {
    return self.vtable.resize(self.ptr, buf, buf_align, new_len, len_align, ret_addr);
}

/// This function is not intended to be called except from within the implementation of an Allocator
pub inline fn rawFree(self: Allocator, buf: []u8, buf_align: u29, ret_addr: usize) void {
    return self.vtable.free(self.ptr, buf, buf_align, ret_addr);
}

/// Returns a pointer to undefined memory.
/// Call `destroy` with the result to free the memory.
pub fn create(self: Allocator, comptime T: type) Error!*T {
    if (@sizeOf(T) == 0) return @as(*T, undefined);
    const slice = try self.allocAdvancedWithRetAddr(T, null, 1, .exact, @returnAddress());
    return &slice[0];
}

/// `ptr` should be the return value of `create`, or otherwise
/// have the same address and alignment property.
pub fn destroy(self: Allocator, ptr: anytype) void {
    const info = @typeInfo(@TypeOf(ptr)).Pointer;
    const T = info.child;
    if (@sizeOf(T) == 0) return;
    const non_const_ptr = @intToPtr([*]u8, @ptrToInt(ptr));
    self.rawFree(non_const_ptr[0..@sizeOf(T)], info.alignment, @returnAddress());
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
    return self.allocAdvancedWithRetAddr(T, null, n, .exact, @returnAddress());
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
        const ptr = try self.allocAdvancedWithRetAddr(Elem, optional_alignment, n + 1, .exact, return_address);
        ptr[n] = sentinel;
        return ptr[0..n :sentinel];
    } else {
        return self.allocAdvancedWithRetAddr(Elem, optional_alignment, n, .exact, return_address);
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
    return self.allocAdvancedWithRetAddr(T, alignment, n, .exact, @returnAddress());
}

pub fn allocAdvanced(
    self: Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?u29,
    n: usize,
    exact: Exact,
) Error![]align(alignment orelse @alignOf(T)) T {
    return self.allocAdvancedWithRetAddr(T, alignment, n, exact, @returnAddress());
}

pub const Exact = enum { exact, at_least };

pub fn allocAdvancedWithRetAddr(
    self: Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?u29,
    n: usize,
    exact: Exact,
    return_address: usize,
) Error![]align(alignment orelse @alignOf(T)) T {
    const a = if (alignment) |a| blk: {
        if (a == @alignOf(T)) return allocAdvancedWithRetAddr(self, T, null, n, exact, return_address);
        break :blk a;
    } else @alignOf(T);

    if (n == 0) {
        return @as([*]align(a) T, undefined)[0..0];
    }

    const byte_count = math.mul(usize, @sizeOf(T), n) catch return Error.OutOfMemory;
    // TODO The `if (alignment == null)` blocks are workarounds for zig not being able to
    // access certain type information about T without creating a circular dependency in async
    // functions that heap-allocate their own frame with @Frame(func).
    const size_of_T = if (alignment == null) @intCast(u29, @divExact(byte_count, n)) else @sizeOf(T);
    const len_align: u29 = switch (exact) {
        .exact => 0,
        .at_least => size_of_T,
    };
    const byte_slice = try self.rawAlloc(byte_count, a, len_align, return_address);
    switch (exact) {
        .exact => assert(byte_slice.len == byte_count),
        .at_least => assert(byte_slice.len >= byte_count),
    }
    // TODO: https://github.com/ziglang/zig/issues/4298
    @memset(byte_slice.ptr, undefined, byte_slice.len);
    if (alignment == null) {
        // This if block is a workaround (see comment above)
        return @intToPtr([*]T, @ptrToInt(byte_slice.ptr))[0..@divExact(byte_slice.len, @sizeOf(T))];
    } else {
        return mem.bytesAsSlice(T, @alignCast(a, byte_slice));
    }
}

/// Increases or decreases the size of an allocation. It is guaranteed to not move the pointer.
pub fn resize(self: Allocator, old_mem: anytype, new_n: usize) ?@TypeOf(old_mem) {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    const T = Slice.child;
    if (new_n == 0) {
        self.free(old_mem);
        return &[0]T{};
    }
    const old_byte_slice = mem.sliceAsBytes(old_mem);
    const new_byte_count = math.mul(usize, @sizeOf(T), new_n) catch return null;
    const rc = self.rawResize(old_byte_slice, Slice.alignment, new_byte_count, 0, @returnAddress()) orelse return null;
    assert(rc == new_byte_count);
    const new_byte_slice = old_byte_slice.ptr[0..new_byte_count];
    return mem.bytesAsSlice(T, new_byte_slice);
}

/// This function requests a new byte size for an existing allocation,
/// which can be larger, smaller, or the same size as the old memory
/// allocation.
/// This function is preferred over `shrink`, because it can fail, even
/// when shrinking. This gives the allocator a chance to perform a
/// cheap shrink operation if possible, or otherwise return OutOfMemory,
/// indicating that the caller should keep their capacity, for example
/// in `std.ArrayList.shrink`.
/// If you need guaranteed success, call `shrink`.
/// If `new_n` is 0, this is the same as `free` and it always succeeds.
pub fn realloc(self: Allocator, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    break :t Error![]align(Slice.alignment) Slice.child;
} {
    const old_alignment = @typeInfo(@TypeOf(old_mem)).Pointer.alignment;
    return self.reallocAdvancedWithRetAddr(old_mem, old_alignment, new_n, .exact, @returnAddress());
}

pub fn reallocAtLeast(self: Allocator, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    break :t Error![]align(Slice.alignment) Slice.child;
} {
    const old_alignment = @typeInfo(@TypeOf(old_mem)).Pointer.alignment;
    return self.reallocAdvancedWithRetAddr(old_mem, old_alignment, new_n, .at_least, @returnAddress());
}

/// This is the same as `realloc`, except caller may additionally request
/// a new alignment, which can be larger, smaller, or the same as the old
/// allocation.
pub fn reallocAdvanced(
    self: Allocator,
    old_mem: anytype,
    comptime new_alignment: u29,
    new_n: usize,
    exact: Exact,
) Error![]align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
    return self.reallocAdvancedWithRetAddr(old_mem, new_alignment, new_n, exact, @returnAddress());
}

pub fn reallocAdvancedWithRetAddr(
    self: Allocator,
    old_mem: anytype,
    comptime new_alignment: u29,
    new_n: usize,
    exact: Exact,
    return_address: usize,
) Error![]align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    const T = Slice.child;
    if (old_mem.len == 0) {
        return self.allocAdvancedWithRetAddr(T, new_alignment, new_n, exact, return_address);
    }
    if (new_n == 0) {
        self.free(old_mem);
        return @as([*]align(new_alignment) T, undefined)[0..0];
    }

    const old_byte_slice = mem.sliceAsBytes(old_mem);
    const byte_count = math.mul(usize, @sizeOf(T), new_n) catch return Error.OutOfMemory;
    // Note: can't set shrunk memory to undefined as memory shouldn't be modified on realloc failure
    const len_align: u29 = switch (exact) {
        .exact => 0,
        .at_least => @sizeOf(T),
    };

    if (mem.isAligned(@ptrToInt(old_byte_slice.ptr), new_alignment)) {
        if (byte_count <= old_byte_slice.len) {
            const shrunk_len = self.shrinkBytes(old_byte_slice, Slice.alignment, byte_count, len_align, return_address);
            return mem.bytesAsSlice(T, @alignCast(new_alignment, old_byte_slice.ptr[0..shrunk_len]));
        }

        if (self.rawResize(old_byte_slice, Slice.alignment, byte_count, len_align, return_address)) |resized_len| {
            // TODO: https://github.com/ziglang/zig/issues/4298
            @memset(old_byte_slice.ptr + byte_count, undefined, resized_len - byte_count);
            return mem.bytesAsSlice(T, @alignCast(new_alignment, old_byte_slice.ptr[0..resized_len]));
        }
    }

    if (byte_count <= old_byte_slice.len and new_alignment <= Slice.alignment) {
        return error.OutOfMemory;
    }

    const new_mem = try self.rawAlloc(byte_count, new_alignment, len_align, return_address);
    @memcpy(new_mem.ptr, old_byte_slice.ptr, math.min(byte_count, old_byte_slice.len));
    // TODO https://github.com/ziglang/zig/issues/4298
    @memset(old_byte_slice.ptr, undefined, old_byte_slice.len);
    self.rawFree(old_byte_slice, Slice.alignment, return_address);

    return mem.bytesAsSlice(T, @alignCast(new_alignment, new_mem));
}

/// Prefer calling realloc to shrink if you can tolerate failure, such as
/// in an ArrayList data structure with a storage capacity.
/// Shrink always succeeds, and `new_n` must be <= `old_mem.len`.
/// Returned slice has same alignment as old_mem.
/// Shrinking to 0 is the same as calling `free`.
pub fn shrink(self: Allocator, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    break :t []align(Slice.alignment) Slice.child;
} {
    const old_alignment = @typeInfo(@TypeOf(old_mem)).Pointer.alignment;
    return self.alignedShrinkWithRetAddr(old_mem, old_alignment, new_n, @returnAddress());
}

/// This is the same as `shrink`, except caller may additionally request
/// a new alignment, which must be smaller or the same as the old
/// allocation.
pub fn alignedShrink(
    self: Allocator,
    old_mem: anytype,
    comptime new_alignment: u29,
    new_n: usize,
) []align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
    return self.alignedShrinkWithRetAddr(old_mem, new_alignment, new_n, @returnAddress());
}

/// This is the same as `alignedShrink`, except caller may additionally pass
/// the return address of the first stack frame, which may be relevant for
/// allocators which collect stack traces.
pub fn alignedShrinkWithRetAddr(
    self: Allocator,
    old_mem: anytype,
    comptime new_alignment: u29,
    new_n: usize,
    return_address: usize,
) []align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    const T = Slice.child;

    if (new_n == old_mem.len)
        return old_mem;
    if (new_n == 0) {
        self.free(old_mem);
        return @as([*]align(new_alignment) T, undefined)[0..0];
    }

    assert(new_n < old_mem.len);
    assert(new_alignment <= Slice.alignment);

    // Here we skip the overflow checking on the multiplication because
    // new_n <= old_mem.len and the multiplication didn't overflow for that operation.
    const byte_count = @sizeOf(T) * new_n;

    const old_byte_slice = mem.sliceAsBytes(old_mem);
    // TODO: https://github.com/ziglang/zig/issues/4298
    @memset(old_byte_slice.ptr + byte_count, undefined, old_byte_slice.len - byte_count);
    _ = self.shrinkBytes(old_byte_slice, Slice.alignment, byte_count, 0, return_address);
    return old_mem[0..new_n];
}

/// Free an array allocated with `alloc`. To free a single item,
/// see `destroy`.
pub fn free(self: Allocator, memory: anytype) void {
    const Slice = @typeInfo(@TypeOf(memory)).Pointer;
    const bytes = mem.sliceAsBytes(memory);
    const bytes_len = bytes.len + if (Slice.sentinel != null) @sizeOf(Slice.child) else 0;
    if (bytes_len == 0) return;
    const non_const_ptr = @intToPtr([*]u8, @ptrToInt(bytes.ptr));
    // TODO: https://github.com/ziglang/zig/issues/4298
    @memset(non_const_ptr, undefined, bytes_len);
    self.rawFree(non_const_ptr[0..bytes_len], Slice.alignment, @returnAddress());
}

/// Copies `m` to newly allocated memory. Caller owns the memory.
pub fn dupe(allocator: Allocator, comptime T: type, m: []const T) ![]T {
    const new_buf = try allocator.alloc(T, m.len);
    mem.copy(T, new_buf, m);
    return new_buf;
}

/// Copies `m` to newly allocated memory, with a null-terminated element. Caller owns the memory.
pub fn dupeZ(allocator: Allocator, comptime T: type, m: []const T) ![:0]T {
    const new_buf = try allocator.alloc(T, m.len + 1);
    mem.copy(T, new_buf, m);
    new_buf[m.len] = 0;
    return new_buf[0..m.len :0];
}

/// This function allows a runtime `alignment` value. Callers should generally prefer
/// to call the `alloc*` functions.
pub fn allocBytes(
    self: Allocator,
    /// Must be >= 1.
    /// Must be a power of 2.
    /// Returned slice's pointer will have this alignment.
    alignment: u29,
    byte_count: usize,
    /// 0 indicates the length of the slice returned MUST match `byte_count` exactly
    /// non-zero means the length of the returned slice must be aligned by `len_align`
    /// `byte_count` must be aligned by `len_align`
    len_align: u29,
    return_address: usize,
) Error![]u8 {
    const new_mem = try self.rawAlloc(byte_count, alignment, len_align, return_address);
    // TODO: https://github.com/ziglang/zig/issues/4298
    @memset(new_mem.ptr, undefined, new_mem.len);
    return new_mem;
}

test "allocBytes" {
    const number_of_bytes: usize = 10;
    var runtime_alignment: u29 = 2;

    {
        const new_mem = try std.testing.allocator.allocBytes(runtime_alignment, number_of_bytes, 0, @returnAddress());
        defer std.testing.allocator.free(new_mem);

        try std.testing.expectEqual(number_of_bytes, new_mem.len);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }

    runtime_alignment = 8;

    {
        const new_mem = try std.testing.allocator.allocBytes(runtime_alignment, number_of_bytes, 0, @returnAddress());
        defer std.testing.allocator.free(new_mem);

        try std.testing.expectEqual(number_of_bytes, new_mem.len);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }
}

test "allocBytes non-zero len_align" {
    const number_of_bytes: usize = 10;
    var runtime_alignment: u29 = 1;
    var len_align: u29 = 2;

    {
        const new_mem = try std.testing.allocator.allocBytes(runtime_alignment, number_of_bytes, len_align, @returnAddress());
        defer std.testing.allocator.free(new_mem);

        try std.testing.expect(new_mem.len >= number_of_bytes);
        try std.testing.expect(new_mem.len % len_align == 0);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }

    runtime_alignment = 16;
    len_align = 5;

    {
        const new_mem = try std.testing.allocator.allocBytes(runtime_alignment, number_of_bytes, len_align, @returnAddress());
        defer std.testing.allocator.free(new_mem);

        try std.testing.expect(new_mem.len >= number_of_bytes);
        try std.testing.expect(new_mem.len % len_align == 0);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }
}

/// Realloc is used to modify the size or alignment of an existing allocation,
/// as well as to provide the allocator with an opportunity to move an allocation
/// to a better location.
/// The returned slice will have its pointer aligned at least to `new_alignment` bytes.
///
/// This function allows a runtime `alignment` value. Callers should generally prefer
/// to call the `realloc*` functions.
///
/// If the size/alignment is greater than the previous allocation, and the requested new
/// allocation could not be granted this function returns `error.OutOfMemory`.
/// When the size/alignment is less than or equal to the previous allocation,
/// this function returns `error.OutOfMemory` when the allocator decides the client
/// would be better off keeping the extra alignment/size. 
/// Clients will call `resizeFn` when they require the allocator to track a new alignment/size,
/// and so this function should only return success when the allocator considers
/// the reallocation desirable from the allocator's perspective.
///
/// As an example, `std.ArrayList` tracks a "capacity", and therefore can handle
/// reallocation failure, even when `new_n` <= `old_mem.len`. A `FixedBufferAllocator`
/// would always return `error.OutOfMemory` for `reallocFn` when the size/alignment
/// is less than or equal to the old allocation, because it cannot reclaim the memory,
/// and thus the `std.ArrayList` would be better off retaining its capacity.
pub fn reallocBytes(
    self: Allocator,
    /// Must be the same as what was returned from most recent call to `allocFn` or `resizeFn`.
    /// If `old_mem.len == 0` then this is a new allocation and `new_byte_count` must be >= 1.
    old_mem: []u8,
    /// If `old_mem.len == 0` then this is `undefined`, otherwise:
    /// Must be the same as what was passed to `allocFn`.
    /// Must be >= 1.
    /// Must be a power of 2.
    old_alignment: u29,
    /// If `new_byte_count` is 0 then this is a free and it is required that `old_mem.len != 0`.
    new_byte_count: usize,
    /// Must be >= 1.
    /// Must be a power of 2.
    /// Returned slice's pointer will have this alignment.
    new_alignment: u29,
    /// 0 indicates the length of the slice returned MUST match `new_byte_count` exactly
    /// non-zero means the length of the returned slice must be aligned by `len_align`
    /// `new_byte_count` must be aligned by `len_align`
    len_align: u29,
    return_address: usize,
) Error![]u8 {
    if (old_mem.len == 0) {
        return self.allocBytes(new_alignment, new_byte_count, len_align, return_address);
    }
    if (new_byte_count == 0) {
        // TODO https://github.com/ziglang/zig/issues/4298
        @memset(old_mem.ptr, undefined, old_mem.len);
        self.rawFree(old_mem, old_alignment, return_address);
        return &[0]u8{};
    }

    if (mem.isAligned(@ptrToInt(old_mem.ptr), new_alignment)) {
        if (new_byte_count <= old_mem.len) {
            const shrunk_len = self.shrinkBytes(old_mem, old_alignment, new_byte_count, len_align, return_address);
            return old_mem.ptr[0..shrunk_len];
        }

        if (self.rawResize(old_mem, old_alignment, new_byte_count, len_align, return_address)) |resized_len| {
            assert(resized_len >= new_byte_count);
            // TODO: https://github.com/ziglang/zig/issues/4298
            @memset(old_mem.ptr + new_byte_count, undefined, resized_len - new_byte_count);
            return old_mem.ptr[0..resized_len];
        }
    }

    if (new_byte_count <= old_mem.len and new_alignment <= old_alignment) {
        return error.OutOfMemory;
    }

    const new_mem = try self.rawAlloc(new_byte_count, new_alignment, len_align, return_address);
    @memcpy(new_mem.ptr, old_mem.ptr, math.min(new_byte_count, old_mem.len));

    // TODO https://github.com/ziglang/zig/issues/4298
    @memset(old_mem.ptr, undefined, old_mem.len);
    self.rawFree(old_mem, old_alignment, return_address);

    return new_mem;
}

test "reallocBytes" {
    var new_mem: []u8 = &.{};

    var new_byte_count: usize = 16;
    var runtime_alignment: u29 = 4;

    // `new_mem.len == 0`, this is a new allocation
    {
        new_mem = try std.testing.allocator.reallocBytes(new_mem, undefined, new_byte_count, runtime_alignment, 0, @returnAddress());
        try std.testing.expectEqual(new_byte_count, new_mem.len);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }

    // `new_byte_count < new_mem.len`, this is a shrink, alignment is unmodified
    new_byte_count = 14;
    {
        new_mem = try std.testing.allocator.reallocBytes(new_mem, runtime_alignment, new_byte_count, runtime_alignment, 0, @returnAddress());
        try std.testing.expectEqual(new_byte_count, new_mem.len);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }

    // `new_byte_count < new_mem.len`, this is a shrink, alignment is decreased from 4 to 2
    runtime_alignment = 2;
    new_byte_count = 12;
    {
        new_mem = try std.testing.allocator.reallocBytes(new_mem, 4, new_byte_count, runtime_alignment, 0, @returnAddress());
        try std.testing.expectEqual(new_byte_count, new_mem.len);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }

    // `new_byte_count > new_mem.len`, this is a growth, alignment is increased from 2 to 8
    runtime_alignment = 8;
    new_byte_count = 32;
    {
        new_mem = try std.testing.allocator.reallocBytes(new_mem, 2, new_byte_count, runtime_alignment, 0, @returnAddress());
        try std.testing.expectEqual(new_byte_count, new_mem.len);
        try std.testing.expect(mem.isAligned(@ptrToInt(new_mem.ptr), runtime_alignment));
    }

    // `new_byte_count == 0`, this is a free
    new_byte_count = 0;
    {
        new_mem = try std.testing.allocator.reallocBytes(new_mem, runtime_alignment, new_byte_count, runtime_alignment, 0, @returnAddress());
        try std.testing.expectEqual(new_byte_count, new_mem.len);
    }
}

/// Call `vtable.resize`, but caller guarantees that `new_len` <= `buf.len` meaning
/// than a `null` return value should be impossible.
/// This function allows a runtime `buf_align` value. Callers should generally prefer
/// to call `shrink`.
pub fn shrinkBytes(
    self: Allocator,
    /// Must be the same as what was returned from most recent call to `allocFn` or `resizeFn`.
    buf: []u8,
    /// Must be the same as what was passed to `allocFn`.
    /// Must be >= 1.
    /// Must be a power of 2.
    buf_align: u29,
    /// Must be >= 1.
    new_len: usize,
    /// 0 indicates the length of the slice returned MUST match `new_len` exactly
    /// non-zero means the length of the returned slice must be aligned by `len_align`
    /// `new_len` must be aligned by `len_align`
    len_align: u29,
    return_address: usize,
) usize {
    assert(new_len <= buf.len);
    return self.rawResize(buf, buf_align, new_len, len_align, return_address) orelse unreachable;
}
