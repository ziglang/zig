const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const builtin = @import("builtin");
const mem = @This();
const meta = std.meta;
const trait = meta.trait;
const testing = std.testing;

pub const page_size = switch (builtin.arch) {
    .wasm32, .wasm64 => 64 * 1024,
    else => 4 * 1024,
};

pub const Allocator = struct {
    pub const Error = error{OutOfMemory};

    /// Realloc is used to modify the size or alignment of an existing allocation,
    /// as well as to provide the allocator with an opportunity to move an allocation
    /// to a better location.
    /// When the size/alignment is greater than the previous allocation, this function
    /// returns `error.OutOfMemory` when the requested new allocation could not be granted.
    /// When the size/alignment is less than or equal to the previous allocation,
    /// this function returns `error.OutOfMemory` when the allocator decides the client
    /// would be better off keeping the extra alignment/size. Clients will call
    /// `shrinkFn` when they require the allocator to track a new alignment/size,
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
    reallocFn: fn (
        self: *Allocator,
        /// Guaranteed to be the same as what was returned from most recent call to
        /// `reallocFn` or `shrinkFn`.
        /// If `old_mem.len == 0` then this is a new allocation and `new_byte_count`
        /// is guaranteed to be >= 1.
        old_mem: []u8,
        /// If `old_mem.len == 0` then this is `undefined`, otherwise:
        /// Guaranteed to be the same as what was returned from most recent call to
        /// `reallocFn` or `shrinkFn`.
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
    ) Error![]u8,

    /// This function deallocates memory. It must succeed.
    shrinkFn: fn (
        self: *Allocator,
        /// Guaranteed to be the same as what was returned from most recent call to
        /// `reallocFn` or `shrinkFn`.
        old_mem: []u8,
        /// Guaranteed to be the same as what was returned from most recent call to
        /// `reallocFn` or `shrinkFn`.
        old_alignment: u29,
        /// Guaranteed to be less than or equal to `old_mem.len`.
        new_byte_count: usize,
        /// If `new_byte_count == 0` then this is `undefined`, otherwise:
        /// Guaranteed to be less than or equal to `old_alignment`.
        new_alignment: u29,
    ) []u8,

    /// Returns a pointer to undefined memory.
    /// Call `destroy` with the result to free the memory.
    pub fn create(self: *Allocator, comptime T: type) Error!*T {
        if (@sizeOf(T) == 0) return &(T{});
        const slice = try self.alloc(T, 1);
        return &slice[0];
    }

    /// `ptr` should be the return value of `create`, or otherwise
    /// have the same address and alignment property.
    pub fn destroy(self: *Allocator, ptr: var) void {
        const T = @TypeOf(ptr).Child;
        if (@sizeOf(T) == 0) return;
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(ptr));
        const shrink_result = self.shrinkFn(self, non_const_ptr[0..@sizeOf(T)], @alignOf(T), 0, 1);
        assert(shrink_result.len == 0);
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

    pub fn alignedAlloc(
        self: *Allocator,
        comptime T: type,
        /// null means naturally aligned
        comptime alignment: ?u29,
        n: usize,
    ) Error![]align(alignment orelse @alignOf(T)) T {
        const a = if (alignment) |a| blk: {
            if (a == @alignOf(T)) return alignedAlloc(self, T, null, n);
            break :blk a;
        } else @alignOf(T);

        if (n == 0) {
            return @as([*]align(a) T, undefined)[0..0];
        }

        const byte_count = math.mul(usize, @sizeOf(T), n) catch return Error.OutOfMemory;
        const byte_slice = try self.reallocFn(self, &[0]u8{}, undefined, byte_count, a);
        assert(byte_slice.len == byte_count);
        @memset(byte_slice.ptr, undefined, byte_slice.len);
        if (alignment == null) {
            // TODO This is a workaround for zig not being able to successfully do
            // @bytesToSlice(T, @alignCast(a, byte_slice)) without resolving alignment of T,
            // which causes a circular dependency in async functions which try to heap-allocate
            // their own frame with @Frame(func).
            return @intToPtr([*]T, @ptrToInt(byte_slice.ptr))[0..n];
        } else {
            return @bytesToSlice(T, @alignCast(a, byte_slice));
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
    pub fn realloc(self: *Allocator, old_mem: var, new_n: usize) t: {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        break :t Error![]align(Slice.alignment) Slice.child;
    } {
        const old_alignment = @typeInfo(@TypeOf(old_mem)).Pointer.alignment;
        return self.alignedRealloc(old_mem, old_alignment, new_n);
    }

    /// This is the same as `realloc`, except caller may additionally request
    /// a new alignment, which can be larger, smaller, or the same as the old
    /// allocation.
    pub fn alignedRealloc(
        self: *Allocator,
        old_mem: var,
        comptime new_alignment: u29,
        new_n: usize,
    ) Error![]align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        const T = Slice.child;
        if (old_mem.len == 0) {
            return self.alignedAlloc(T, new_alignment, new_n);
        }
        if (new_n == 0) {
            self.free(old_mem);
            return @as([*]align(new_alignment) T, undefined)[0..0];
        }

        const old_byte_slice = @sliceToBytes(old_mem);
        const byte_count = math.mul(usize, @sizeOf(T), new_n) catch return Error.OutOfMemory;
        const byte_slice = try self.reallocFn(self, old_byte_slice, Slice.alignment, byte_count, new_alignment);
        assert(byte_slice.len == byte_count);
        if (new_n > old_mem.len) {
            @memset(byte_slice.ptr + old_byte_slice.len, undefined, byte_slice.len - old_byte_slice.len);
        }
        return @bytesToSlice(T, @alignCast(new_alignment, byte_slice));
    }

    /// Prefer calling realloc to shrink if you can tolerate failure, such as
    /// in an ArrayList data structure with a storage capacity.
    /// Shrink always succeeds, and `new_n` must be <= `old_mem.len`.
    /// Returned slice has same alignment as old_mem.
    /// Shrinking to 0 is the same as calling `free`.
    pub fn shrink(self: *Allocator, old_mem: var, new_n: usize) t: {
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
        old_mem: var,
        comptime new_alignment: u29,
        new_n: usize,
    ) []align(new_alignment) @typeInfo(@TypeOf(old_mem)).Pointer.child {
        const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
        const T = Slice.child;

        if (new_n == 0) {
            self.free(old_mem);
            return old_mem[0..0];
        }

        assert(new_n <= old_mem.len);
        assert(new_alignment <= Slice.alignment);

        // Here we skip the overflow checking on the multiplication because
        // new_n <= old_mem.len and the multiplication didn't overflow for that operation.
        const byte_count = @sizeOf(T) * new_n;

        const old_byte_slice = @sliceToBytes(old_mem);
        const byte_slice = self.shrinkFn(self, old_byte_slice, Slice.alignment, byte_count, new_alignment);
        assert(byte_slice.len == byte_count);
        return @bytesToSlice(T, @alignCast(new_alignment, byte_slice));
    }

    /// Free an array allocated with `alloc`. To free a single item,
    /// see `destroy`.
    pub fn free(self: *Allocator, memory: var) void {
        const Slice = @typeInfo(@TypeOf(memory)).Pointer;
        const bytes = @sliceToBytes(memory);
        const bytes_len = bytes.len + @boolToInt(Slice.sentinel != null);
        if (bytes_len == 0) return;
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(bytes.ptr));
        const shrink_result = self.shrinkFn(self, non_const_ptr[0..bytes_len], Slice.alignment, 0, 1);
        assert(shrink_result.len == 0);
    }
};

