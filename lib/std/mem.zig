const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const builtin = @import("builtin");
const mem = @This();
const meta = std.meta;
const trait = meta.trait;
const testing = std.testing;

// https://github.com/ziglang/zig/issues/2564
pub const page_size = switch (builtin.arch) {
    .wasm32, .wasm64 => 64 * 1024,
    else => 4 * 1024,
};

pub const Allocator = struct {
    pub const Error = error{OutOfMemory};

    /// Attempt to allocate at least `len` bytes aligned to `ptr_align`.
    ///
    /// If `len_align` is `0`, then the length returned MUST be exactly `len` bytes,
    /// otherwise, the length must be aligned to `len_align`.
    ///
    /// `len` must be greater than or equal to `len_align` and must be aligned by `len_align`.
    allocFn: fn (self: *Allocator, len: usize, ptr_align: u29, len_align: u29) Error![]u8,

    /// Attempt to expand or shrink memory in place. `buf.len` must equal the most recent
    /// length returned by `allocFn` or `resizeFn`.
    ///
    /// Passing a `new_len` of 0 frees and invalidates the buffer such that it can no
    /// longer be passed to `resizeFn`.
    ///
    /// error.OutOfMemory can only be returned if `new_len` is greater than `buf.len`.
    /// If `buf` cannot be expanded to accomodate `new_len`, then the allocation MUST be
    /// unmodified and error.OutOfMemory MUST be returned.
    ///
    /// If `len_align` is `0`, then the length returned MUST be exactly `len` bytes,
    /// otherwise, the length must be aligned to `len_align`.
    ///
    /// `new_len` must be greater than or equal to `len_align` and must be aligned by `len_align`.
    resizeFn: fn (self: *Allocator, buf: []u8, new_len: usize, len_align: u29) Error!usize,

    pub fn callAllocFn(self: *Allocator, new_len: usize, alignment: u29, len_align: u29) Error![]u8 {
        return self.allocFn(self, new_len, alignment, len_align);
    }

    pub fn callResizeFn(self: *Allocator, buf: []u8, new_len: usize, len_align: u29) Error!usize {
        return self.resizeFn(self, buf, new_len, len_align);
    }

    /// Set to resizeFn if in-place resize is not supported.
    pub fn noResize(self: *Allocator, buf: []u8, new_len: usize, len_align: u29) Error!usize {
        if (new_len > buf.len)
            return error.OutOfMemory;
        return new_len;
    }

    /// Call `resizeFn`, but caller guarantees that `new_len` <= `buf.len` meaning
    /// error.OutOfMemory should be impossible.
    pub fn shrinkBytes(self: *Allocator, buf: []u8, new_len: usize, len_align: u29) usize {
        assert(new_len <= buf.len);
        return self.callResizeFn(buf, new_len, len_align) catch unreachable;
    }

    /// Realloc is used to modify the size or alignment of an existing allocation,
    /// as well as to provide the allocator with an opportunity to move an allocation
    /// to a better location.
    /// When the size/alignment is greater than the previous allocation, this function
    /// returns `error.OutOfMemory` when the requested new allocation could not be granted.
    /// When the size/alignment is less than or equal to the previous allocation,
    /// this function returns `error.OutOfMemory` when the allocator decides the client
    /// would be better off keeping the extra alignment/size. Clients will call
    /// `callResizeFn` when they require the allocator to track a new alignment/size,
    /// and so this function should only return success when the allocator considers
    /// the reallocation desirable from the allocator's perspective.
    /// As an example, `std.ArrayList` tracks a "capacity", and therefore can handle
    /// reallocation failure, even when `new_n` <= `old_mem.len`. A `FixedBufferAllocator`
    /// would always return `error.OutOfMemory` for `reallocFn` when the size/alignment
    /// is less than or equal to the old allocation, because it cannot reclaim the memory,
    /// and thus the `std.ArrayList` would be better off retaining its capacity.
    /// When `reallocFn` returns,
    /// `return_value[0..min(old_mem.len, new_byte_count)]` must be the same
    /// as `old_mem` was when `reallocFn` is called. The bytes of
    /// `return_value[old_mem.len..]` have undefined values.
    /// The returned slice must have its pointer aligned at least to `new_alignment` bytes.
    fn reallocBytes(
        self: *Allocator,
        /// Guaranteed to be the same as what was returned from most recent call to
        /// `allocFn` or `resizeFn`.
        /// If `old_mem.len == 0` then this is a new allocation and `new_byte_count`
        /// is guaranteed to be >= 1.
        old_mem: []u8,
        /// If `old_mem.len == 0` then this is `undefined`, otherwise:
        /// Guaranteed to be the same as what was passed to `allocFn`.
        /// Guaranteed to be >= 1.
        /// Guaranteed to be a power of 2.
        old_alignment: u29,
        /// If `new_byte_count` is 0 then this is a free and it is guaranteed that
        /// `old_mem.len != 0`.
        new_byte_count: usize,
        /// Guaranteed to be >= 1.
        /// Guaranteed to be a power of 2.
        /// Returned slice's pointer must have this alignment.
        new_alignment: u29,
        /// 0 indicates the length of the slice returned MUST match `new_byte_count` exactly
        /// non-zero means the length of the returned slice must be aligned by `len_align`
        /// `new_len` must be aligned by `len_align`
        len_align: u29,
    ) Error![]u8 {
        if (old_mem.len == 0) {
            const new_mem = try self.callAllocFn(new_byte_count, new_alignment, len_align);
            @memset(new_mem.ptr, undefined, new_byte_count);
            return new_mem;
        }

        if (isAligned(@ptrToInt(old_mem.ptr), new_alignment)) {
            if (new_byte_count <= old_mem.len) {
                const shrunk_len = self.shrinkBytes(old_mem, new_byte_count, len_align);
                return old_mem.ptr[0..shrunk_len];
            }
            if (self.callResizeFn(old_mem, new_byte_count, len_align)) |resized_len| {
                assert(resized_len >= new_byte_count);
                @memset(old_mem.ptr + new_byte_count, undefined, resized_len - new_byte_count);
                return old_mem.ptr[0..resized_len];
            } else |_| {}
        }
        if (new_byte_count <= old_mem.len and new_alignment <= old_alignment) {
            return error.OutOfMemory;
        }
        return self.moveBytes(old_mem, new_byte_count, new_alignment, len_align);
    }

    /// Move the given memory to a new location in the given allocator to accomodate a new
    /// size and alignment.
    fn moveBytes(self: *Allocator, old_mem: []u8, new_len: usize, new_alignment: u29, len_align: u29) Error![]u8 {
        assert(old_mem.len > 0);
        assert(new_len > 0);
        const new_mem = try self.callAllocFn(new_len, new_alignment, len_align);
        @memcpy(new_mem.ptr, old_mem.ptr, std.math.min(new_len, old_mem.len));
        // DISABLED TO AVOID BUGS IN TRANSLATE C
        // use './zig build test-translate-c' to reproduce, some of the symbols in the
        // generated C code will be a sequence of 0xaa (the undefined value), meaning
        // it is printing data that has been freed
        //@memset(old_mem.ptr, undefined, old_mem.len);
        _ = self.shrinkBytes(old_mem, 0, 0);
        return new_mem;
    }

    /// Returns a pointer to undefined memory.
    /// Call `destroy` with the result to free the memory.
    pub fn create(self: *Allocator, comptime T: type) Error!*T {
        if (@sizeOf(T) == 0) return &(T{});
        const slice = try self.alloc(T, 1);
        return &slice[0];
    }

    /// `ptr` should be the return value of `create`, or otherwise
    /// have the same address and alignment property.
    pub fn destroy(self: *Allocator, ptr: anytype) void {
        const T = @TypeOf(ptr).Child;
        if (@sizeOf(T) == 0) return;
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(ptr));
        _ = self.shrinkBytes(non_const_ptr[0..@sizeOf(T)], 0, 0);
    }

    /// Allocates an array of `n` items of type `T` and sets all the
    /// items to `undefined`. Depending on the Allocator
    /// implementation, it may be required to call `free` once the
    /// memory is no longer needed, to avoid a resource leak. If the
    /// `Allocator` implementation is unknown, then correct code will
    /// call `free` when done.
    ///
    /// For allocating a single item, see `create`.
    pub fn alloc(self: *Allocator, comptime T: type, n: usize) Error![]T {
        return self.alignedAlloc(T, null, n);
    }

    pub fn allocWithOptions(
        self: *Allocator,
        comptime Elem: type,
        n: usize,
        /// null means naturally aligned
        comptime optional_alignment: ?u29,
        comptime optional_sentinel: ?Elem,
    ) Error!AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
        if (optional_sentinel) |sentinel| {
            const ptr = try self.alignedAlloc(Elem, optional_alignment, n + 1);
            ptr[n] = sentinel;
            return ptr[0..n :sentinel];
        } else {
            return self.alignedAlloc(Elem, optional_alignment, n);
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
    ///
    /// Deprecated; use `allocWithOptions`.
    pub fn allocSentinel(self: *Allocator, comptime Elem: type, n: usize, comptime sentinel: Elem) Error![:sentinel]Elem {
        return self.allocWithOptions(Elem, n, null, sentinel);
    }

    /// Deprecated: use `allocAdvanced`
    pub fn alignedAlloc(
        self: *Allocator,
        comptime T: type,
        /// null means naturally aligned
        comptime alignment: ?u29,
        n: usize,
    ) Error![]align(alignment orelse @alignOf(T)) T {
        return self.allocAdvanced(T, alignment, n, .exact);
    }

    const Exact = enum { exact, at_least };
    pub fn allocAdvanced(
        self: *Allocator,
        comptime T: type,
        /// null means naturally aligned
        comptime alignment: ?u29,
        n: usize,
        exact: Exact,
    ) Error![]align(alignment orelse @alignOf(T)) T {
        const a = if (alignment) |a| blk: {
            if (a == @alignOf(T)) return allocAdvanced(self, T, null, n, exact);
            break :blk a;
        } else @alignOf(T);

        if (n == 0) {
            return @as([*]align(a) T, undefined)[0..0];
        }

        const byte_count = math.mul(usize, @sizeOf(T), n) catch return Error.OutOfMemory;
        // TODO The `if (alignment == null)` blocks are workarounds for zig not being able to
        // access certain type information about T without creating a circular dependency in async
        // functions that heap-allocate their own frame with @Frame(func).
        const sizeOfT = if (alignment == null) @intCast(u29, @divExact(byte_count, n)) else @sizeOf(T);
        const byte_slice = try self.callAllocFn(byte_count, a, if (exact == .exact) @as(u29, 0) else sizeOfT);
        switch (exact) {
            .exact => assert(byte_slice.len == byte_count),
            .at_least => assert(byte_slice.len >= byte_count),
        }
        @memset(byte_slice.ptr, undefined, byte_slice.len);
        if (alignment == null) {
            // This if block is a workaround (see comment above)
            return @intToPtr([*]T, @ptrToInt(byte_slice.ptr))[0..@divExact(byte_slice.len, @sizeOf(T))];
        } else {
            return mem.bytesAsSlice(T, @alignCast(a, byte_slice));
        }
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
    pub fn realloc(self: *Allocator, old_mem: anytype, new_n: usize) t: {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        break :t Error![]align(Slice.alignment) Slice.child;
    } {
        const old_alignment = @typeInfo(@TypeOf(old_mem)).Pointer.alignment;
        return self.reallocAdvanced(old_mem, old_alignment, new_n, .exact);
    }

    pub fn reallocAtLeast(self: *Allocator, old_mem: anytype, new_n: usize) t: {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        break :t Error![]align(Slice.alignment) Slice.child;
    } {
        const old_alignment = @typeInfo(@TypeOf(old_mem)).Pointer.alignment;
        return self.reallocAdvanced(old_mem, old_alignment, new_n, .at_least);
    }

    // Deprecated: use `reallocAdvanced`
    pub fn alignedRealloc(
        self: *Allocator,
        old_mem: anytype,
        comptime new_alignment: u29,
        new_n: usize,
    ) Error![]align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
        return self.reallocAdvanced(old_mem, new_alignment, new_n, .exact);
    }

    /// This is the same as `realloc`, except caller may additionally request
    /// a new alignment, which can be larger, smaller, or the same as the old
    /// allocation.
    pub fn reallocAdvanced(
        self: *Allocator,
        old_mem: anytype,
        comptime new_alignment: u29,
        new_n: usize,
        exact: Exact,
    ) Error![]align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        const T = Slice.child;
        if (old_mem.len == 0) {
            return self.allocAdvanced(T, new_alignment, new_n, exact);
        }
        if (new_n == 0) {
            self.free(old_mem);
            return @as([*]align(new_alignment) T, undefined)[0..0];
        }

        const old_byte_slice = mem.sliceAsBytes(old_mem);
        const byte_count = math.mul(usize, @sizeOf(T), new_n) catch return Error.OutOfMemory;
        // Note: can't set shrunk memory to undefined as memory shouldn't be modified on realloc failure
        const new_byte_slice = try self.reallocBytes(old_byte_slice, Slice.alignment, byte_count, new_alignment, if (exact == .exact) @as(u29, 0) else @sizeOf(T));
        return mem.bytesAsSlice(T, @alignCast(new_alignment, new_byte_slice));
    }

    /// Prefer calling realloc to shrink if you can tolerate failure, such as
    /// in an ArrayList data structure with a storage capacity.
    /// Shrink always succeeds, and `new_n` must be <= `old_mem.len`.
    /// Returned slice has same alignment as old_mem.
    /// Shrinking to 0 is the same as calling `free`.
    pub fn shrink(self: *Allocator, old_mem: anytype, new_n: usize) t: {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        break :t []align(Slice.alignment) Slice.child;
    } {
        const old_alignment = @typeInfo(@TypeOf(old_mem)).Pointer.alignment;
        return self.alignedShrink(old_mem, old_alignment, new_n);
    }

    /// This is the same as `shrink`, except caller may additionally request
    /// a new alignment, which must be smaller or the same as the old
    /// allocation.
    pub fn alignedShrink(
        self: *Allocator,
        old_mem: anytype,
        comptime new_alignment: u29,
        new_n: usize,
    ) []align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        const T = Slice.child;

        if (new_n == old_mem.len)
            return old_mem;
        assert(new_n < old_mem.len);
        assert(new_alignment <= Slice.alignment);

        // Here we skip the overflow checking on the multiplication because
        // new_n <= old_mem.len and the multiplication didn't overflow for that operation.
        const byte_count = @sizeOf(T) * new_n;

        const old_byte_slice = mem.sliceAsBytes(old_mem);
        @memset(old_byte_slice.ptr + byte_count, undefined, old_byte_slice.len - byte_count);
        _ = self.shrinkBytes(old_byte_slice, byte_count, 0);
        return old_mem[0..new_n];
    }

    /// Free an array allocated with `alloc`. To free a single item,
    /// see `destroy`.
    pub fn free(self: *Allocator, memory: anytype) void {
        const Slice = @typeInfo(@TypeOf(memory)).Pointer;
        const bytes = mem.sliceAsBytes(memory);
        const bytes_len = bytes.len + if (Slice.sentinel != null) @sizeOf(Slice.child) else 0;
        if (bytes_len == 0) return;
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(bytes.ptr));
        @memset(non_const_ptr, undefined, bytes_len);
        _ = self.shrinkBytes(non_const_ptr[0..bytes_len], 0, 0);
    }

    /// Copies `m` to newly allocated memory. Caller owns the memory.
    pub fn dupe(allocator: *Allocator, comptime T: type, m: []const T) ![]T {
        const new_buf = try allocator.alloc(T, m.len);
        copy(T, new_buf, m);
        return new_buf;
    }

    /// Copies `m` to newly allocated memory, with a null-terminated element. Caller owns the memory.
    pub fn dupeZ(allocator: *Allocator, comptime T: type, m: []const T) ![:0]T {
        const new_buf = try allocator.alloc(T, m.len + 1);
        copy(T, new_buf, m);
        new_buf[m.len] = 0;
        return new_buf[0..m.len :0];
    }
};

