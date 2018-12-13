const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const builtin = @import("builtin");
const mem = @This();
const meta = std.meta;
const trait = meta.trait;

pub const Allocator = struct {
    pub const Error = error{OutOfMemory};

    /// Allocate byte_count bytes and return them in a slice, with the
    /// slice's pointer aligned at least to alignment bytes.
    /// The returned newly allocated memory is undefined.
    /// `alignment` is guaranteed to be >= 1
    /// `alignment` is guaranteed to be a power of 2
    allocFn: fn (self: *Allocator, byte_count: usize, alignment: u29) Error![]u8,

    /// If `new_byte_count > old_mem.len`:
    /// * `old_mem.len` is the same as what was returned from allocFn or reallocFn.
    /// * alignment >= alignment of old_mem.ptr
    ///
    /// If `new_byte_count <= old_mem.len`:
    /// * this function must return successfully.
    /// * alignment <= alignment of old_mem.ptr
    ///
    /// When `reallocFn` returns,
    /// `return_value[0..min(old_mem.len, new_byte_count)]` must be the same
    /// as `old_mem` was when `reallocFn` is called. The bytes of
    /// `return_value[old_mem.len..]` have undefined values.
    /// `alignment` is guaranteed to be >= 1
    /// `alignment` is guaranteed to be a power of 2
    reallocFn: fn (self: *Allocator, old_mem: []u8, new_byte_count: usize, alignment: u29) Error![]u8,

    /// Guaranteed: `old_mem.len` is the same as what was returned from `allocFn` or `reallocFn`
    freeFn: fn (self: *Allocator, old_mem: []u8) void,

    /// Call `destroy` with the result
    /// TODO this is deprecated. use createOne instead
    pub fn create(self: *Allocator, init: var) Error!*@typeOf(init) {
        const T = @typeOf(init);
        if (@sizeOf(T) == 0) return &(T{});
        const slice = try self.alloc(T, 1);
        const ptr = &slice[0];
        ptr.* = init;
        return ptr;
    }

    /// Call `destroy` with the result.
    /// Returns undefined memory.
    pub fn createOne(self: *Allocator, comptime T: type) Error!*T {
        if (@sizeOf(T) == 0) return &(T{});
        const slice = try self.alloc(T, 1);
        return &slice[0];
    }

    /// `ptr` should be the return value of `create`
    pub fn destroy(self: *Allocator, ptr: var) void {
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(ptr));
        self.freeFn(self, non_const_ptr[0..@sizeOf(@typeOf(ptr).Child)]);
    }

    pub fn alloc(self: *Allocator, comptime T: type, n: usize) ![]T {
        return self.alignedAlloc(T, @alignOf(T), n);
    }

    pub fn alignedAlloc(self: *Allocator, comptime T: type, comptime alignment: u29, n: usize) ![]align(alignment) T {
        if (n == 0) {
            return ([*]align(alignment) T)(undefined)[0..0];
        }
        const byte_count = math.mul(usize, @sizeOf(T), n) catch return Error.OutOfMemory;
        const byte_slice = try self.allocFn(self, byte_count, alignment);
        assert(byte_slice.len == byte_count);
        // This loop gets optimized out in ReleaseFast mode
        for (byte_slice) |*byte| {
            byte.* = undefined;
        }
        return @bytesToSlice(T, @alignCast(alignment, byte_slice));
    }

    pub fn realloc(self: *Allocator, comptime T: type, old_mem: []T, n: usize) ![]T {
        return self.alignedRealloc(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
    }

    pub fn alignedRealloc(self: *Allocator, comptime T: type, comptime alignment: u29, old_mem: []align(alignment) T, n: usize) ![]align(alignment) T {
        if (old_mem.len == 0) {
            return self.alignedAlloc(T, alignment, n);
        }
        if (n == 0) {
            self.free(old_mem);
            return ([*]align(alignment) T)(undefined)[0..0];
        }

        const old_byte_slice = @sliceToBytes(old_mem);
        const byte_count = math.mul(usize, @sizeOf(T), n) catch return Error.OutOfMemory;
        const byte_slice = try self.reallocFn(self, old_byte_slice, byte_count, alignment);
        assert(byte_slice.len == byte_count);
        if (n > old_mem.len) {
            // This loop gets optimized out in ReleaseFast mode
            for (byte_slice[old_byte_slice.len..]) |*byte| {
                byte.* = undefined;
            }
        }
        return @bytesToSlice(T, @alignCast(alignment, byte_slice));
    }

    /// Reallocate, but `n` must be less than or equal to `old_mem.len`.
    /// Unlike `realloc`, this function cannot fail.
    /// Shrinking to 0 is the same as calling `free`.
    pub fn shrink(self: *Allocator, comptime T: type, old_mem: []T, n: usize) []T {
        return self.alignedShrink(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
    }

    pub fn alignedShrink(self: *Allocator, comptime T: type, comptime alignment: u29, old_mem: []align(alignment) T, n: usize) []align(alignment) T {
        if (n == 0) {
            self.free(old_mem);
            return old_mem[0..0];
        }

        assert(n <= old_mem.len);

        // Here we skip the overflow checking on the multiplication because
        // n <= old_mem.len and the multiplication didn't overflow for that operation.
        const byte_count = @sizeOf(T) * n;

        const byte_slice = self.reallocFn(self, @sliceToBytes(old_mem), byte_count, alignment) catch unreachable;
        assert(byte_slice.len == byte_count);
        return @bytesToSlice(T, @alignCast(alignment, byte_slice));
    }

    pub fn free(self: *Allocator, memory: var) void {
        const bytes = @sliceToBytes(memory);
        if (bytes.len == 0) return;
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(bytes.ptr));
        self.freeFn(self, non_const_ptr[0..bytes.len]);
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
    var a = []u8{0xfe} ** 8;
    var b = []u8{0xfe} ** 8;

    set(u8, a[0..], 0);
    secureZero(u8, b[0..]);

    assert(eql(u8, a[0..], b[0..]));
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
    assert(compare(u8, "abcd", "bee") == Compare.LessThan);
    assert(compare(u8, "abc", "abc") == Compare.Equal);
    assert(compare(u8, "abc", "abc0") == Compare.LessThan);
    assert(compare(u8, "", "") == Compare.Equal);
    assert(compare(u8, "", "a") == Compare.LessThan);
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
    assert(lessThan(u8, "abcd", "bee"));
    assert(!lessThan(u8, "abc", "abc"));
    assert(lessThan(u8, "abc", "abc0"));
    assert(!lessThan(u8, "", ""));
    assert(lessThan(u8, "", "a"));
}

/// Compares two slices and returns whether they are equal.
pub fn eql(comptime T: type, a: []const T, b: []const T) bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

pub fn len(comptime T: type, ptr: [*]const T) usize {
    var count: usize = 0;
    while (ptr[count] != 0) : (count += 1) {}
    return count;
}

pub fn toSliceConst(comptime T: type, ptr: [*]const T) []const T {
    return ptr[0..len(T, ptr)];
}

pub fn toSlice(comptime T: type, ptr: [*]T) []T {
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
    assert(eql(u8, trimLeft(u8, " foo\n ", " \n"), "foo\n "));
    assert(eql(u8, trimRight(u8, " foo\n ", " \n"), " foo"));
    assert(eql(u8, trim(u8, " foo\n ", " \n"), "foo"));
    assert(eql(u8, trim(u8, "foo", " \n"), "foo"));
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
    assert(indexOf(u8, "one two three four", "four").? == 14);
    assert(lastIndexOf(u8, "one two three two four", "two").? == 14);
    assert(indexOf(u8, "one two three four", "gour") == null);
    assert(lastIndexOf(u8, "one two three four", "gour") == null);
    assert(indexOf(u8, "foo", "foo").? == 0);
    assert(lastIndexOf(u8, "foo", "foo").? == 0);
    assert(indexOf(u8, "foo", "fool") == null);
    assert(lastIndexOf(u8, "foo", "lfoo") == null);
    assert(lastIndexOf(u8, "foo", "fool") == null);

    assert(indexOf(u8, "foo foo", "foo").? == 0);
    assert(lastIndexOf(u8, "foo foo", "foo").? == 4);
    assert(lastIndexOfAny(u8, "boo, cat", "abo").? == 6);
    assert(lastIndexOfScalar(u8, "boo", 'o').? == 2);
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
                result = result | (ReturnType(b) << @intCast(ShiftType, index * 8));
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
pub fn readIntNative(comptime T: type, bytes: *const [@sizeOf(T)]u8) T {
    comptime assert(T.bit_count % 8 == 0);
    return @ptrCast(*align(1) const T, bytes).*;
}

/// Reads an integer from memory with bit count specified by T.
/// The bit count of T must be evenly divisible by 8.
/// This function cannot fail and cannot cause undefined behavior.
/// Assumes the endianness of memory is foreign, so it must byte-swap.
pub fn readIntForeign(comptime T: type, bytes: *const [@sizeOf(T)]u8) T {
    comptime assert(T.bit_count % 8 == 0);
    return @bswap(T, @ptrCast(*align(1) const T, bytes).*);
}

pub const readIntLittle = switch (builtin.endian) {
    builtin.Endian.Little => readIntNative,
    builtin.Endian.Big => readIntForeign,
};

pub const readIntBig = switch (builtin.endian) {
    builtin.Endian.Little => readIntForeign,
    builtin.Endian.Big => readIntNative,
};

/// Asserts that bytes.len >= @sizeOf(T). Reads the integer starting from index 0
/// and ignores extra bytes.
/// Note that @sizeOf(u24) is 3.
/// The bit count of T must be evenly divisible by 8.
/// Assumes the endianness of memory is native. This means the function can
/// simply pointer cast memory.
pub fn readIntSliceNative(comptime T: type, bytes: []const u8) T {
    assert(@sizeOf(u24) == 3);
    assert(bytes.len >= @sizeOf(T));
    // TODO https://github.com/ziglang/zig/issues/863
    return readIntNative(T, @ptrCast(*const [@sizeOf(T)]u8, bytes.ptr));
}

/// Asserts that bytes.len >= @sizeOf(T). Reads the integer starting from index 0
/// and ignores extra bytes.
/// Note that @sizeOf(u24) is 3.
/// The bit count of T must be evenly divisible by 8.
/// Assumes the endianness of memory is foreign, so it must byte-swap.
pub fn readIntSliceForeign(comptime T: type, bytes: []const u8) T {
    assert(@sizeOf(u24) == 3);
    assert(bytes.len >= @sizeOf(T));
    // TODO https://github.com/ziglang/zig/issues/863
    return readIntForeign(T, @ptrCast(*const [@sizeOf(T)]u8, bytes.ptr));
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
pub fn readInt(comptime T: type, bytes: *const [@sizeOf(T)]u8, endian: builtin.Endian) T {
    if (endian == builtin.endian) {
        return readIntNative(T, bytes);
    } else {
        return readIntForeign(T, bytes);
    }
}

/// Asserts that bytes.len >= @sizeOf(T). Reads the integer starting from index 0
/// and ignores extra bytes.
/// Note that @sizeOf(u24) is 3.
/// The bit count of T must be evenly divisible by 8.
pub fn readIntSlice(comptime T: type, bytes: []const u8, endian: builtin.Endian) T {
    assert(@sizeOf(u24) == 3);
    assert(bytes.len >= @sizeOf(T));
    // TODO https://github.com/ziglang/zig/issues/863
    return readInt(T, @ptrCast(*const [@sizeOf(T)]u8, bytes.ptr), endian);
}

test "readIntBig and readIntLittle" {
    assert(readIntSliceBig(u0, []u8{}) == 0x0);
    assert(readIntSliceLittle(u0, []u8{}) == 0x0);

    assert(readIntSliceBig(u8, []u8{0x32}) == 0x32);
    assert(readIntSliceLittle(u8, []u8{0x12}) == 0x12);

    assert(readIntSliceBig(u16, []u8{ 0x12, 0x34 }) == 0x1234);
    assert(readIntSliceLittle(u16, []u8{ 0x12, 0x34 }) == 0x3412);

    assert(readIntSliceBig(u72, []u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x24 }) == 0x123456789abcdef024);
    assert(readIntSliceLittle(u72, []u8{ 0xec, 0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe }) == 0xfedcba9876543210ec);

    assert(readIntSliceBig(i8, []u8{0xff}) == -1);
    assert(readIntSliceLittle(i8, []u8{0xfe}) == -2);

    assert(readIntSliceBig(i16, []u8{ 0xff, 0xfd }) == -3);
    assert(readIntSliceLittle(i16, []u8{ 0xfc, 0xff }) == -4);
}

/// Writes an integer to memory, storing it in twos-complement.
/// This function always succeeds, has defined behavior for all inputs, and
/// accepts any integer bit width.
/// This function stores in native endian, which means it is implemented as a simple
/// memory store.
pub fn writeIntNative(comptime T: type, buf: *[@sizeOf(T)]u8, value: T) void {
    @ptrCast(*align(1) T, buf).* = value;
}

/// Writes an integer to memory, storing it in twos-complement.
/// This function always succeeds, has defined behavior for all inputs, but
/// the integer bit width must be divisible by 8.
/// This function stores in foreign endian, which means it does a @bswap first.
pub fn writeIntForeign(comptime T: type, buf: *[@sizeOf(T)]u8, value: T) void {
    @ptrCast(*align(1) T, buf).* = @bswap(T, value);
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
pub fn writeInt(comptime T: type, buffer: *[@sizeOf(T)]u8, value: T, endian: builtin.Endian) void {
    comptime assert(T.bit_count % 8 == 0);
    if (endian == builtin.endian) {
        return writeIntNative(T, buffer, value);
    } else {
        return writeIntForeign(T, buffer, value);
    }
}

/// Writes a twos-complement little-endian integer to memory.
/// Asserts that buf.len >= @sizeOf(T). Note that @sizeOf(u24) is 3.
/// The bit count of T must be divisible by 8.
/// Any extra bytes in buffer after writing the integer are set to zero. To
/// avoid the branch to check for extra buffer bytes, use writeIntLittle
/// instead.
pub fn writeIntSliceLittle(comptime T: type, buffer: []u8, value: T) void {
    comptime assert(@sizeOf(u24) == 3);
    comptime assert(T.bit_count % 8 == 0);
    assert(buffer.len >= @sizeOf(T));

    // TODO I want to call writeIntLittle here but comptime eval facilities aren't good enough
    const uint = @IntType(false, T.bit_count);
    var bits = @truncate(uint, value);
    for (buffer) |*b| {
        b.* = @truncate(u8, bits);
        bits >>= 8;
    }
}

/// Writes a twos-complement big-endian integer to memory.
/// Asserts that buffer.len >= @sizeOf(T). Note that @sizeOf(u24) is 3.
/// The bit count of T must be divisible by 8.
/// Any extra bytes in buffer before writing the integer are set to zero. To
/// avoid the branch to check for extra buffer bytes, use writeIntBig instead.
pub fn writeIntSliceBig(comptime T: type, buffer: []u8, value: T) void {
    comptime assert(@sizeOf(u24) == 3);
    comptime assert(T.bit_count % 8 == 0);
    assert(buffer.len >= @sizeOf(T));

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
/// Asserts that buf.len >= @sizeOf(T). Note that @sizeOf(u24) is 3.
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
    assert(eql_slice_u8(buf0[0..], []u8{}));
    writeIntLittle(u0, &buf0, 0x0);
    assert(eql_slice_u8(buf0[0..], []u8{}));

    writeIntBig(u8, &buf1, 0x12);
    assert(eql_slice_u8(buf1[0..], []u8{0x12}));
    writeIntLittle(u8, &buf1, 0x34);
    assert(eql_slice_u8(buf1[0..], []u8{0x34}));

    writeIntBig(u16, &buf2, 0x1234);
    assert(eql_slice_u8(buf2[0..], []u8{ 0x12, 0x34 }));
    writeIntLittle(u16, &buf2, 0x5678);
    assert(eql_slice_u8(buf2[0..], []u8{ 0x78, 0x56 }));

    writeIntBig(u72, &buf9, 0x123456789abcdef024);
    assert(eql_slice_u8(buf9[0..], []u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x24 }));
    writeIntLittle(u72, &buf9, 0xfedcba9876543210ec);
    assert(eql_slice_u8(buf9[0..], []u8{ 0xec, 0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe }));

    writeIntBig(i8, &buf1, -1);
    assert(eql_slice_u8(buf1[0..], []u8{0xff}));
    writeIntLittle(i8, &buf1, -2);
    assert(eql_slice_u8(buf1[0..], []u8{0xfe}));

    writeIntBig(i16, &buf2, -3);
    assert(eql_slice_u8(buf2[0..], []u8{ 0xff, 0xfd }));
    writeIntLittle(i16, &buf2, -4);
    assert(eql_slice_u8(buf2[0..], []u8{ 0xfc, 0xff }));
}

pub fn hash_slice_u8(k: []const u8) u32 {
    // FNV 32-bit hash
    var h: u32 = 2166136261;
    for (k) |b| {
        h = (h ^ b) *% 16777619;
    }
    return h;
}

pub fn eql_slice_u8(a: []const u8, b: []const u8) bool {
    return eql(u8, a, b);
}

/// Returns an iterator that iterates over the slices of `buffer` that are not
/// any of the bytes in `split_bytes`.
/// split("   abc def    ghi  ", " ")
/// Will return slices for "abc", "def", "ghi", null, in that order.
pub fn split(buffer: []const u8, split_bytes: []const u8) SplitIterator {
    return SplitIterator{
        .index = 0,
        .buffer = buffer,
        .split_bytes = split_bytes,
    };
}

test "mem.split" {
    var it = split("   abc def   ghi  ", " ");
    assert(eql(u8, it.next().?, "abc"));
    assert(eql(u8, it.next().?, "def"));
    assert(eql(u8, it.next().?, "ghi"));
    assert(it.next() == null);
}

pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
    return if (needle.len > haystack.len) false else eql(T, haystack[0..needle.len], needle);
}

test "mem.startsWith" {
    assert(startsWith(u8, "Bob", "Bo"));
    assert(!startsWith(u8, "Needle in haystack", "haystack"));
}

pub fn endsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
    return if (needle.len > haystack.len) false else eql(T, haystack[haystack.len - needle.len ..], needle);
}

