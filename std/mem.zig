const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const builtin = @import("builtin");
const mem = this;

pub const Allocator = struct {
    const Error = error{OutOfMemory};

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
    /// The returned newly allocated memory is undefined.
    /// `alignment` is guaranteed to be >= 1
    /// `alignment` is guaranteed to be a power of 2
    reallocFn: fn (self: *Allocator, old_mem: []u8, new_byte_count: usize, alignment: u29) Error![]u8,

    /// Guaranteed: `old_mem.len` is the same as what was returned from `allocFn` or `reallocFn`
    freeFn: fn (self: *Allocator, old_mem: []u8) void,

    /// Call `destroy` with the result
    pub fn create(self: *Allocator, init: var) Error!*@typeOf(init) {
        const T = @typeOf(init);
        if (@sizeOf(T) == 0) return &(T{});
        const slice = try self.alloc(T, 1);
        const ptr = &slice[0];
        ptr.* = init;
        return ptr;
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
            return self.alloc(T, n);
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

/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
pub fn copy(comptime T: type, dest: []T, source: []const T) void {
    // TODO instead of manually doing this check for the whole array
    // and turning off runtime safety, the compiler should detect loops like
    // this and automatically omit safety checks for loops
    @setRuntimeSafety(false);
    assert(dest.len >= source.len);
    for (source) |s, i|
        dest[i] = s;
}

pub fn set(comptime T: type, dest: []T, value: T) void {
    for (dest) |*d|
        d.* = value;
}

/// Returns true if lhs < rhs, false otherwise
pub fn lessThan(comptime T: type, lhs: []const T, rhs: []const T) bool {
    const n = math.min(lhs.len, rhs.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (lhs[i] == rhs[i]) continue;
        return lhs[i] < rhs[i];
    }

    return lhs.len < rhs.len;
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
/// See also ::readIntBE or ::readIntLE.
pub fn readInt(bytes: []const u8, comptime T: type, endian: builtin.Endian) T {
    if (T.bit_count == 8) {
        return bytes[0];
    }
    var result: T = 0;
    switch (endian) {
        builtin.Endian.Big => {
            for (bytes) |b| {
                result = (result << 8) | b;
            }
        },
        builtin.Endian.Little => {
            const ShiftType = math.Log2Int(T);
            for (bytes) |b, index| {
                result = result | (T(b) << @intCast(ShiftType, index * 8));
            }
        },
    }
    return result;
}

/// Reads a big-endian int of type T from bytes.
/// bytes.len must be exactly @sizeOf(T).
pub fn readIntBE(comptime T: type, bytes: []const u8) T {
    if (T.is_signed) {
        return @bitCast(T, readIntBE(@IntType(false, T.bit_count), bytes));
    }
    assert(bytes.len == @sizeOf(T));
    var result: T = 0;
    {
        comptime var i = 0;
        inline while (i < @sizeOf(T)) : (i += 1) {
            result = (result << 8) | T(bytes[i]);
        }
    }
    return result;
}

/// Reads a little-endian int of type T from bytes.
/// bytes.len must be exactly @sizeOf(T).
pub fn readIntLE(comptime T: type, bytes: []const u8) T {
    if (T.is_signed) {
        return @bitCast(T, readIntLE(@IntType(false, T.bit_count), bytes));
    }
    assert(bytes.len == @sizeOf(T));
    var result: T = 0;
    {
        comptime var i = 0;
        inline while (i < @sizeOf(T)) : (i += 1) {
            result |= T(bytes[i]) << i * 8;
        }
    }
    return result;
}

/// Writes an integer to memory with size equal to bytes.len. Pads with zeroes
/// to fill the entire buffer provided.
/// value must be an integer.
pub fn writeInt(buf: []u8, value: var, endian: builtin.Endian) void {
    const uint = @IntType(false, @typeOf(value).bit_count);
    var bits = @truncate(uint, value);
    switch (endian) {
        builtin.Endian.Big => {
            var index: usize = buf.len;
            while (index != 0) {
                index -= 1;

                buf[index] = @truncate(u8, bits);
                bits >>= 8;
            }
        },
        builtin.Endian.Little => {
            for (buf) |*b| {
                b.* = @truncate(u8, bits);
                bits >>= 8;
            }
        },
    }
    assert(bits == 0);
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

    return buf[0..buf_index];
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
        assert(readInt(bytes, u32, builtin.Endian.Big) == 0x12345678);
        assert(readIntBE(u32, bytes) == 0x12345678);
        assert(readIntBE(i32, bytes) == 0x12345678);
        assert(readInt(bytes, u32, builtin.Endian.Little) == 0x78563412);
        assert(readIntLE(u32, bytes) == 0x78563412);
        assert(readIntLE(i32, bytes) == 0x78563412);
    }
    {
        const buf = []u8{
            0x00,
            0x00,
            0x12,
            0x34,
        };
        const answer = readInt(buf, u64, builtin.Endian.Big);
        assert(answer == 0x00001234);
    }
    {
        const buf = []u8{
            0x12,
            0x34,
            0x00,
            0x00,
        };
        const answer = readInt(buf, u64, builtin.Endian.Little);
        assert(answer == 0x00003412);
    }
    {
        const bytes = []u8{
            0xff,
            0xfe,
        };
        assert(readIntBE(u16, bytes) == 0xfffe);
        assert(readIntBE(i16, bytes) == -0x0002);
        assert(readIntLE(u16, bytes) == 0xfeff);
        assert(readIntLE(i16, bytes) == -0x0101);
    }
}

test "testWriteInt" {
    testWriteIntImpl();
    comptime testWriteIntImpl();
}
fn testWriteIntImpl() void {
    var bytes: [4]u8 = undefined;

    writeInt(bytes[0..], u32(0x12345678), builtin.Endian.Big);
    assert(eql(u8, bytes, []u8{
        0x12,
        0x34,
        0x56,
        0x78,
    }));

    writeInt(bytes[0..], u32(0x78563412), builtin.Endian.Little);
    assert(eql(u8, bytes, []u8{
        0x12,
        0x34,
        0x56,
        0x78,
    }));

    writeInt(bytes[0..], u16(0x1234), builtin.Endian.Big);
    assert(eql(u8, bytes, []u8{
        0x00,
        0x00,
        0x12,
        0x34,
    }));

    writeInt(bytes[0..], u16(0x1234), builtin.Endian.Little);
    assert(eql(u8, bytes, []u8{
        0x34,
        0x12,
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

// TODO: When https://github.com/ziglang/zig/issues/649 is solved these can be done by
// endian-casting the pointer and then dereferencing

pub fn endianSwapIfLe(comptime T: type, x: T) T {
    return endianSwapIf(builtin.Endian.Little, T, x);
}

pub fn endianSwapIfBe(comptime T: type, x: T) T {
    return endianSwapIf(builtin.Endian.Big, T, x);
}

pub fn endianSwapIf(endian: builtin.Endian, comptime T: type, x: T) T {
    return if (builtin.endian == endian) endianSwap(T, x) else x;
}

pub fn endianSwap(comptime T: type, x: T) T {
    var buf: [@sizeOf(T)]u8 = undefined;
    mem.writeInt(buf[0..], x, builtin.Endian.Little);
    return mem.readInt(buf, T, builtin.Endian.Big);
}

test "std.mem.endianSwap" {
    assert(endianSwap(u32, 0xDEADBEEF) == 0xEFBEADDE);
}