/// Detects and asserts if the std.mem.Allocator interface is violated by the caller
/// or the allocator.
pub fn ValidationAllocator(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        underlying_allocator: T,
        pub fn init(allocator: T) @This() {
            return .{
                .allocator = .{
                    .allocFn = alloc,
                    .resizeFn = resize,
                },
                .underlying_allocator = allocator,
            };
        }
        fn getUnderlyingAllocatorPtr(self: *@This()) *Allocator {
            if (T == *Allocator) return self.underlying_allocator;
            if (*T == *Allocator) return &self.underlying_allocator;
            return &self.underlying_allocator.allocator;
        }
        pub fn alloc(allocator: *Allocator, n: usize, ptr_align: u29, len_align: u29) Allocator.Error![]u8 {
            assert(n > 0);
            assert(mem.isValidAlign(ptr_align));
            if (len_align != 0) {
                assert(mem.isAlignedAnyAlign(n, len_align));
                assert(n >= len_align);
            }

            const self = @fieldParentPtr(@This(), "allocator", allocator);
            const result = try self.getUnderlyingAllocatorPtr().callAllocFn(n, ptr_align, len_align);
            assert(mem.isAligned(@ptrToInt(result.ptr), ptr_align));
            if (len_align == 0) {
                assert(result.len == n);
            } else {
                assert(result.len >= n);
                assert(mem.isAlignedAnyAlign(result.len, len_align));
            }
            return result;
        }
        pub fn resize(allocator: *Allocator, buf: []u8, new_len: usize, len_align: u29) Allocator.Error!usize {
            assert(buf.len > 0);
            if (len_align != 0) {
                assert(mem.isAlignedAnyAlign(new_len, len_align));
                assert(new_len >= len_align);
            }
            const self = @fieldParentPtr(@This(), "allocator", allocator);
            const result = try self.getUnderlyingAllocatorPtr().callResizeFn(buf, new_len, len_align);
            if (len_align == 0) {
                assert(result == new_len);
            } else {
                assert(result >= new_len);
                assert(mem.isAlignedAnyAlign(result, len_align));
            }
            return result;
        }
        pub usingnamespace if (T == *Allocator or !@hasDecl(T, "reset")) struct {} else struct {
            pub fn reset(self: *Self) void {
                self.underlying_allocator.reset();
            }
        };
    };
}

pub fn validationWrap(allocator: anytype) ValidationAllocator(@TypeOf(allocator)) {
    return ValidationAllocator(@TypeOf(allocator)).init(allocator);
}

/// An allocator helper function.  Adjusts an allocation length satisfy `len_align`.
/// `full_len` should be the full capacity of the allocation which may be greater
/// than the `len` that was requsted.  This function should only be used by allocators
/// that are unaffected by `len_align`.
pub fn alignAllocLen(full_len: usize, alloc_len: usize, len_align: u29) usize {
    assert(alloc_len > 0);
    assert(alloc_len >= len_align);
    assert(full_len >= alloc_len);
    if (len_align == 0)
        return alloc_len;
    const adjusted = alignBackwardAnyAlign(full_len, len_align);
    assert(adjusted >= alloc_len);
    return adjusted;
}

var failAllocator = Allocator{
    .allocFn = failAllocatorAlloc,
    .resizeFn = Allocator.noResize,
};
fn failAllocatorAlloc(self: *Allocator, n: usize, alignment: u29, len_align: u29) Allocator.Error![]u8 {
    return error.OutOfMemory;
}

test "mem.Allocator basics" {
    testing.expectError(error.OutOfMemory, failAllocator.alloc(u8, 1));
    testing.expectError(error.OutOfMemory, failAllocator.allocSentinel(u8, 1, 0));
}

/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
/// dest.ptr must be <= src.ptr.
pub fn copy(comptime T: type, dest: []T, source: []const T) void {
    // TODO instead of manually doing this check for the whole array
    // and turning off runtime safety, the compiler should detect loops like
    // this and automatically omit safety checks for loops
    @setRuntimeSafety(false);
    assert(dest.len >= source.len);
    for (source) |s, i|
        dest[i] = s;
}

/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
/// dest.ptr must be >= src.ptr.
pub fn copyBackwards(comptime T: type, dest: []T, source: []const T) void {
    // TODO instead of manually doing this check for the whole array
    // and turning off runtime safety, the compiler should detect loops like
    // this and automatically omit safety checks for loops
    @setRuntimeSafety(false);
    assert(dest.len >= source.len);
    var i = source.len;
    while (i > 0) {
        i -= 1;
        dest[i] = source[i];
    }
}

/// Sets all elements of `dest` to `value`.
pub fn set(comptime T: type, dest: []T, value: T) void {
    for (dest) |*d|
        d.* = value;
}

/// Generally, Zig users are encouraged to explicitly initialize all fields of a struct explicitly rather than using this function.
/// However, it is recognized that there are sometimes use cases for initializing all fields to a "zero" value. For example, when
/// interfacing with a C API where this practice is more common and relied upon. If you are performing code review and see this
/// function used, examine closely - it may be a code smell.
/// Zero initializes the type.
/// This can be used to zero initialize a any type for which it makes sense. Structs will be initialized recursively.
pub fn zeroes(comptime T: type) T {
    switch (@typeInfo(T)) {
        .ComptimeInt, .Int, .ComptimeFloat, .Float => {
            return @as(T, 0);
        },
        .Enum, .EnumLiteral => {
            return @intToEnum(T, 0);
        },
        .Void => {
            return {};
        },
        .Bool => {
            return false;
        },
        .Optional, .Null => {
            return null;
        },
        .Struct => |struct_info| {
            if (@sizeOf(T) == 0) return T{};
            if (comptime meta.containerLayout(T) == .Extern) {
                var item: T = undefined;
                set(u8, asBytes(&item), 0);
                return item;
            } else {
                var structure: T = undefined;
                inline for (struct_info.fields) |field| {
                    @field(structure, field.name) = zeroes(@TypeOf(@field(structure, field.name)));
                }
                return structure;
            }
        },
        .Pointer => |ptr_info| {
            switch (ptr_info.size) {
                .Slice => {
                    return &[_]ptr_info.child{};
                },
                .C => {
                    return null;
                },
                .One, .Many => {
                    @compileError("Can't set a non nullable pointer to zero.");
                },
            }
        },
        .Array => |info| {
            if (info.sentinel) |sentinel| {
                return [_:sentinel]info.child{zeroes(info.child)} ** info.len;
            }
            return [_]info.child{zeroes(info.child)} ** info.len;
        },
        .Vector => |info| {
            return @splat(info.len, zeroes(info.child));
        },
        .ErrorUnion,
        .ErrorSet,
        .Union,
        .Fn,
        .BoundFn,
        .Type,
        .NoReturn,
        .Undefined,
        .Opaque,
        .Frame,
        .AnyFrame,
        => {
            @compileError("Can't set a " ++ @typeName(T) ++ " to zero.");
        },
    }
}