pub const Compare = enum {
    LessThan,
    Equal,
    GreaterThan,
};

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

pub fn set(comptime T: type, dest: []T, value: T) void {
    for (dest) |*d|
        d.* = value;
}

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

pub fn compare(comptime T: type, lhs: []const T, rhs: []const T) Compare {
    const n = math.min(lhs.len, rhs.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (lhs[i] == rhs[i]) {
            continue;
        } else if (lhs[i] < rhs[i]) {
            return Compare.LessThan;
        } else if (lhs[i] > rhs[i]) {
            return Compare.GreaterThan;
        } else {
            unreachable;
        }
    }

    if (lhs.len == rhs.len) {
        return Compare.Equal;
    } else if (lhs.len < rhs.len) {
        return Compare.LessThan;
    } else if (lhs.len > rhs.len) {
        return Compare.GreaterThan;
    }
    unreachable;
}

test "mem.compare" {
    testing.expect(compare(u8, "abcd", "bee") == Compare.LessThan);
    testing.expect(compare(u8, "abc", "abc") == Compare.Equal);
    testing.expect(compare(u8, "abc", "abc0") == Compare.LessThan);
    testing.expect(compare(u8, "", "") == Compare.Equal);
    testing.expect(compare(u8, "", "a") == Compare.LessThan);
}