test "mem.endsWith" {
    assert(endsWith(u8, "Needle in haystack", "haystack"));
    assert(!endsWith(u8, "Bob", "Bo"));
}

pub const SplitIterator = struct {
    buffer: []const u8,
    split_bytes: []const u8,
    index: usize,

    pub fn next(self: *SplitIterator) ?[]const u8 {
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
    pub fn rest(self: *const SplitIterator) []const u8 {
        // move to beginning of token
        var index: usize = self.index;
        while (index < self.buffer.len and self.isSplitByte(self.buffer[index])) : (index += 1) {}
        return self.buffer[index..];
    }

    fn isSplitByte(self: *const SplitIterator, byte: u8) bool {
        for (self.split_bytes) |split_byte| {
            if (byte == split_byte) {
                return true;
            }
        }
        return false;
    }
};

/// Naively combines a series of strings with a separator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: *Allocator, sep: u8, strings: ...) ![]u8 {
    comptime assert(strings.len >= 1);
    var total_strings_len: usize = strings.len; // 1 sep per string
    {
        comptime var string_i = 0;
        inline while (string_i < strings.len) : (string_i += 1) {
            const arg = ([]const u8)(strings[string_i]);
            total_strings_len += arg.len;
        }
    }

    const buf = try allocator.alloc(u8, total_strings_len);
    errdefer allocator.free(buf);

    var buf_index: usize = 0;
    comptime var string_i = 0;
    inline while (true) {
        const arg = ([]const u8)(strings[string_i]);
        string_i += 1;
        copy(u8, buf[buf_index..], arg);
        buf_index += arg.len;
        if (string_i >= strings.len) break;
        if (buf[buf_index - 1] != sep) {
            buf[buf_index] = sep;
            buf_index += 1;
        }
    }

    return allocator.shrink(u8, buf, buf_index);
}