test "mem.zeroes" {
    const C_struct = extern struct {
        x: u32,
        y: u32,
    };

    var a = zeroes(C_struct);
    a.y += 10;

    testing.expect(a.x == 0);
    testing.expect(a.y == 10);

    const ZigStruct = struct {
        integral_types: struct {
            integer_0: i0,
            integer_8: i8,
            integer_16: i16,
            integer_32: i32,
            integer_64: i64,
            integer_128: i128,
            unsigned_0: u0,
            unsigned_8: u8,
            unsigned_16: u16,
            unsigned_32: u32,
            unsigned_64: u64,
            unsigned_128: u128,

            float_32: f32,
            float_64: f64,
        },

        pointers: struct {
            optional: ?*u8,
            c_pointer: [*c]u8,
            slice: []u8,
        },

        array: [2]u32,
        vector_u32: meta.Vector(2, u32),
        vector_f32: meta.Vector(2, f32),
        vector_bool: meta.Vector(2, bool),
        optional_int: ?u8,
        empty: void,
        sentinel: [3:0]u8,
    };

    const b = zeroes(ZigStruct);
    testing.expectEqual(@as(i8, 0), b.integral_types.integer_0);
    testing.expectEqual(@as(i8, 0), b.integral_types.integer_8);
    testing.expectEqual(@as(i16, 0), b.integral_types.integer_16);
    testing.expectEqual(@as(i32, 0), b.integral_types.integer_32);
    testing.expectEqual(@as(i64, 0), b.integral_types.integer_64);
    testing.expectEqual(@as(i128, 0), b.integral_types.integer_128);
    testing.expectEqual(@as(u8, 0), b.integral_types.unsigned_0);
    testing.expectEqual(@as(u8, 0), b.integral_types.unsigned_8);
    testing.expectEqual(@as(u16, 0), b.integral_types.unsigned_16);
    testing.expectEqual(@as(u32, 0), b.integral_types.unsigned_32);
    testing.expectEqual(@as(u64, 0), b.integral_types.unsigned_64);
    testing.expectEqual(@as(u128, 0), b.integral_types.unsigned_128);
    testing.expectEqual(@as(f32, 0), b.integral_types.float_32);
    testing.expectEqual(@as(f64, 0), b.integral_types.float_64);
    testing.expectEqual(@as(?*u8, null), b.pointers.optional);
    testing.expectEqual(@as([*c]u8, null), b.pointers.c_pointer);
    testing.expectEqual(@as([]u8, &[_]u8{}), b.pointers.slice);
    for (b.array) |e| {
        testing.expectEqual(@as(u32, 0), e);
    }
    testing.expectEqual(@splat(2, @as(u32, 0)), b.vector_u32);
    testing.expectEqual(@splat(2, @as(f32, 0.0)), b.vector_f32);
    testing.expectEqual(@splat(2, @as(bool, false)), b.vector_bool);
    testing.expectEqual(@as(?u8, null), b.optional_int);
    for (b.sentinel) |e| {
        testing.expectEqual(@as(u8, 0), e);
    }
}

/// Sets a slice to zeroes.
/// Prevents the store from being optimized out.
pub fn secureZero(comptime T: type, s: []T) void {
    // NOTE: We do not use a volatile slice cast here since LLVM cannot
    // see that it can be replaced by a memset.
    const ptr = @ptrCast([*]volatile u8, s.ptr);
    const length = s.len * @sizeOf(T);
    @memset(ptr, 0, length);
}

test "mem.secureZero" {
    var a = [_]u8{0xfe} ** 8;
    var b = [_]u8{0xfe} ** 8;

    set(u8, a[0..], 0);
    secureZero(u8, b[0..]);

    testing.expectEqualSlices(u8, a[0..], b[0..]);
}

/// Initializes all fields of the struct with their default value, or zero values if no default value is present.
/// If the field is present in the provided initial values, it will have that value instead.
/// Structs are initialized recursively.
pub fn zeroInit(comptime T: type, init: anytype) T {
    comptime const Init = @TypeOf(init);

    switch (@typeInfo(T)) {
        .Struct => |struct_info| {
            switch (@typeInfo(Init)) {
                .Struct => |init_info| {
                    var value = std.mem.zeroes(T);

                    if (init_info.is_tuple) {
                        inline for (init_info.fields) |field, i| {
                            @field(value, struct_info.fields[i].name) = @field(init, field.name);
                        }
                        return value;
                    }

                    inline for (init_info.fields) |field| {
                        if (!@hasField(T, field.name)) {
                            @compileError("Encountered an initializer for `" ++ field.name ++ "`, but it is not a field of " ++ @typeName(T));
                        }
                    }

                    inline for (struct_info.fields) |field| {
                        if (@hasField(Init, field.name)) {
                            switch (@typeInfo(field.field_type)) {
                                .Struct => {
                                    @field(value, field.name) = zeroInit(field.field_type, @field(init, field.name));
                                },
                                else => {
                                    @field(value, field.name) = @field(init, field.name);
                                },
                            }
                        } else if (field.default_value) |default_value| {
                            @field(value, field.name) = default_value;
                        }
                    }

                    return value;
                },
                else => {
                    @compileError("The initializer must be a struct");
                },
            }
        },
        else => {
            @compileError("Can't default init a " ++ @typeName(T));
        },
    }
}

test "zeroInit" {
    const I = struct {
        d: f64,
    };

    const S = struct {
        a: u32,
        b: ?bool,
        c: I,
        e: [3]u8,
        f: i64 = -1,
    };

    const s = zeroInit(S, .{
        .a = 42,
    });

    testing.expectEqual(S{
        .a = 42,
        .b = null,
        .c = .{
            .d = 0,
        },
        .e = [3]u8{ 0, 0, 0 },
        .f = -1,
    }, s);

    const Color = struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    };

    const c = zeroInit(Color, .{ 255, 255 });
    testing.expectEqual(Color{
        .r = 255,
        .g = 255,
        .b = 0,
        .a = 0,
    }, c);
}

/// Compares two slices of numbers lexicographically. O(n).
pub fn order(comptime T: type, lhs: []const T, rhs: []const T) math.Order {
    const n = math.min(lhs.len, rhs.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        switch (math.order(lhs[i], rhs[i])) {
            .eq => continue,
            .lt => return .lt,
            .gt => return .gt,
        }
    }
    return math.order(lhs.len, rhs.len);
}

test "order" {
    testing.expect(order(u8, "abcd", "bee") == .lt);
    testing.expect(order(u8, "abc", "abc") == .eq);
    testing.expect(order(u8, "abc", "abc0") == .lt);
    testing.expect(order(u8, "", "") == .eq);
    testing.expect(order(u8, "", "a") == .lt);
}

/// Returns true if lhs < rhs, false otherwise
pub fn lessThan(comptime T: type, lhs: []const T, rhs: []const T) bool {
    return order(T, lhs, rhs) == .lt;
}

test "mem.lessThan" {
    testing.expect(lessThan(u8, "abcd", "bee"));
    testing.expect(!lessThan(u8, "abc", "abc"));
    testing.expect(lessThan(u8, "abc", "abc0"));
    testing.expect(!lessThan(u8, "", ""));
    testing.expect(lessThan(u8, "", "a"));
}

/// Compares two slices and returns whether they are equal.
pub fn eql(comptime T: type, a: []const T, b: []const T) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

/// Compares two slices and returns the index of the first inequality.
/// Returns null if the slices are equal.
pub fn indexOfDiff(comptime T: type, a: []const T, b: []const T) ?usize {
    const shortest = math.min(a.len, b.len);
    if (a.ptr == b.ptr)
        return if (a.len == b.len) null else shortest;
    var index: usize = 0;
    while (index < shortest) : (index += 1) if (a[index] != b[index]) return index;
    return if (a.len == b.len) null else shortest;
}

test "indexOfDiff" {
    testing.expectEqual(indexOfDiff(u8, "one", "one"), null);
    testing.expectEqual(indexOfDiff(u8, "one two", "one"), 3);
    testing.expectEqual(indexOfDiff(u8, "one", "one two"), 3);
    testing.expectEqual(indexOfDiff(u8, "one twx", "one two"), 6);
    testing.expectEqual(indexOfDiff(u8, "xne", "one"), 0);
}

pub const toSliceConst = @compileError("deprecated; use std.mem.spanZ");
pub const toSlice = @compileError("deprecated; use std.mem.spanZ");

/// Takes a pointer to an array, a sentinel-terminated pointer, or a slice, and
/// returns a slice. If there is a sentinel on the input type, there will be a
/// sentinel on the output type. The constness of the output type matches
/// the constness of the input type. `[*c]` pointers are assumed to be 0-terminated,
/// and assumed to not allow null.
pub fn Span(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Optional => |optional_info| {
            return ?Span(optional_info.child);
        },
        .Pointer => |ptr_info| {
            var new_ptr_info = ptr_info;
            switch (ptr_info.size) {
                .One => switch (@typeInfo(ptr_info.child)) {
                    .Array => |info| {
                        new_ptr_info.child = info.child;
                        new_ptr_info.sentinel = info.sentinel;
                    },
                    else => @compileError("invalid type given to std.mem.Span"),
                },
                .C => {
                    new_ptr_info.sentinel = 0;
                    new_ptr_info.is_allowzero = false;
                },
                .Many, .Slice => {},
            }
            new_ptr_info.size = .Slice;
            return @Type(std.builtin.TypeInfo{ .Pointer = new_ptr_info });
        },
        else => @compileError("invalid type given to std.mem.Span"),
    }
}

test "Span" {
    testing.expect(Span(*[5]u16) == []u16);
    testing.expect(Span(?*[5]u16) == ?[]u16);
    testing.expect(Span(*const [5]u16) == []const u16);
    testing.expect(Span(?*const [5]u16) == ?[]const u16);
    testing.expect(Span([]u16) == []u16);
    testing.expect(Span(?[]u16) == ?[]u16);
    testing.expect(Span([]const u8) == []const u8);
    testing.expect(Span(?[]const u8) == ?[]const u8);
    testing.expect(Span([:1]u16) == [:1]u16);
    testing.expect(Span(?[:1]u16) == ?[:1]u16);
    testing.expect(Span([:1]const u8) == [:1]const u8);
    testing.expect(Span(?[:1]const u8) == ?[:1]const u8);
    testing.expect(Span([*:1]u16) == [:1]u16);
    testing.expect(Span(?[*:1]u16) == ?[:1]u16);
    testing.expect(Span([*:1]const u8) == [:1]const u8);
    testing.expect(Span(?[*:1]const u8) == ?[:1]const u8);
    testing.expect(Span([*c]u16) == [:0]u16);
    testing.expect(Span(?[*c]u16) == ?[:0]u16);
    testing.expect(Span([*c]const u8) == [:0]const u8);
    testing.expect(Span(?[*c]const u8) == ?[:0]const u8);
}

/// Takes a pointer to an array, a sentinel-terminated pointer, or a slice, and
/// returns a slice. If there is a sentinel on the input type, there will be a
/// sentinel on the output type. The constness of the output type matches
/// the constness of the input type.
///
/// When there is both a sentinel and an array length or slice length, the
/// length value is used instead of the sentinel.
pub fn span(ptr: anytype) Span(@TypeOf(ptr)) {
    if (@typeInfo(@TypeOf(ptr)) == .Optional) {
        if (ptr) |non_null| {
            return span(non_null);
        } else {
            return null;
        }
    }
    const Result = Span(@TypeOf(ptr));
    const l = len(ptr);
    if (@typeInfo(Result).Pointer.sentinel) |s| {
        return ptr[0..l :s];
    } else {
        return ptr[0..l];
    }
}

test "span" {
    var array: [5]u16 = [_]u16{ 1, 2, 3, 4, 5 };
    const ptr = @as([*:3]u16, array[0..2 :3]);
    testing.expect(eql(u16, span(ptr), &[_]u16{ 1, 2 }));
    testing.expect(eql(u16, span(&array), &[_]u16{ 1, 2, 3, 4, 5 }));
    testing.expectEqual(@as(?[:0]u16, null), span(@as(?[*:0]u16, null)));
}