/// Returns true if lhs < rhs, false otherwise
pub fn lessThan(comptime T: type, lhs: []const T, rhs: []const T) bool {
    var result = compare(T, lhs, rhs);
    if (result == Compare.LessThan) {
        return true;
    } else
        return false;
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

pub fn len(comptime T: type, ptr: [*:0]const T) usize {
    var count: usize = 0;
    while (ptr[count] != 0) : (count += 1) {}
    return count;
}

pub fn toSliceConst(comptime T: type, ptr: [*:0]const T) [:0]const T {
    return ptr[0..len(T, ptr)];
}

pub fn toSlice(comptime T: type, ptr: [*:0]T) [:0]T {
    return ptr[0..len(T, ptr)];
}

/// Returns true if all elements in a slice are equal to the scalar value provided
pub fn allEqual(comptime T: type, slice: []const T, scalar: T) bool {
    for (slice) |item| {
        if (item != scalar) return false;
    }
    return true;
}

/// Copies ::m to newly allocated memory. Caller is responsible to free it.
pub fn dupe(allocator: *Allocator, comptime T: type, m: []const T) ![]T {
    const new_buf = try allocator.alloc(T, m.len);
    copy(T, new_buf, m);
    return new_buf;
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
        builtin.Endian.Big => {
            for (bytes) |b| {
                result = (result << 8) | b;
            }
        },
        builtin.Endian.Little => {
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
    builtin.Endian.Little => readIntNative,
    builtin.Endian.Big => readIntForeign,
};

pub const readIntBig = switch (builtin.endian) {
    builtin.Endian.Little => readIntForeign,
    builtin.Endian.Big => readIntNative,
};

/// Asserts that bytes.len >= T.bit_count / 8. Reads the integer starting from index 0
/// and ignores extra bytes.
/// The bit count of T must be evenly divisible by 8.
/// Assumes the endianness of memory is native. This means the function can
/// simply pointer cast memory.
pub fn readIntSliceNative(comptime T: type, bytes: []const u8) T {
    const n = @divExact(T.bit_count, 8);
    assert(bytes.len >= n);
    // TODO https://github.com/ziglang/zig/issues/863
    return readIntNative(T, @ptrCast(*const [n]u8, bytes.ptr));
}

/// Asserts that bytes.len >= T.bit_count / 8. Reads the integer starting from index 0
/// and ignores extra bytes.
/// The bit count of T must be evenly divisible by 8.
/// Assumes the endianness of memory is foreign, so it must byte-swap.
pub fn readIntSliceForeign(comptime T: type, bytes: []const u8) T {
    return @byteSwap(T, readIntSliceNative(T, bytes));
}

pub const readIntSliceLittle = switch (builtin.endian) {
    builtin.Endian.Little => readIntSliceNative,
    builtin.Endian.Big => readIntSliceForeign,
};

pub const readIntSliceBig = switch (builtin.endian) {
    builtin.Endian.Little => readIntSliceForeign,
    builtin.Endian.Big => readIntSliceNative,
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
    // TODO https://github.com/ziglang/zig/issues/863
    return readInt(T, @ptrCast(*const [n]u8, bytes.ptr), endian);
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
    builtin.Endian.Little => writeIntNative,
    builtin.Endian.Big => writeIntForeign,
};

pub const writeIntBig = switch (builtin.endian) {
    builtin.Endian.Little => writeIntForeign,
    builtin.Endian.Big => writeIntNative,
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

    // TODO I want to call writeIntLittle here but comptime eval facilities aren't good enough
    const uint = @IntType(false, T.bit_count);
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

    // TODO I want to call writeIntBig here but comptime eval facilities aren't good enough
    const uint = @IntType(false, T.bit_count);
    var bits = @truncate(uint, value);
    var index: usize = buffer.len;
    while (index != 0) {
        index -= 1;
        buffer[index] = @truncate(u8, bits);
        bits >>= 8;
    }
}

pub const writeIntSliceNative = switch (builtin.endian) {
    builtin.Endian.Little => writeIntSliceLittle,
    builtin.Endian.Big => writeIntSliceBig,
};

pub const writeIntSliceForeign = switch (builtin.endian) {
    builtin.Endian.Little => writeIntSliceBig,
    builtin.Endian.Big => writeIntSliceLittle,
};

/// Writes a twos-complement integer to memory, with the specified endianness.
/// Asserts that buf.len >= T.bit_count / 8.
/// The bit count of T must be evenly divisible by 8.
/// Any extra bytes in buffer not part of the integer are set to zero, with
/// respect to endianness. To avoid the branch to check for extra buffer bytes,
/// use writeInt instead.
pub fn writeIntSlice(comptime T: type, buffer: []u8, value: T, endian: builtin.Endian) void {
    comptime assert(T.bit_count % 8 == 0);
    switch (endian) {
        builtin.Endian.Little => return writeIntSliceLittle(T, buffer, value),
        builtin.Endian.Big => return writeIntSliceBig(T, buffer, value),
    }
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
/// See also the related function `separate`.
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
/// separate("abc|def||ghi", "|")
/// will return slices for "abc", "def", "", "ghi", null, in that order.
/// If `delimiter` does not exist in buffer,
/// the iterator will return `buffer`, null, in that order.
/// The delimiter length must not be zero.
/// See also the related function `tokenize`.
/// It is planned to rename this function to `split` before 1.0.0, like this:
/// pub fn split(buffer: []const u8, delimiter: []const u8) SplitIterator {
pub fn separate(buffer: []const u8, delimiter: []const u8) SplitIterator {
    assert(delimiter.len != 0);
    return SplitIterator{
        .index = 0,
        .buffer = buffer,
        .delimiter = delimiter,
    };
}

test "mem.separate" {
    var it = separate("abc|def||ghi", "|");
    testing.expect(eql(u8, it.next().?, "abc"));
    testing.expect(eql(u8, it.next().?, "def"));
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(eql(u8, it.next().?, "ghi"));
    testing.expect(it.next() == null);

    it = separate("", "|");
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(it.next() == null);

    it = separate("|", "|");
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(eql(u8, it.next().?, ""));
    testing.expect(it.next() == null);

    it = separate("hello", " ");
    testing.expect(eql(u8, it.next().?, "hello"));
    testing.expect(it.next() == null);
}

test "mem.separate (multibyte)" {
    var it = separate("a, b ,, c, d, e", ", ");
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
    if (slices.len == 0) return &[0]u8{};

    const total_len = blk: {
        var sum: usize = separator.len * (slices.len - 1);
        for (slices) |slice|
            sum += slice.len;
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

    // No need for shrink since buf is exactly the correct size.
    return buf;
}

test "mem.join" {
    var buf: [1024]u8 = undefined;
    const a = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    testing.expect(eql(u8, try join(a, ",", &[_][]const u8{ "a", "b", "c" }), "a,b,c"));
    testing.expect(eql(u8, try join(a, ",", &[_][]const u8{"a"}), "a"));
    testing.expect(eql(u8, try join(a, ",", &[_][]const u8{ "a", "", "b", "", "c" }), "a,,b,,c"));
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
    var buf: [1024]u8 = undefined;
    const a = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    testing.expect(eql(u8, try concat(a, u8, &[_][]const u8{ "abc", "def", "ghi" }), "abcdefghi"));
    testing.expect(eql(u32, try concat(a, u32, &[_][]const u32{
        &[_]u32{ 0, 1 },
        &[_]u32{ 2, 3, 4 },
        &[_]u32{},
        &[_]u32{5},
    }), &[_]u32{ 0, 1, 2, 3, 4, 5 }));
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

/// Converts a little-endian integer to host endianness.
pub fn littleToNative(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        builtin.Endian.Little => x,
        builtin.Endian.Big => @byteSwap(T, x),
    };
}

/// Converts a big-endian integer to host endianness.
pub fn bigToNative(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        builtin.Endian.Little => @byteSwap(T, x),
        builtin.Endian.Big => x,
    };
}

/// Converts an integer from specified endianness to host endianness.
pub fn toNative(comptime T: type, x: T, endianness_of_x: builtin.Endian) T {
    return switch (endianness_of_x) {
        builtin.Endian.Little => littleToNative(T, x),
        builtin.Endian.Big => bigToNative(T, x),
    };
}

/// Converts an integer which has host endianness to the desired endianness.
pub fn nativeTo(comptime T: type, x: T, desired_endianness: builtin.Endian) T {
    return switch (desired_endianness) {
        builtin.Endian.Little => nativeToLittle(T, x),
        builtin.Endian.Big => nativeToBig(T, x),
    };
}

/// Converts an integer which has host endianness to little endian.
pub fn nativeToLittle(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        builtin.Endian.Little => x,
        builtin.Endian.Big => @byteSwap(T, x),
    };
}

/// Converts an integer which has host endianness to big endian.
pub fn nativeToBig(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        builtin.Endian.Little => @byteSwap(T, x),
        builtin.Endian.Big => x,
    };
}

fn AsBytesReturnType(comptime P: type) type {
    if (comptime !trait.isSingleItemPtr(P))
        @compileError("expected single item " ++ "pointer, passed " ++ @typeName(P));

    const size = @as(usize, @sizeOf(meta.Child(P)));
    const alignment = comptime meta.alignment(P);

    if (alignment == 0) {
        if (comptime trait.isConstPtr(P))
            return *const [size]u8;
        return *[size]u8;
    }

    if (comptime trait.isConstPtr(P))
        return *align(alignment) const [size]u8;
    return *align(alignment) [size]u8;
}

///Given a pointer to a single item, returns a slice of the underlying bytes, preserving constness.
pub fn asBytes(ptr: var) AsBytesReturnType(@TypeOf(ptr)) {
    const P = @TypeOf(ptr);
    return @ptrCast(AsBytesReturnType(P), ptr);
}

test "asBytes" {
    const deadbeef = @as(u32, 0xDEADBEEF);
    const deadbeef_bytes = switch (builtin.endian) {
        builtin.Endian.Big => "\xDE\xAD\xBE\xEF",
        builtin.Endian.Little => "\xEF\xBE\xAD\xDE",
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

///Given any value, returns a copy of its bytes in an array.
pub fn toBytes(value: var) [@sizeOf(@TypeOf(value))]u8 {
    return asBytes(&value).*;
}

test "toBytes" {
    var my_bytes = toBytes(@as(u32, 0x12345678));
    switch (builtin.endian) {
        builtin.Endian.Big => testing.expect(eql(u8, &my_bytes, "\x12\x34\x56\x78")),
        builtin.Endian.Little => testing.expect(eql(u8, &my_bytes, "\x78\x56\x34\x12")),
    }

    my_bytes[0] = '\x99';
    switch (builtin.endian) {
        builtin.Endian.Big => testing.expect(eql(u8, &my_bytes, "\x99\x34\x56\x78")),
        builtin.Endian.Little => testing.expect(eql(u8, &my_bytes, "\x99\x56\x34\x12")),
    }
}

fn BytesAsValueReturnType(comptime T: type, comptime B: type) type {
    const size = @as(usize, @sizeOf(T));

    if (comptime !trait.is(builtin.TypeId.Pointer)(B) or
        (meta.Child(B) != [size]u8 and meta.Child(B) != [size:0]u8))
    {
        @compileError("expected *[N]u8 " ++ ", passed " ++ @typeName(B));
    }

    const alignment = comptime meta.alignment(B);

    return if (comptime trait.isConstPtr(B)) *align(alignment) const T else *align(alignment) T;
}

///Given a pointer to an array of bytes, returns a pointer to a value of the specified type
/// backed by those bytes, preserving constness.
pub fn bytesAsValue(comptime T: type, bytes: var) BytesAsValueReturnType(T, @TypeOf(bytes)) {
    return @ptrCast(BytesAsValueReturnType(T, @TypeOf(bytes)), bytes);
}

test "bytesAsValue" {
    const deadbeef = @as(u32, 0xDEADBEEF);
    const deadbeef_bytes = switch (builtin.endian) {
        builtin.Endian.Big => "\xDE\xAD\xBE\xEF",
        builtin.Endian.Little => "\xEF\xBE\xAD\xDE",
    };

    testing.expect(deadbeef == bytesAsValue(u32, deadbeef_bytes).*);

    var codeface_bytes: [4]u8 = switch (builtin.endian) {
        builtin.Endian.Big => "\xC0\xDE\xFA\xCE",
        builtin.Endian.Little => "\xCE\xFA\xDE\xC0",
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

///Given a pointer to an array of bytes, returns a value of the specified type backed by a
/// copy of those bytes.
pub fn bytesToValue(comptime T: type, bytes: var) T {
    return bytesAsValue(T, bytes).*;
}
test "bytesToValue" {
    const deadbeef_bytes = switch (builtin.endian) {
        builtin.Endian.Big => "\xDE\xAD\xBE\xEF",
        builtin.Endian.Little => "\xEF\xBE\xAD\xDE",
    };

    const deadbeef = bytesToValue(u32, deadbeef_bytes);
    testing.expect(deadbeef == @as(u32, 0xDEADBEEF));
}

fn SubArrayPtrReturnType(comptime T: type, comptime length: usize) type {
    if (trait.isConstPtr(T))
        return *const [length]meta.Child(meta.Child(T));
    return *[length]meta.Child(meta.Child(T));
}

///Given a pointer to an array, returns a pointer to a portion of that array, preserving constness.
pub fn subArrayPtr(ptr: var, comptime start: usize, comptime length: usize) SubArrayPtrReturnType(@TypeOf(ptr), length) {
    assert(start + length <= ptr.*.len);

    const ReturnType = SubArrayPtrReturnType(@TypeOf(ptr), length);
    const T = meta.Child(meta.Child(@TypeOf(ptr)));
    return @ptrCast(ReturnType, &ptr[start]);
}

test "subArrayPtr" {
    const a1: [6]u8 = "abcdef".*;
    const sub1 = subArrayPtr(&a1, 2, 3);
    testing.expect(eql(u8, sub1, "cde"));

    var a2: [6]u8 = "abcdef".*;
    var sub2 = subArrayPtr(&a2, 2, 3);

    testing.expect(eql(u8, sub2, "cde"));
    sub2[1] = 'X';
    testing.expect(eql(u8, &a2, "abcXef"));
}

/// Round an address up to the nearest aligned address
/// The alignment must be a power of 2 and greater than 0.
pub fn alignForward(addr: usize, alignment: usize) usize {
    return alignBackward(addr + (alignment - 1), alignment);
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
/// The alignment must be a power of 2 and greater than 0.
pub fn alignBackward(addr: usize, alignment: usize) usize {
    assert(@popCount(usize, alignment) == 1);
    // 000010000 // example addr
    // 000001111 // subtract 1
    // 111110000 // binary not
    return addr & ~(alignment - 1);
}

/// Given an address and an alignment, return true if the address is a multiple of the alignment
/// The alignment must be a power of 2 and greater than 0.
pub fn isAligned(addr: usize, alignment: usize) bool {
    return alignBackward(addr, alignment) == addr;
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