test "mem.join" {
    assert(eql(u8, try join(debug.global_allocator, ',', "a", "b", "c"), "a,b,c"));
    assert(eql(u8, try join(debug.global_allocator, ',', "a"), "a"));
}

test "testStringEquality" {
    assert(eql(u8, "abcd", "abcd"));
    assert(!eql(u8, "abcdef", "abZdef"));
    assert(!eql(u8, "abcdefg", "abcdef"));
}

test "testReadInt" {
    testReadIntImpl();
    comptime testReadIntImpl();
}
fn testReadIntImpl() void {
    {
        const bytes = []u8{
            0x12,
            0x34,
            0x56,
            0x78,
        };
        assert(readInt(u32, &bytes, builtin.Endian.Big) == 0x12345678);
        assert(readIntBig(u32, &bytes) == 0x12345678);
        assert(readIntBig(i32, &bytes) == 0x12345678);
        assert(readInt(u32, &bytes, builtin.Endian.Little) == 0x78563412);
        assert(readIntLittle(u32, &bytes) == 0x78563412);
        assert(readIntLittle(i32, &bytes) == 0x78563412);
    }
    {
        const buf = []u8{
            0x00,
            0x00,
            0x12,
            0x34,
        };
        const answer = readInt(u32, &buf, builtin.Endian.Big);
        assert(answer == 0x00001234);
    }
    {
        const buf = []u8{
            0x12,
            0x34,
            0x00,
            0x00,
        };
        const answer = readInt(u32, &buf, builtin.Endian.Little);
        assert(answer == 0x00003412);
    }
    {
        const bytes = []u8{
            0xff,
            0xfe,
        };
        assert(readIntBig(u16, &bytes) == 0xfffe);
        assert(readIntBig(i16, &bytes) == -0x0002);
        assert(readIntLittle(u16, &bytes) == 0xfeff);
        assert(readIntLittle(i16, &bytes) == -0x0101);
    }
}