/// Same as `span`, except when there is both a sentinel and an array
/// length or slice length, scans the memory for the sentinel value
/// rather than using the length.
pub fn spanZ(ptr: anytype) Span(@TypeOf(ptr)) {
    if (@typeInfo(@TypeOf(ptr)) == .Optional) {
        if (ptr) |non_null| {
            return spanZ(non_null);
        } else {
            return null;
        }
    }
    const Result = Span(@TypeOf(ptr));
    const l = lenZ(ptr);
    if (@typeInfo(Result).Pointer.sentinel) |s| {
        return ptr[0..l :s];
    } else {
        return ptr[0..l];
    }
}

test "spanZ" {
    var array: [5]u16 = [_]u16{ 1, 2, 3, 4, 5 };
    const ptr = @as([*:3]u16, array[0..2 :3]);
    testing.expect(eql(u16, spanZ(ptr), &[_]u16{ 1, 2 }));
    testing.expect(eql(u16, spanZ(&array), &[_]u16{ 1, 2, 3, 4, 5 }));
    testing.expectEqual(@as(?[:0]u16, null), spanZ(@as(?[*:0]u16, null)));
}

/// Takes a pointer to an array, an array, a vector, a sentinel-terminated pointer,
/// or a slice, and returns the length.
/// In the case of a sentinel-terminated array, it uses the array length.
/// For C pointers it assumes it is a pointer-to-many with a 0 sentinel.
pub fn len(value: anytype) usize {
    return switch (@typeInfo(@TypeOf(value))) {
        .Array => |info| info.len,
        .Vector => |info| info.len,
        .Pointer => |info| switch (info.size) {
            .One => switch (@typeInfo(info.child)) {
                .Array => value.len,
                else => @compileError("invalid type given to std.mem.len"),
            },
            .Many => if (info.sentinel) |sentinel|
                indexOfSentinel(info.child, sentinel, value)
            else
                @compileError("length of pointer with no sentinel"),
            .C => indexOfSentinel(info.child, 0, value),
            .Slice => value.len,
        },
        else => @compileError("invalid type given to std.mem.len"),
    };
}

test "len" {
    testing.expect(len("aoeu") == 4);

    {
        var array: [5]u16 = [_]u16{ 1, 2, 3, 4, 5 };
        testing.expect(len(&array) == 5);
        testing.expect(len(array[0..3]) == 3);
        array[2] = 0;
        const ptr = @as([*:0]u16, array[0..2 :0]);
        testing.expect(len(ptr) == 2);
    }
    {
        var array: [5:0]u16 = [_:0]u16{ 1, 2, 3, 4, 5 };
        testing.expect(len(&array) == 5);
        array[2] = 0;
        testing.expect(len(&array) == 5);
    }
    {
        const vector: meta.Vector(2, u32) = [2]u32{ 1, 2 };
        testing.expect(len(vector) == 2);
    }
}

/// Takes a pointer to an array, an array, a sentinel-terminated pointer,
/// or a slice, and returns the length.
/// In the case of a sentinel-terminated array, it scans the array
/// for a sentinel and uses that for the length, rather than using the array length.
/// For C pointers it assumes it is a pointer-to-many with a 0 sentinel.
pub fn lenZ(ptr: anytype) usize {
    return switch (@typeInfo(@TypeOf(ptr))) {
        .Array => |info| if (info.sentinel) |sentinel|
            indexOfSentinel(info.child, sentinel, &ptr)
        else
            info.len,
        .Pointer => |info| switch (info.size) {
            .One => switch (@typeInfo(info.child)) {
                .Array => |x| if (x.sentinel) |sentinel|
                    indexOfSentinel(x.child, sentinel, ptr)
                else
                    ptr.len,
                else => @compileError("invalid type given to std.mem.lenZ"),
            },
            .Many => if (info.sentinel) |sentinel|
                indexOfSentinel(info.child, sentinel, ptr)
            else
                @compileError("length of pointer with no sentinel"),
            .C => indexOfSentinel(info.child, 0, ptr),
            .Slice => if (info.sentinel) |sentinel|
                indexOfSentinel(info.child, sentinel, ptr.ptr)
            else
                ptr.len,
        },
        else => @compileError("invalid type given to std.mem.lenZ"),
    };
}

test "lenZ" {
    testing.expect(lenZ("aoeu") == 4);

    {
        var array: [5]u16 = [_]u16{ 1, 2, 3, 4, 5 };
        testing.expect(lenZ(&array) == 5);
        testing.expect(lenZ(array[0..3]) == 3);
        array[2] = 0;
        const ptr = @as([*:0]u16, array[0..2 :0]);
        testing.expect(lenZ(ptr) == 2);
    }
    {
        var array: [5:0]u16 = [_:0]u16{ 1, 2, 3, 4, 5 };
        testing.expect(lenZ(&array) == 5);
        array[2] = 0;
        testing.expect(lenZ(&array) == 2);
    }
}

pub fn indexOfSentinel(comptime Elem: type, comptime sentinel: Elem, ptr: [*:sentinel]const Elem) usize {
    var i: usize = 0;
    while (ptr[i] != sentinel) {
        i += 1;
    }
    return i;
}

/// Returns true if all elements in a slice are equal to the scalar value provided
pub fn allEqual(comptime T: type, slice: []const T, scalar: T) bool {
    for (slice) |item| {
        if (item != scalar) return false;
    }
    return true;
}

/// Deprecated, use `Allocator.dupe`.
pub fn dupe(allocator: *Allocator, comptime T: type, m: []const T) ![]T {
    return allocator.dupe(T, m);
}

/// Deprecated, use `Allocator.dupeZ`.
pub fn dupeZ(allocator: *Allocator, comptime T: type, m: []const T) ![:0]T {
    return allocator.dupeZ(T, m);
}

/// Remove values from the beginning of a slice.
pub fn trimLeft(comptime T: type, slice: []const T, values_to_strip: []const T) []const T {
    var begin: usize = 0;
    while (begin < slice.len and indexOfScalar(T, values_to_strip, slice[begin]) != null) : (begin += 1) {}
    return slice[begin..];
}

/// Remove values from the end of a slice.
pub fn trimRight(comptime T: type, slice: []const T, values_to_strip: []const T) []const T {
    var end: usize = slice.len;
    while (end > 0 and indexOfScalar(T, values_to_strip, slice[end - 1]) != null) : (end -= 1) {}
    return slice[0..end];
}

/// Remove values from the beginning and end of a slice.
pub fn trim(comptime T: type, slice: []const T, values_to_strip: []const T) []const T {
    var begin: usize = 0;
    var end: usize = slice.len;
    while (begin < end and indexOfScalar(T, values_to_strip, slice[begin]) != null) : (begin += 1) {}
    while (end > begin and indexOfScalar(T, values_to_strip, slice[end - 1]) != null) : (end -= 1) {}
    return slice[begin..end];
}

test "mem.trim" {
    testing.expectEqualSlices(u8, "foo\n ", trimLeft(u8, " foo\n ", " \n"));
    testing.expectEqualSlices(u8, " foo", trimRight(u8, " foo\n ", " \n"));
    testing.expectEqualSlices(u8, "foo", trim(u8, " foo\n ", " \n"));
    testing.expectEqualSlices(u8, "foo", trim(u8, "foo", " \n"));
}

/// Linear search for the index of a scalar value inside a slice.
pub fn indexOfScalar(comptime T: type, slice: []const T, value: T) ?usize {
    return indexOfScalarPos(T, slice, 0, value);
}

/// Linear search for the last index of a scalar value inside a slice.
pub fn lastIndexOfScalar(comptime T: type, slice: []const T, value: T) ?usize {
    var i: usize = slice.len;
    while (i != 0) {
        i -= 1;
        if (slice[i] == value) return i;
    }
    return null;
}

pub fn indexOfScalarPos(comptime T: type, slice: []const T, start_index: usize, value: T) ?usize {
    var i: usize = start_index;
    while (i < slice.len) : (i += 1) {
        if (slice[i] == value) return i;
    }
    return null;
}

pub fn indexOfAny(comptime T: type, slice: []const T, values: []const T) ?usize {
    return indexOfAnyPos(T, slice, 0, values);
}

pub fn lastIndexOfAny(comptime T: type, slice: []const T, values: []const T) ?usize {
    var i: usize = slice.len;
    while (i != 0) {
        i -= 1;
        for (values) |value| {
            if (slice[i] == value) return i;
        }
    }
    return null;
}

pub fn indexOfAnyPos(comptime T: type, slice: []const T, start_index: usize, values: []const T) ?usize {
    var i: usize = start_index;
    while (i < slice.len) : (i += 1) {
        for (values) |value| {
            if (slice[i] == value) return i;
        }
    }
    return null;
}

pub fn indexOf(comptime T: type, haystack: []const T, needle: []const T) ?usize {
    return indexOfPos(T, haystack, 0, needle);
}

/// Find the index in a slice of a sub-slice, searching from the end backwards.
/// To start looking at a different index, slice the haystack first.
/// TODO is there even a better algorithm for this?
pub fn lastIndexOf(comptime T: type, haystack: []const T, needle: []const T) ?usize {
    if (needle.len > haystack.len) return null;

    var i: usize = haystack.len - needle.len;
    while (true) : (i -= 1) {
        if (mem.eql(T, haystack[i .. i + needle.len], needle)) return i;
        if (i == 0) return null;
    }
}

// TODO boyer-moore algorithm
pub fn indexOfPos(comptime T: type, haystack: []const T, start_index: usize, needle: []const T) ?usize {
    if (needle.len > haystack.len) return null;

    var i: usize = start_index;
    const end = haystack.len - needle.len;
    while (i <= end) : (i += 1) {
        if (eql(T, haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

test "mem.indexOf" {
    testing.expect(indexOf(u8, "one two three four", "four").? == 14);
    testing.expect(lastIndexOf(u8, "one two three two four", "two").? == 14);
    testing.expect(indexOf(u8, "one two three four", "gour") == null);
    testing.expect(lastIndexOf(u8, "one two three four", "gour") == null);
    testing.expect(indexOf(u8, "foo", "foo").? == 0);
    testing.expect(lastIndexOf(u8, "foo", "foo").? == 0);
    testing.expect(indexOf(u8, "foo", "fool") == null);
    testing.expect(lastIndexOf(u8, "foo", "lfoo") == null);
    testing.expect(lastIndexOf(u8, "foo", "fool") == null);

    testing.expect(indexOf(u8, "foo foo", "foo").? == 0);
    testing.expect(lastIndexOf(u8, "foo foo", "foo").? == 4);
    testing.expect(lastIndexOfAny(u8, "boo, cat", "abo").? == 6);
    testing.expect(lastIndexOfScalar(u8, "boo", 'o').? == 2);
}

/// Reads an integer from memory with size equal to bytes.len.
/// T specifies the return type, which must be large enough to store
/// the result.
pub fn readVarInt(comptime ReturnType: type, bytes: []const u8, endian: builtin.Endian) ReturnType {
    var result: ReturnType = 0;
    switch (endian) {
        .Big => {
            for (bytes) |b| {
                result = (result << 8) | b;
            }
        },
        .Little => {
            const ShiftType = math.Log2Int(ReturnType);
            for (bytes) |b, index| {
                result = result | (@as(ReturnType, b) << @intCast(ShiftType, index * 8));
            }
        },
    }
    return result;
}

/// Reads an integer from memory with bit count specified by T.
/// The bit count of T must be evenly divisible by 8.
/// This function cannot fail and cannot cause undefined behavior.
/// Assumes the endianness of memory is native. This means the function can
/// simply pointer cast memory.
pub fn readIntNative(comptime T: type, bytes: *const [@divExact(T.bit_count, 8)]u8) T {
    return @ptrCast(*align(1) const T, bytes).*;
}

/// Reads an integer from memory with bit count specified by T.
/// The bit count of T must be evenly divisible by 8.
/// This function cannot fail and cannot cause undefined behavior.
/// Assumes the endianness of memory is foreign, so it must byte-swap.
pub fn readIntForeign(comptime T: type, bytes: *const [@divExact(T.bit_count, 8)]u8) T {
    return @byteSwap(T, readIntNative(T, bytes));
}

pub const readIntLittle = switch (builtin.endian) {
    .Little => readIntNative,
    .Big => readIntForeign,
};

pub const readIntBig = switch (builtin.endian) {
    .Little => readIntForeign,
    .Big => readIntNative,
};

/// Asserts that bytes.len >= T.bit_count / 8. Reads the integer starting from index 0
/// and ignores extra bytes.
/// The bit count of T must be evenly divisible by 8.
/// Assumes the endianness of memory is native. This means the function can
/// simply pointer cast memory.
pub fn readIntSliceNative(comptime T: type, bytes: []const u8) T {
    const n = @divExact(T.bit_count, 8);
    assert(bytes.len >= n);
    return readIntNative(T, bytes[0..n]);
}

/// Asserts that bytes.len >= T.bit_count / 8. Reads the integer starting from index 0
/// and ignores extra bytes.
/// The bit count of T must be evenly divisible by 8.
/// Assumes the endianness of memory is foreign, so it must byte-swap.
pub fn readIntSliceForeign(comptime T: type, bytes: []const u8) T {
    return @byteSwap(T, readIntSliceNative(T, bytes));
}

pub const readIntSliceLittle = switch (builtin.endian) {
    .Little => readIntSliceNative,
    .Big => readIntSliceForeign,
};

pub const readIntSliceBig = switch (builtin.endian) {
    .Little => readIntSliceForeign,
    .Big => readIntSliceNative,
};

/// Reads an integer from memory with bit count specified by T.
/// The bit count of T must be evenly divisible by 8.
/// This function cannot fail and cannot cause undefined behavior.
pub fn readInt(comptime T: type, bytes: *const [@divExact(T.bit_count, 8)]u8, endian: builtin.Endian) T {
    if (endian == builtin.endian) {
        return readIntNative(T, bytes);
    } else {
        return readIntForeign(T, bytes);
    }
}

/// Asserts that bytes.len >= T.bit_count / 8. Reads the integer starting from index 0
/// and ignores extra bytes.
/// The bit count of T must be evenly divisible by 8.
pub fn readIntSlice(comptime T: type, bytes: []const u8, endian: builtin.Endian) T {
    const n = @divExact(T.bit_count, 8);
    assert(bytes.len >= n);
    return readInt(T, bytes[0..n], endian);
}

test "comptime read/write int" {
    comptime {
        var bytes: [2]u8 = undefined;
        writeIntLittle(u16, &bytes, 0x1234);
        const result = readIntBig(u16, &bytes);
        testing.expect(result == 0x3412);
    }
    comptime {
        var bytes: [2]u8 = undefined;
        writeIntBig(u16, &bytes, 0x1234);
        const result = readIntLittle(u16, &bytes);
        testing.expect(result == 0x3412);
    }
}

test "readIntBig and readIntLittle" {
    testing.expect(readIntSliceBig(u0, &[_]u8{}) == 0x0);
    testing.expect(readIntSliceLittle(u0, &[_]u8{}) == 0x0);

    testing.expect(readIntSliceBig(u8, &[_]u8{0x32}) == 0x32);
    testing.expect(readIntSliceLittle(u8, &[_]u8{0x12}) == 0x12);

    testing.expect(readIntSliceBig(u16, &[_]u8{ 0x12, 0x34 }) == 0x1234);
    testing.expect(readIntSliceLittle(u16, &[_]u8{ 0x12, 0x34 }) == 0x3412);

    testing.expect(readIntSliceBig(u72, &[_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x24 }) == 0x123456789abcdef024);
    testing.expect(readIntSliceLittle(u72, &[_]u8{ 0xec, 0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe }) == 0xfedcba9876543210ec);

    testing.expect(readIntSliceBig(i8, &[_]u8{0xff}) == -1);
    testing.expect(readIntSliceLittle(i8, &[_]u8{0xfe}) == -2);

    testing.expect(readIntSliceBig(i16, &[_]u8{ 0xff, 0xfd }) == -3);
    testing.expect(readIntSliceLittle(i16, &[_]u8{ 0xfc, 0xff }) == -4);
}

/// Writes an integer to memory, storing it in twos-complement.
/// This function always succeeds, has defined behavior for all inputs, and
/// accepts any integer bit width.
/// This function stores in native endian, which means it is implemented as a simple
/// memory store.
pub fn writeIntNative(comptime T: type, buf: *[(T.bit_count + 7) / 8]u8, value: T) void {
    @ptrCast(*align(1) T, buf).* = value;
}

/// Writes an integer to memory, storing it in twos-complement.
/// This function always succeeds, has defined behavior for all inputs, but
/// the integer bit width must be divisible by 8.
/// This function stores in foreign endian, which means it does a @byteSwap first.
pub fn writeIntForeign(comptime T: type, buf: *[@divExact(T.bit_count, 8)]u8, value: T) void {
    writeIntNative(T, buf, @byteSwap(T, value));
}

pub const writeIntLittle = switch (builtin.endian) {
    .Little => writeIntNative,
    .Big => writeIntForeign,
};

pub const writeIntBig = switch (builtin.endian) {
    .Little => writeIntForeign,
    .Big => writeIntNative,
};

/// Writes an integer to memory, storing it in twos-complement.
/// This function always succeeds, has defined behavior for all inputs, but
/// the integer bit width must be divisible by 8.
pub fn writeInt(comptime T: type, buffer: *[@divExact(T.bit_count, 8)]u8, value: T, endian: builtin.Endian) void {
    if (endian == builtin.endian) {
        return writeIntNative(T, buffer, value);
    } else {
        return writeIntForeign(T, buffer, value);
    }
}

/// Writes a twos-complement little-endian integer to memory.
/// Asserts that buf.len >= T.bit_count / 8.
/// The bit count of T must be divisible by 8.
/// Any extra bytes in buffer after writing the integer are set to zero. To
/// avoid the branch to check for extra buffer bytes, use writeIntLittle
/// instead.
pub fn writeIntSliceLittle(comptime T: type, buffer: []u8, value: T) void {
    assert(buffer.len >= @divExact(T.bit_count, 8));

    if (T.bit_count == 0)
        return set(u8, buffer, 0);

    // TODO I want to call writeIntLittle here but comptime eval facilities aren't good enough
    const uint = std.meta.Int(false, T.bit_count);
    var bits = @truncate(uint, value);
    for (buffer) |*b| {
        b.* = @truncate(u8, bits);
        bits >>= 8;
    }
}

/// Writes a twos-complement big-endian integer to memory.
/// Asserts that buffer.len >= T.bit_count / 8.
/// The bit count of T must be divisible by 8.
/// Any extra bytes in buffer before writing the integer are set to zero. To
/// avoid the branch to check for extra buffer bytes, use writeIntBig instead.
pub fn writeIntSliceBig(comptime T: type, buffer: []u8, value: T) void {
    assert(buffer.len >= @divExact(T.bit_count, 8));

    if (T.bit_count == 0)
        return set(u8, buffer, 0);

    // TODO I want to call writeIntBig here but comptime eval facilities aren't good enough
    const uint = std.meta.Int(false, T.bit_count);
    var bits = @truncate(uint, value);
    var index: usize = buffer.len;
    while (index != 0) {
        index -= 1;
        buffer[index] = @truncate(u8, bits);
        bits >>= 8;
    }
}

pub const writeIntSliceNative = switch (builtin.endian) {
    .Little => writeIntSliceLittle,
    .Big => writeIntSliceBig,
};

pub const writeIntSliceForeign = switch (builtin.endian) {
    .Little => writeIntSliceBig,
    .Big => writeIntSliceLittle,
};

/// Writes a twos-complement integer to memory, with the specified endianness.
/// Asserts that buf.len >= T.bit_count / 8.
/// The bit count of T must be evenly divisible by 8.
/// Any extra bytes in buffer not part of the integer are set to zero, with
/// respect to endianness. To avoid the branch to check for extra buffer bytes,
/// use writeInt instead.
pub fn writeIntSlice(comptime T: type, buffer: []u8, value: T, endian: builtin.Endian) void {
    comptime assert(T.bit_count % 8 == 0);
    return switch (endian) {
        .Little => writeIntSliceLittle(T, buffer, value),
        .Big => writeIntSliceBig(T, buffer, value),
    };
}

test "writeIntBig and writeIntLittle" {
    var buf0: [0]u8 = undefined;
    var buf1: [1]u8 = undefined;
    var buf2: [2]u8 = undefined;
    var buf9: [9]u8 = undefined;

    writeIntBig(u0, &buf0, 0x0);
    testing.expect(eql(u8, buf0[0..], &[_]u8{}));
    writeIntLittle(u0, &buf0, 0x0);
    testing.expect(eql(u8, buf0[0..], &[_]u8{}));

    writeIntBig(u8, &buf1, 0x12);
    testing.expect(eql(u8, buf1[0..], &[_]u8{0x12}));
    writeIntLittle(u8, &buf1, 0x34);
    testing.expect(eql(u8, buf1[0..], &[_]u8{0x34}));

    writeIntBig(u16, &buf2, 0x1234);
    testing.expect(eql(u8, buf2[0..], &[_]u8{ 0x12, 0x34 }));
    writeIntLittle(u16, &buf2, 0x5678);
    testing.expect(eql(u8, buf2[0..], &[_]u8{ 0x78, 0x56 }));

    writeIntBig(u72, &buf9, 0x123456789abcdef024);
    testing.expect(eql(u8, buf9[0..], &[_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x24 }));
    writeIntLittle(u72, &buf9, 0xfedcba9876543210ec);
    testing.expect(eql(u8, buf9[0..], &[_]u8{ 0xec, 0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe }));

    writeIntBig(i8, &buf1, -1);
    testing.expect(eql(u8, buf1[0..], &[_]u8{0xff}));
    writeIntLittle(i8, &buf1, -2);
    testing.expect(eql(u8, buf1[0..], &[_]u8{0xfe}));

    writeIntBig(i16, &buf2, -3);
    testing.expect(eql(u8, buf2[0..], &[_]u8{ 0xff, 0xfd }));
    writeIntLittle(i16, &buf2, -4);
    testing.expect(eql(u8, buf2[0..], &[_]u8{ 0xfc, 0xff }));
}

/// Returns an iterator that iterates over the slices of `buffer` that are not
/// any of the bytes in `delimiter_bytes`.
/// tokenize("   abc def    ghi  ", " ")
/// Will return slices for "abc", "def", "ghi", null, in that order.
/// If `buffer` is empty, the iterator will return null.
/// If `delimiter_bytes` does not exist in buffer,
/// the iterator will return `buffer`, null, in that order.
/// See also the related function `split`.
pub fn tokenize(buffer: []const u8, delimiter_bytes: []const u8) TokenIterator {
    return TokenIterator{
        .index = 0,
        .buffer = buffer,
        .delimiter_bytes = delimiter_bytes,
    };
}

test "mem.tokenize" {
    var it = tokenize("   abc def   ghi  ", " ");
    testing.expect(eql(u8, it.next().?, "abc"));
    testing.expect(eql(u8, it.next().?, "def"));
    testing.expect(eql(u8, it.next().?, "ghi"));
    testing.expect(it.next() == null);

    it = tokenize("..\\bob", "\\");
    testing.expect(eql(u8, it.next().?, ".."));
    testing.expect(eql(u8, "..", "..\\bob"[0..it.index]));
    testing.expect(eql(u8, it.next().?, "bob"));
    testing.expect(it.next() == null);

    it = tokenize("//a/b", "/");
    testing.expect(eql(u8, it.next().?, "a"));
    testing.expect(eql(u8, it.next().?, "b"));
    testing.expect(eql(u8, "//a/b", "//a/b"[0..it.index]));
    testing.expect(it.next() == null);

    it = tokenize("|", "|");
    testing.expect(it.next() == null);

    it = tokenize("", "|");
    testing.expect(it.next() == null);

    it = tokenize("hello", "");
    testing.expect(eql(u8, it.next().?, "hello"));
    testing.expect(it.next() == null);

    it = tokenize("hello", " ");
    testing.expect(eql(u8, it.next().?, "hello"));
    testing.expect(it.next() == null);
}

test "mem.tokenize (multibyte)" {
    var it = tokenize("a|b,c/d e", " /,|");
    testing.expect(eql(u8, it.next().?, "a"));
    testing.expect(eql(u8, it.next().?, "b"));
    testing.expect(eql(u8, it.next().?, "c"));
    testing.expect(eql(u8, it.next().?, "d"));
    testing.expect(eql(u8, it.next().?, "e"));
    testing.expect(it.next() == null);
}

/// Returns an iterator that iterates over the slices of `buffer` that
/// are separated by bytes in `delimiter`.
/// split("abc|def||ghi", "|")
/// will return slices for "abc", "def", "", "ghi", null, in that order.
/// If `delimiter` does not exist in buffer,
/// the iterator will return `buffer`, null, in that order.
/// The delimiter length must not be zero.
/// See also the related function `tokenize`.
pub fn split(buffer: []const u8, delimiter: []const u8) SplitIterator {
    assert(delimiter.len != 0);
    return SplitIterator{
        .index = 0,
        .buffer = buffer,
        .delimiter = delimiter,
    };
}

pub const separate = @compileError("deprecated: renamed to split (behavior remains unchanged)");

test "mem.split" {
    var it = split("abc|def||ghi", "|");
    testing.expect(eql(u8, it.next().?, "abc"));
    testing.expect(eql(u8, it.next().?, "def"));
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(eql(u8, it.next().?, "ghi"));
    testing.expect(it.next() == null);

    it = split("", "|");
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(it.next() == null);

    it = split("|", "|");
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(it.next() == null);

    it = split("hello", " ");
    testing.expect(eql(u8, it.next().?, "hello"));
    testing.expect(it.next() == null);
}

test "mem.split (multibyte)" {
    var it = split("a, b ,, c, d, e", ", ");
    testing.expect(eql(u8, it.next().?, "a"));
    testing.expect(eql(u8, it.next().?, "b ,"));
    testing.expect(eql(u8, it.next().?, "c"));
    testing.expect(eql(u8, it.next().?, "d"));
    testing.expect(eql(u8, it.next().?, "e"));
    testing.expect(it.next() == null);
}

pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
    return if (needle.len > haystack.len) false else eql(T, haystack[0..needle.len], needle);
}

test "mem.startsWith" {
    testing.expect(startsWith(u8, "Bob", "Bo"));
    testing.expect(!startsWith(u8, "Needle in haystack", "haystack"));
}

pub fn endsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
    return if (needle.len > haystack.len) false else eql(T, haystack[haystack.len - needle.len ..], needle);
}

test "mem.endsWith" {
    testing.expect(endsWith(u8, "Needle in haystack", "haystack"));
    testing.expect(!endsWith(u8, "Bob", "Bo"));
}

pub const TokenIterator = struct {
    buffer: []const u8,
    delimiter_bytes: []const u8,
    index: usize,

    /// Returns a slice of the next token, or null if tokenization is complete.
    pub fn next(self: *TokenIterator) ?[]const u8 {
        // move to beginning of token
        while (self.index < self.buffer.len and self.isSplitByte(self.buffer[self.index])) : (self.index += 1) {}
        const start = self.index;
        if (start == self.buffer.len) {
            return null;
        }

        // move to end of token
        while (self.index < self.buffer.len and !self.isSplitByte(self.buffer[self.index])) : (self.index += 1) {}
        const end = self.index;

        return self.buffer[start..end];
    }

    /// Returns a slice of the remaining bytes. Does not affect iterator state.
    pub fn rest(self: TokenIterator) []const u8 {
        // move to beginning of token
        var index: usize = self.index;
        while (index < self.buffer.len and self.isSplitByte(self.buffer[index])) : (index += 1) {}
        return self.buffer[index..];
    }

    fn isSplitByte(self: TokenIterator, byte: u8) bool {
        for (self.delimiter_bytes) |delimiter_byte| {
            if (byte == delimiter_byte) {
                return true;
            }
        }
        return false;
    }
};

pub const SplitIterator = struct {
    buffer: []const u8,
    index: ?usize,
    delimiter: []const u8,

    /// Returns a slice of the next field, or null if splitting is complete.
    pub fn next(self: *SplitIterator) ?[]const u8 {
        const start = self.index orelse return null;
        const end = if (indexOfPos(u8, self.buffer, start, self.delimiter)) |delim_start| blk: {
            self.index = delim_start + self.delimiter.len;
            break :blk delim_start;
        } else blk: {
            self.index = null;
            break :blk self.buffer.len;
        };
        return self.buffer[start..end];
    }

    /// Returns a slice of the remaining bytes. Does not affect iterator state.
    pub fn rest(self: SplitIterator) []const u8 {
        const end = self.buffer.len;
        const start = self.index orelse end;
        return self.buffer[start..end];
    }
};

/// Naively combines a series of slices with a separator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: *Allocator, separator: []const u8, slices: []const []const u8) ![]u8 {
    return joinMaybeZ(allocator, separator, slices, false);
}

/// Naively combines a series of slices with a separator and null terminator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn joinZ(allocator: *Allocator, separator: []const u8, slices: []const []const u8) ![:0]u8 {
    const out = try joinMaybeZ(allocator, separator, slices, true);
    return out[0 .. out.len - 1 :0];
}