test "std.mem.writeIntSlice" {
    testWriteIntImpl();
    comptime testWriteIntImpl();
}
fn testWriteIntImpl() void {
    var bytes: [8]u8 = undefined;

    writeIntSlice(u0, bytes[0..], 0, builtin.Endian.Big);
    assert(eql(u8, bytes, []u8{
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    }));

    writeIntSlice(u0, bytes[0..], 0, builtin.Endian.Little);
    assert(eql(u8, bytes, []u8{
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    }));

    writeIntSlice(u64, bytes[0..], 0x12345678CAFEBABE, builtin.Endian.Big);
    assert(eql(u8, bytes, []u8{
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
    assert(eql(u8, bytes, []u8{
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
    assert(eql(u8, bytes, []u8{
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
    assert(eql(u8, bytes, []u8{
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
    assert(eql(u8, bytes, []u8{
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
    assert(eql(u8, bytes, []u8{
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
    assert(min(u8, "abcdefg") == 'a');
}

pub fn max(comptime T: type, slice: []const T) T {
    var best = slice[0];
    for (slice[1..]) |item| {
        best = math.max(best, item);
    }
    return best;
}

test "mem.max" {
    assert(max(u8, "abcdefg") == 'g');
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

test "std.mem.reverse" {
    var arr = []i32{
        5,
        3,
        1,
        2,
        4,
    };
    reverse(i32, arr[0..]);

    assert(eql(i32, arr, []i32{
        4,
        2,
        1,
        3,
        5,
    }));
}

/// In-place rotation of the values in an array ([0 1 2 3] becomes [1 2 3 0] if we rotate by 1)
/// Assumes 0 <= amount <= items.len
pub fn rotate(comptime T: type, items: []T, amount: usize) void {
    reverse(T, items[0..amount]);
    reverse(T, items[amount..]);
    reverse(T, items);
}

test "std.mem.rotate" {
    var arr = []i32{
        5,
        3,
        1,
        2,
        4,
    };
    rotate(i32, arr[0..], 2);

    assert(eql(i32, arr, []i32{
        1,
        2,
        4,
        5,
        3,
    }));
}

/// Converts a little-endian integer to host endianness.
pub fn littleToNative(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        builtin.Endian.Little => x,
        builtin.Endian.Big => @bswap(T, x),
    };
}

/// Converts a big-endian integer to host endianness.
pub fn bigToNative(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        builtin.Endian.Little => @bswap(T, x),
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
        builtin.Endian.Big => @bswap(T, x),
    };
}

/// Converts an integer which has host endianness to big endian.
pub fn nativeToBig(comptime T: type, x: T) T {
    return switch (builtin.endian) {
        builtin.Endian.Little => @bswap(T, x),
        builtin.Endian.Big => x,
    };
}

fn AsBytesReturnType(comptime P: type) type {
    if (comptime !trait.isSingleItemPtr(P))
        @compileError("expected single item " ++ "pointer, passed " ++ @typeName(P));

    const size = usize(@sizeOf(meta.Child(P)));
    const alignment = comptime meta.alignment(P);

    if (comptime trait.isConstPtr(P))
        return *align(alignment) const [size]u8;
    return *align(alignment) [size]u8;
}

///Given a pointer to a single item, returns a slice of the underlying bytes, preserving constness.
pub fn asBytes(ptr: var) AsBytesReturnType(@typeOf(ptr)) {
    const P = @typeOf(ptr);
    return @ptrCast(AsBytesReturnType(P), ptr);
}

test "std.mem.asBytes" {
    const deadbeef = u32(0xDEADBEEF);
    const deadbeef_bytes = switch (builtin.endian) {
        builtin.Endian.Big => "\xDE\xAD\xBE\xEF",
        builtin.Endian.Little => "\xEF\xBE\xAD\xDE",
    };

    debug.assert(std.mem.eql(u8, asBytes(&deadbeef), deadbeef_bytes));

    var codeface = u32(0xC0DEFACE);
    for (asBytes(&codeface).*) |*b|
        b.* = 0;
    debug.assert(codeface == 0);

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
    debug.assert(std.mem.eql(u8, asBytes(&inst), "\xBE\xEF\xDE\xA1"));
}

///Given any value, returns a copy of its bytes in an array.
pub fn toBytes(value: var) [@sizeOf(@typeOf(value))]u8 {
    return asBytes(&value).*;
}

test "std.mem.toBytes" {
    var my_bytes = toBytes(u32(0x12345678));
    switch (builtin.endian) {
        builtin.Endian.Big => debug.assert(std.mem.eql(u8, my_bytes, "\x12\x34\x56\x78")),
        builtin.Endian.Little => debug.assert(std.mem.eql(u8, my_bytes, "\x78\x56\x34\x12")),
    }

    my_bytes[0] = '\x99';
    switch (builtin.endian) {
        builtin.Endian.Big => debug.assert(std.mem.eql(u8, my_bytes, "\x99\x34\x56\x78")),
        builtin.Endian.Little => debug.assert(std.mem.eql(u8, my_bytes, "\x99\x56\x34\x12")),
    }
}

fn BytesAsValueReturnType(comptime T: type, comptime B: type) type {
    const size = usize(@sizeOf(T));

    if (comptime !trait.is(builtin.TypeId.Pointer)(B) or meta.Child(B) != [size]u8) {
        @compileError("expected *[N]u8 " ++ ", passed " ++ @typeName(B));
    }

    const alignment = comptime meta.alignment(B);

    return if (comptime trait.isConstPtr(B)) *align(alignment) const T else *align(alignment) T;
}

///Given a pointer to an array of bytes, returns a pointer to a value of the specified type
/// backed by those bytes, preserving constness.
pub fn bytesAsValue(comptime T: type, bytes: var) BytesAsValueReturnType(T, @typeOf(bytes)) {
    return @ptrCast(BytesAsValueReturnType(T, @typeOf(bytes)), bytes);
}

test "std.mem.bytesAsValue" {
    const deadbeef = u32(0xDEADBEEF);
    const deadbeef_bytes = switch (builtin.endian) {
        builtin.Endian.Big => "\xDE\xAD\xBE\xEF",
        builtin.Endian.Little => "\xEF\xBE\xAD\xDE",
    };

    debug.assert(deadbeef == bytesAsValue(u32, &deadbeef_bytes).*);

    var codeface_bytes = switch (builtin.endian) {
        builtin.Endian.Big => "\xC0\xDE\xFA\xCE",
        builtin.Endian.Little => "\xCE\xFA\xDE\xC0",
    };
    var codeface = bytesAsValue(u32, &codeface_bytes);
    debug.assert(codeface.* == 0xC0DEFACE);
    codeface.* = 0;
    for (codeface_bytes) |b|
        debug.assert(b == 0);

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
    const inst2 = bytesAsValue(S, &inst_bytes);
    debug.assert(meta.eql(inst, inst2.*));
}

///Given a pointer to an array of bytes, returns a value of the specified type backed by a
/// copy of those bytes.
pub fn bytesToValue(comptime T: type, bytes: var) T {
    return bytesAsValue(T, &bytes).*;
}
test "std.mem.bytesToValue" {
    const deadbeef_bytes = switch (builtin.endian) {
        builtin.Endian.Big => "\xDE\xAD\xBE\xEF",
        builtin.Endian.Little => "\xEF\xBE\xAD\xDE",
    };

    const deadbeef = bytesToValue(u32, deadbeef_bytes);
    debug.assert(deadbeef == u32(0xDEADBEEF));
}

fn SubArrayPtrReturnType(comptime T: type, comptime length: usize) type {
    if (trait.isConstPtr(T))
        return *const [length]meta.Child(meta.Child(T));
    return *[length]meta.Child(meta.Child(T));
}

///Given a pointer to an array, returns a pointer to a portion of that array, preserving constness.
pub fn subArrayPtr(ptr: var, comptime start: usize, comptime length: usize) SubArrayPtrReturnType(@typeOf(ptr), length) {
    debug.assert(start + length <= ptr.*.len);

    const ReturnType = SubArrayPtrReturnType(@typeOf(ptr), length);
    const T = meta.Child(meta.Child(@typeOf(ptr)));
    return @ptrCast(ReturnType, &ptr[start]);
}

test "std.mem.subArrayPtr" {
    const a1 = "abcdef";
    const sub1 = subArrayPtr(&a1, 2, 3);
    debug.assert(std.mem.eql(u8, sub1.*, "cde"));

    var a2 = "abcdef";
    var sub2 = subArrayPtr(&a2, 2, 3);

    debug.assert(std.mem.eql(u8, sub2, "cde"));
    sub2[1] = 'X';
    debug.assert(std.mem.eql(u8, a2, "abcXef"));
}