fn joinMaybeZ(allocator: *Allocator, separator: []const u8, slices: []const []const u8, zero: bool) ![]u8 {
    if (slices.len == 0) return &[0]u8{};

    const total_len = blk: {
        var sum: usize = separator.len * (slices.len - 1);
        for (slices) |slice| sum += slice.len;
        if (zero) sum += 1;
        break :blk sum;
    };

    const buf = try allocator.alloc(u8, total_len);
    errdefer allocator.free(buf);

    copy(u8, buf, slices[0]);
    var buf_index: usize = slices[0].len;
    for (slices[1..]) |slice| {
        copy(u8, buf[buf_index..], separator);
        buf_index += separator.len;
        copy(u8, buf[buf_index..], slice);
        buf_index += slice.len;
    }

    if (zero) buf[buf.len - 1] = 0;

    // No need for shrink since buf is exactly the correct size.
    return buf;
}

test "mem.join" {
    {
        const str = try join(testing.allocator, ",", &[_][]const u8{ "a", "b", "c" });
        defer testing.allocator.free(str);
        testing.expect(eql(u8, str, "a,b,c"));
    }
    {
        const str = try join(testing.allocator, ",", &[_][]const u8{"a"});
        defer testing.allocator.free(str);
        testing.expect(eql(u8, str, "a"));
    }
    {
        const str = try join(testing.allocator, ",", &[_][]const u8{ "a", "", "b", "", "c" });
        defer testing.allocator.free(str);
        testing.expect(eql(u8, str, "a,,b,,c"));
    }
}

test "mem.joinZ" {
    {
        const str = try joinZ(testing.allocator, ",", &[_][]const u8{ "a", "b", "c" });
        defer testing.allocator.free(str);
        testing.expect(eql(u8, str, "a,b,c"));
        testing.expectEqual(str[str.len], 0);
    }
    {
        const str = try joinZ(testing.allocator, ",", &[_][]const u8{"a"});
        defer testing.allocator.free(str);
        testing.expect(eql(u8, str, "a"));
        testing.expectEqual(str[str.len], 0);
    }
    {
        const str = try joinZ(testing.allocator, ",", &[_][]const u8{ "a", "", "b", "", "c" });
        defer testing.allocator.free(str);
        testing.expect(eql(u8, str, "a,,b,,c"));
        testing.expectEqual(str[str.len], 0);
    }
}

/// Copies each T from slices into a new slice that exactly holds all the elements.
pub fn concat(allocator: *Allocator, comptime T: type, slices: []const []const T) ![]T {
    if (slices.len == 0) return &[0]T{};

    const total_len = blk: {
        var sum: usize = 0;
        for (slices) |slice| {
            sum += slice.len;
        }
        break :blk sum;
    };

    const buf = try allocator.alloc(T, total_len);
    errdefer allocator.free(buf);

    var buf_index: usize = 0;
    for (slices) |slice| {
        copy(T, buf[buf_index..], slice);
        buf_index += slice.len;
    }

    // No need for shrink since buf is exactly the correct size.
    return buf;
}

test "concat" {
    {
        const str = try concat(testing.allocator, u8, &[_][]const u8{ "abc", "def", "ghi" });
        defer testing.allocator.free(str);
        testing.expect(eql(u8, str, "abcdefghi"));
    }
    {
        const str = try concat(testing.allocator, u32, &[_][]const u32{
            &[_]u32{ 0, 1 },
            &[_]u32{ 2, 3, 4 },
            &[_]u32{},
            &[_]u32{5},
        });
        defer testing.allocator.free(str);
        testing.expect(eql(u32, str, &[_]u32{ 0, 1, 2, 3, 4, 5 }));
    }
}

test "testStringEquality" {
    testing.expect(eql(u8, "abcd", "abcd"));
    testing.expect(!eql(u8, "abcdef", "abZdef"));
    testing.expect(!eql(u8, "abcdefg", "abcdef"));
}

test "testReadInt" {
    testReadIntImpl();
    comptime testReadIntImpl();
}
fn testReadIntImpl() void {
    {
        const bytes = [_]u8{
            0x12,
            0x34,
            0x56,
            0x78,
        };
        testing.expect(readInt(u32, &bytes, builtin.Endian.Big) == 0x12345678);
        testing.expect(readIntBig(u32, &bytes) == 0x12345678);
        testing.expect(readIntBig(i32, &bytes) == 0x12345678);
        testing.expect(readInt(u32, &bytes, builtin.Endian.Little) == 0x78563412);
        testing.expect(readIntLittle(u32, &bytes) == 0x78563412);
        testing.expect(readIntLittle(i32, &bytes) == 0x78563412);
    }
    {
        const buf = [_]u8{
            0x00,
            0x00,
            0x12,
            0x34,
        };
        const answer = readInt(u32, &buf, builtin.Endian.Big);
        testing.expect(answer == 0x00001234);
    }
    {
        const buf = [_]u8{
            0x12,
            0x34,
            0x00,
            0x00,
        };
        const answer = readInt(u32, &buf, builtin.Endian.Little);
        testing.expect(answer == 0x00003412);
    }
    {
        const bytes = [_]u8{
            0xff,
            0xfe,
        };
        testing.expect(readIntBig(u16, &bytes) == 0xfffe);
        testing.expect(readIntBig(i16, &bytes) == -0x0002);
        testing.expect(readIntLittle(u16, &bytes) == 0xfeff);
        testing.expect(readIntLittle(i16, &bytes) == -0x0101);
    }
}

test "writeIntSlice" {
    testWriteIntImpl();
    comptime testWriteIntImpl();
}
fn testWriteIntImpl() void {
    var bytes: [8]u8 = undefined;

    writeIntSlice(u0, bytes[0..], 0, builtin.Endian.Big);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    }));

    writeIntSlice(u0, bytes[0..], 0, builtin.Endian.Little);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    }));

    writeIntSlice(u64, bytes[0..], 0x12345678CAFEBABE, builtin.Endian.Big);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x12,
        0x34,
        0x56,
        0x78,
        0xCA,
        0xFE,
        0xBA,
        0xBE,
    }));

    writeIntSlice(u64, bytes[0..], 0xBEBAFECA78563412, builtin.Endian.Little);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x12,
        0x34,
        0x56,
        0x78,
        0xCA,
        0xFE,
        0xBA,
        0xBE,
    }));

    writeIntSlice(u32, bytes[0..], 0x12345678, builtin.Endian.Big);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x00,
        0x00,
        0x00,
        0x00,
        0x12,
        0x34,
        0x56,
        0x78,
    }));

    writeIntSlice(u32, bytes[0..], 0x78563412, builtin.Endian.Little);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x12,
        0x34,
        0x56,
        0x78,
        0x00,
        0x00,
        0x00,
        0x00,
    }));

    writeIntSlice(u16, bytes[0..], 0x1234, builtin.Endian.Big);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x12,
        0x34,
    }));

    writeIntSlice(u16, bytes[0..], 0x1234, builtin.Endian.Little);
    testing.expect(eql(u8, &bytes, &[_]u8{
        0x34,
        0x12,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
    }));
}

/// Returns the smallest number in a slice. O(n).
/// `slice` must not be empty.
pub fn min(comptime T: type, slice: []const T) T {
    var best = slice[0];
    for (slice[1..]) |item| {
        best = math.min(best, item);
    }
    return best;
}

test "mem.min" {
    testing.expect(min(u8, "abcdefg") == 'a');
}

/// Returns the largest number in a slice. O(n).
/// `slice` must not be empty.
pub fn max(comptime T: type, slice: []const T) T {
    var best = slice[0];
    for (slice[1..]) |item| {
        best = math.max(best, item);
    }
    return best;
}

test "mem.max" {
    testing.expect(max(u8, "abcdefg") == 'g');
}

pub fn swap(comptime T: type, a: *T, b: *T) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

/// In-place order reversal of a slice
pub fn reverse(comptime T: type, items: []T) void {
    var i: usize = 0;
    const end = items.len / 2;
    while (i < end) : (i += 1) {
        swap(T, &items[i], &items[items.len - i - 1]);
    }
}

test "reverse" {
    var arr = [_]i32{ 5, 3, 1, 2, 4 };
    reverse(i32, arr[0..]);

    testing.expect(eql(i32, &arr, &[_]i32{ 4, 2, 1, 3, 5 }));
}

/// In-place rotation of the values in an array ([0 1 2 3] becomes [1 2 3 0] if we rotate by 1)
/// Assumes 0 <= amount <= items.len
pub fn rotate(comptime T: type, items: []T, amount: usize) void {
    reverse(T, items[0..amount]);
    reverse(T, items[amount..]);
    reverse(T, items);
}

test "rotate" {
    var arr = [_]i32{ 5, 3, 1, 2, 4 };
    rotate(i32, arr[0..], 2);

    testing.expect(eql(i32, &arr, &[_]i32{ 1, 2, 4, 5, 3 }));
}

/// Replace needle with replacement as many times as possible, writing to an output buffer which is assumed to be of
/// appropriate size. Use replacementSize to calculate an appropriate buffer size.
pub fn replace(comptime T: type, input: []const T, needle: []const T, replacement: []const T, output: []T) usize {
    var i: usize = 0;
    var slide: usize = 0;
    var replacements: usize = 0;
    while (slide < input.len) {
        if (mem.indexOf(T, input[slide..], needle) == @as(usize, 0)) {
            mem.copy(T, output[i..i + replacement.len], replacement);
            i += replacement.len;
            slide += needle.len;
            replacements += 1;
        } else {
            output[i] = input[slide];
            i += 1;
            slide += 1;
        }
    }

    return replacements;
}

test "replace" {
    var output: [29]u8 = undefined;
    var replacements = replace(u8, "All your base are belong to us", "base", "Zig", output[0..]);
    testing.expect(replacements == 1);
    testing.expect(eql(u8, output[0..], "All your Zig are belong to us"));

    replacements = replace(u8, "Favor reading code over writing code.", "code", "", output[0..]);
    testing.expect(replacements == 2);
    testing.expect(eql(u8, output[0..], "Favor reading  over writing ."));
}

/// Calculate the size needed in an output buffer to perform a replacement.
pub fn replacementSize(comptime T: type, input: []const T, needle: []const T, replacement: []const T) usize {
    var i: usize = 0;
    var size: usize = input.len;
    while (i < input.len) : (i += 1) {
        if (mem.indexOf(T, input[i..], needle) == @as(usize, 0)) {
            size = size - needle.len + replacement.len;
            i += needle.len;
        }
    }

    return size;
}

test "replacementSize" {
    testing.expect(replacementSize(u8, "All your base are belong to us", "base", "Zig") == 29);
    testing.expect(replacementSize(u8, "", "", "") == 0);
    testing.expect(replacementSize(u8, "Favor reading code over writing code.", "code", "") == 29);
    testing.expect(replacementSize(u8, "Only one obvious way to do things.", "things.", "things in Zig.") == 41);
}

/// Perform a replacement on an allocated buffer of pre-determined size. Caller must free returned memory.
pub fn replaceOwned(comptime T: type, allocator: *Allocator, input: []const T, needle: []const T, replacement: []const T) Allocator.Error![]T {
    var output = try allocator.alloc(T, replacementSize(T, input, needle, replacement));
    _ = replace(T, input, needle, replacement, output);
    return output;
}

test "replaceOwned" {
    const allocator = std.heap.page_allocator;

    const base_replace = replaceOwned(u8, allocator, "All your base are belong to us", "base", "Zig") catch unreachable;
    defer allocator.free(base_replace);
    testing.expect(eql(u8, base_replace, "All your Zig are belong to us"));

    const zen_replace = replaceOwned(u8, allocator, "Favor reading code over writing code.", " code", "") catch unreachable;
    defer allocator.free(zen_replace);
    testing.expect(eql(u8, zen_replace, "Favor reading over writing."));
}

/// Converts a little-endian integer to host endianness.
pub fn littleToNative(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        .Little => x,
        .Big => @byteSwap(T, x),
    };
}

/// Converts a big-endian integer to host endianness.
pub fn bigToNative(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        .Little => @byteSwap(T, x),
        .Big => x,
    };
}

/// Converts an integer from specified endianness to host endianness.
pub fn toNative(comptime T: type, x: T, endianness_of_x: builtin.Endian) T {
    return switch (endianness_of_x) {
        .Little => littleToNative(T, x),
        .Big => bigToNative(T, x),
    };
}

/// Converts an integer which has host endianness to the desired endianness.
pub fn nativeTo(comptime T: type, x: T, desired_endianness: builtin.Endian) T {
    return switch (desired_endianness) {
        .Little => nativeToLittle(T, x),
        .Big => nativeToBig(T, x),
    };
}

/// Converts an integer which has host endianness to little endian.
pub fn nativeToLittle(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        .Little => x,
        .Big => @byteSwap(T, x),
    };
}

/// Converts an integer which has host endianness to big endian.
pub fn nativeToBig(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        .Little => @byteSwap(T, x),
        .Big => x,
    };
}

fn AsBytesReturnType(comptime P: type) type {
    if (!trait.isSingleItemPtr(P))
        @compileError("expected single item pointer, passed " ++ @typeName(P));

    const size = @sizeOf(meta.Child(P));
    const alignment = meta.alignment(P);

    if (alignment == 0) {
        if (trait.isConstPtr(P))
            return *const [size]u8;
        return *[size]u8;
    }

    if (trait.isConstPtr(P))
        return *align(alignment) const [size]u8;
    return *align(alignment) [size]u8;
}

/// Given a pointer to a single item, returns a slice of the underlying bytes, preserving constness.
pub fn asBytes(ptr: anytype) AsBytesReturnType(@TypeOf(ptr)) {
    const P = @TypeOf(ptr);
    return @ptrCast(AsBytesReturnType(P), ptr);
}

test "asBytes" {
    const deadbeef = @as(u32, 0xDEADBEEF);
    const deadbeef_bytes = switch (builtin.endian) {
        .Big => "\xDE\xAD\xBE\xEF",
        .Little => "\xEF\xBE\xAD\xDE",
    };

    testing.expect(eql(u8, asBytes(&deadbeef), deadbeef_bytes));

    var codeface = @as(u32, 0xC0DEFACE);
    for (asBytes(&codeface).*) |*b|
        b.* = 0;
    testing.expect(codeface == 0);

    const S = packed struct {
        a: u8,
        b: u8,
        c: u8,
        d: u8,
    };

    const inst = S{
        .a = 0xBE,
        .b = 0xEF,
        .c = 0xDE,
        .d = 0xA1,
    };
    testing.expect(eql(u8, asBytes(&inst), "\xBE\xEF\xDE\xA1"));

    const ZST = struct {};
    const zero = ZST{};
    testing.expect(eql(u8, asBytes(&zero), ""));
}

/// Given any value, returns a copy of its bytes in an array.
pub fn toBytes(value: anytype) [@sizeOf(@TypeOf(value))]u8 {
    return asBytes(&value).*;
}

test "toBytes" {
    var my_bytes = toBytes(@as(u32, 0x12345678));
    switch (builtin.endian) {
        .Big => testing.expect(eql(u8, &my_bytes, "\x12\x34\x56\x78")),
        .Little => testing.expect(eql(u8, &my_bytes, "\x78\x56\x34\x12")),
    }

    my_bytes[0] = '\x99';
    switch (builtin.endian) {
        .Big => testing.expect(eql(u8, &my_bytes, "\x99\x34\x56\x78")),
        .Little => testing.expect(eql(u8, &my_bytes, "\x99\x56\x34\x12")),
    }
}

fn BytesAsValueReturnType(comptime T: type, comptime B: type) type {
    const size = @as(usize, @sizeOf(T));

    if (comptime !trait.is(.Pointer)(B) or
        (meta.Child(B) != [size]u8 and meta.Child(B) != [size:0]u8))
    {
        comptime var buf: [100]u8 = undefined;
        @compileError(std.fmt.bufPrint(&buf, "expected *[{}]u8, passed " ++ @typeName(B), .{size}) catch unreachable);
    }

    const alignment = comptime meta.alignment(B);

    return if (comptime trait.isConstPtr(B)) *align(alignment) const T else *align(alignment) T;
}

/// Given a pointer to an array of bytes, returns a pointer to a value of the specified type
/// backed by those bytes, preserving constness.
pub fn bytesAsValue(comptime T: type, bytes: anytype) BytesAsValueReturnType(T, @TypeOf(bytes)) {
    return @ptrCast(BytesAsValueReturnType(T, @TypeOf(bytes)), bytes);
}

test "bytesAsValue" {
    const deadbeef = @as(u32, 0xDEADBEEF);
    const deadbeef_bytes = switch (builtin.endian) {
        .Big => "\xDE\xAD\xBE\xEF",
        .Little => "\xEF\xBE\xAD\xDE",
    };

    testing.expect(deadbeef == bytesAsValue(u32, deadbeef_bytes).*);

    var codeface_bytes: [4]u8 = switch (builtin.endian) {
        .Big => "\xC0\xDE\xFA\xCE",
        .Little => "\xCE\xFA\xDE\xC0",
    }.*;
    var codeface = bytesAsValue(u32, &codeface_bytes);
    testing.expect(codeface.* == 0xC0DEFACE);
    codeface.* = 0;
    for (codeface_bytes) |b|
        testing.expect(b == 0);

    const S = packed struct {
        a: u8,
        b: u8,
        c: u8,
        d: u8,
    };

    const inst = S{
        .a = 0xBE,
        .b = 0xEF,
        .c = 0xDE,
        .d = 0xA1,
    };
    const inst_bytes = "\xBE\xEF\xDE\xA1";
    const inst2 = bytesAsValue(S, inst_bytes);
    testing.expect(meta.eql(inst, inst2.*));
}

/// Given a pointer to an array of bytes, returns a value of the specified type backed by a
/// copy of those bytes.
pub fn bytesToValue(comptime T: type, bytes: anytype) T {
    return bytesAsValue(T, bytes).*;
}
test "bytesToValue" {
    const deadbeef_bytes = switch (builtin.endian) {
        .Big => "\xDE\xAD\xBE\xEF",
        .Little => "\xEF\xBE\xAD\xDE",
    };

    const deadbeef = bytesToValue(u32, deadbeef_bytes);
    testing.expect(deadbeef == @as(u32, 0xDEADBEEF));
}

//TODO copy also is_volatile, etc. I tried to use @typeInfo, modify child type, use @Type, but ran into issues.
fn BytesAsSliceReturnType(comptime T: type, comptime bytesType: type) type {
    if (!(trait.isSlice(bytesType) and meta.Child(bytesType) == u8) and !(trait.isPtrTo(.Array)(bytesType) and meta.Child(meta.Child(bytesType)) == u8)) {
        @compileError("expected []u8 or *[_]u8, passed " ++ @typeName(bytesType));
    }

    if (trait.isPtrTo(.Array)(bytesType) and @typeInfo(meta.Child(bytesType)).Array.len % @sizeOf(T) != 0) {
        @compileError("number of bytes in " ++ @typeName(bytesType) ++ " is not divisible by size of " ++ @typeName(T));
    }

    const alignment = meta.alignment(bytesType);

    return if (trait.isConstPtr(bytesType)) []align(alignment) const T else []align(alignment) T;
}

pub fn bytesAsSlice(comptime T: type, bytes: anytype) BytesAsSliceReturnType(T, @TypeOf(bytes)) {
    // let's not give an undefined pointer to @ptrCast
    // it may be equal to zero and fail a null check
    if (bytes.len == 0) {
        return &[0]T{};
    }

    const Bytes = @TypeOf(bytes);
    const alignment = comptime meta.alignment(Bytes);

    const cast_target = if (comptime trait.isConstPtr(Bytes)) [*]align(alignment) const T else [*]align(alignment) T;

    return @ptrCast(cast_target, bytes)[0..@divExact(bytes.len, @sizeOf(T))];
}

test "bytesAsSlice" {
    {
        const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
        const slice = bytesAsSlice(u16, bytes[0..]);
        testing.expect(slice.len == 2);
        testing.expect(bigToNative(u16, slice[0]) == 0xDEAD);
        testing.expect(bigToNative(u16, slice[1]) == 0xBEEF);
    }
    {
        const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
        var runtime_zero: usize = 0;
        const slice = bytesAsSlice(u16, bytes[runtime_zero..]);
        testing.expect(slice.len == 2);
        testing.expect(bigToNative(u16, slice[0]) == 0xDEAD);
        testing.expect(bigToNative(u16, slice[1]) == 0xBEEF);
    }
}

test "bytesAsSlice keeps pointer alignment" {
    {
        var bytes = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
        const numbers = bytesAsSlice(u32, bytes[0..]);
        comptime testing.expect(@TypeOf(numbers) == []align(@alignOf(@TypeOf(bytes))) u32);
    }
    {
        var bytes = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
        var runtime_zero: usize = 0;
        const numbers = bytesAsSlice(u32, bytes[runtime_zero..]);
        comptime testing.expect(@TypeOf(numbers) == []align(@alignOf(@TypeOf(bytes))) u32);
    }
}

test "bytesAsSlice on a packed struct" {
    const F = packed struct {
        a: u8,
    };

    var b = [1]u8{9};
    var f = bytesAsSlice(F, &b);
    testing.expect(f[0].a == 9);
}

test "bytesAsSlice with specified alignment" {
    var bytes align(4) = [_]u8{
        0x33,
        0x33,
        0x33,
        0x33,
    };
    const slice: []u32 = std.mem.bytesAsSlice(u32, bytes[0..]);
    testing.expect(slice[0] == 0x33333333);
}

//TODO copy also is_volatile, etc. I tried to use @typeInfo, modify child type, use @Type, but ran into issues.
fn SliceAsBytesReturnType(comptime sliceType: type) type {
    if (!trait.isSlice(sliceType) and !trait.isPtrTo(.Array)(sliceType)) {
        @compileError("expected []T or *[_]T, passed " ++ @typeName(sliceType));
    }

    const alignment = meta.alignment(sliceType);

    return if (trait.isConstPtr(sliceType)) []align(alignment) const u8 else []align(alignment) u8;
}

pub fn sliceAsBytes(slice: anytype) SliceAsBytesReturnType(@TypeOf(slice)) {
    const Slice = @TypeOf(slice);

    // let's not give an undefined pointer to @ptrCast
    // it may be equal to zero and fail a null check
    if (slice.len == 0 and comptime meta.sentinel(Slice) == null) {
        return &[0]u8{};
    }

    const alignment = comptime meta.alignment(Slice);

    const cast_target = if (comptime trait.isConstPtr(Slice)) [*]align(alignment) const u8 else [*]align(alignment) u8;

    return @ptrCast(cast_target, slice)[0 .. slice.len * @sizeOf(meta.Elem(Slice))];
}

test "sliceAsBytes" {
    const bytes = [_]u16{ 0xDEAD, 0xBEEF };
    const slice = sliceAsBytes(bytes[0..]);
    testing.expect(slice.len == 4);
    testing.expect(eql(u8, slice, switch (builtin.endian) {
        .Big => "\xDE\xAD\xBE\xEF",
        .Little => "\xAD\xDE\xEF\xBE",
    }));
}

test "sliceAsBytes with sentinel slice" {
    const empty_string: [:0]const u8 = "";
    const bytes = sliceAsBytes(empty_string);
    testing.expect(bytes.len == 0);
}

test "sliceAsBytes packed struct at runtime and comptime" {
    const Foo = packed struct {
        a: u4,
        b: u4,
    };
    const S = struct {
        fn doTheTest() void {
            var foo: Foo = undefined;
            var slice = sliceAsBytes(@as(*[1]Foo, &foo)[0..1]);
            slice[0] = 0x13;
            switch (builtin.endian) {
                .Big => {
                    testing.expect(foo.a == 0x1);
                    testing.expect(foo.b == 0x3);
                },
                .Little => {
                    testing.expect(foo.a == 0x3);
                    testing.expect(foo.b == 0x1);
                },
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "sliceAsBytes and bytesAsSlice back" {
    testing.expect(@sizeOf(i32) == 4);

    var big_thing_array = [_]i32{ 1, 2, 3, 4 };
    const big_thing_slice: []i32 = big_thing_array[0..];

    const bytes = sliceAsBytes(big_thing_slice);
    testing.expect(bytes.len == 4 * 4);

    bytes[4] = 0;
    bytes[5] = 0;
    bytes[6] = 0;
    bytes[7] = 0;
    testing.expect(big_thing_slice[1] == 0);

    const big_thing_again = bytesAsSlice(i32, bytes);
    testing.expect(big_thing_again[2] == 3);

    big_thing_again[2] = -1;
    testing.expect(bytes[8] == math.maxInt(u8));
    testing.expect(bytes[9] == math.maxInt(u8));
    testing.expect(bytes[10] == math.maxInt(u8));
    testing.expect(bytes[11] == math.maxInt(u8));
}

/// Round an address up to the nearest aligned address
/// The alignment must be a power of 2 and greater than 0.
pub fn alignForward(addr: usize, alignment: usize) usize {
    return alignForwardGeneric(usize, addr, alignment);
}

/// Round an address up to the nearest aligned address
/// The alignment must be a power of 2 and greater than 0.
pub fn alignForwardGeneric(comptime T: type, addr: T, alignment: T) T {
    return alignBackwardGeneric(T, addr + (alignment - 1), alignment);
}

test "alignForward" {
    testing.expect(alignForward(1, 1) == 1);
    testing.expect(alignForward(2, 1) == 2);
    testing.expect(alignForward(1, 2) == 2);
    testing.expect(alignForward(2, 2) == 2);
    testing.expect(alignForward(3, 2) == 4);
    testing.expect(alignForward(4, 2) == 4);
    testing.expect(alignForward(7, 8) == 8);
    testing.expect(alignForward(8, 8) == 8);
    testing.expect(alignForward(9, 8) == 16);
    testing.expect(alignForward(15, 8) == 16);
    testing.expect(alignForward(16, 8) == 16);
    testing.expect(alignForward(17, 8) == 24);
}

/// Round an address up to the previous aligned address
/// Unlike `alignBackward`, `alignment` can be any positive number, not just a power of 2.
pub fn alignBackwardAnyAlign(i: usize, alignment: usize) usize {
    if (@popCount(usize, alignment) == 1)
        return alignBackward(i, alignment);
    assert(alignment != 0);
    return i - @mod(i, alignment);
}

/// Round an address up to the previous aligned address
/// The alignment must be a power of 2 and greater than 0.
pub fn alignBackward(addr: usize, alignment: usize) usize {
    return alignBackwardGeneric(usize, addr, alignment);
}

/// Round an address up to the previous aligned address
/// The alignment must be a power of 2 and greater than 0.
pub fn alignBackwardGeneric(comptime T: type, addr: T, alignment: T) T {
    assert(@popCount(T, alignment) == 1);
    // 000010000 // example alignment
    // 000001111 // subtract 1
    // 111110000 // binary not
    return addr & ~(alignment - 1);
}

/// Returns whether `alignment` is a valid alignment, meaning it is
/// a positive power of 2.
pub fn isValidAlign(alignment: u29) bool {
    return @popCount(u29, alignment) == 1;
}

pub fn isAlignedAnyAlign(i: usize, alignment: usize) bool {
    if (@popCount(usize, alignment) == 1)
        return isAligned(i, alignment);
    assert(alignment != 0);
    return 0 == @mod(i, alignment);
}

/// Given an address and an alignment, return true if the address is a multiple of the alignment
/// The alignment must be a power of 2 and greater than 0.
pub fn isAligned(addr: usize, alignment: usize) bool {
    return isAlignedGeneric(u64, addr, alignment);
}

pub fn isAlignedGeneric(comptime T: type, addr: T, alignment: T) bool {
    return alignBackwardGeneric(T, addr, alignment) == addr;
}

test "isAligned" {
    testing.expect(isAligned(0, 4));
    testing.expect(isAligned(1, 1));
    testing.expect(isAligned(2, 1));
    testing.expect(isAligned(2, 2));
    testing.expect(!isAligned(2, 4));
    testing.expect(isAligned(3, 1));
    testing.expect(!isAligned(3, 2));
    testing.expect(!isAligned(3, 4));
    testing.expect(isAligned(4, 4));
    testing.expect(isAligned(4, 2));
    testing.expect(isAligned(4, 1));
    testing.expect(!isAligned(4, 8));
    testing.expect(!isAligned(4, 16));
}

test "freeing empty string with null-terminated sentinel" {
    const empty_string = try dupeZ(testing.allocator, u8, "");
    testing.allocator.free(empty_string);
}
