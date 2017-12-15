const debug = @import("debug.zig");
const assert = debug.assert;
const math = @import("math/index.zig");
const builtin = @import("builtin");

pub const Allocator = struct {
    /// Allocate byte_count bytes and return them in a slice, with the
    /// slice's pointer aligned at least to alignment bytes.
    /// The returned newly allocated memory is undefined.
    allocFn: fn (self: &Allocator, byte_count: usize, alignment: u29) -> %[]u8,

    /// If `new_byte_count > old_mem.len`:
    /// * `old_mem.len` is the same as what was returned from allocFn or reallocFn.
    /// * alignment >= alignment of old_mem.ptr
    ///
    /// If `new_byte_count <= old_mem.len`:
    /// * this function must return successfully. 
    /// * alignment <= alignment of old_mem.ptr
    ///
    /// The returned newly allocated memory is undefined.
    reallocFn: fn (self: &Allocator, old_mem: []u8, new_byte_count: usize, alignment: u29) -> %[]u8,

    /// Guaranteed: `old_mem.len` is the same as what was returned from `allocFn` or `reallocFn`
    freeFn: fn (self: &Allocator, old_mem: []u8),

    fn create(self: &Allocator, comptime T: type) -> %&T {
        const slice = %return self.alloc(T, 1);
        return &slice[0];
    }

    fn destroy(self: &Allocator, ptr: var) {
        self.free(ptr[0..1]);
    }

    fn alloc(self: &Allocator, comptime T: type, n: usize) -> %[]T {
        return self.alignedAlloc(T, @alignOf(T), n);
    }

    fn alignedAlloc(self: &Allocator, comptime T: type, comptime alignment: u29,
        n: usize) -> %[]align(alignment) T
    {
        const byte_count = %return math.mul(usize, @sizeOf(T), n);
        const byte_slice = %return self.allocFn(self, byte_count, alignment);
        // This loop should get optimized out in ReleaseFast mode
        for (byte_slice) |*byte| {
            *byte = undefined;
        }
        return ([]align(alignment) T)(@alignCast(alignment, byte_slice));
    }

    fn realloc(self: &Allocator, comptime T: type, old_mem: []T, n: usize) -> %[]T {
        return self.alignedRealloc(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
    }

    fn alignedRealloc(self: &Allocator, comptime T: type, comptime alignment: u29,
        old_mem: []align(alignment) T, n: usize) -> %[]align(alignment) T
    {
        if (old_mem.len == 0) {
            return self.alloc(T, n);
        }

        const old_byte_slice = ([]u8)(old_mem);
        const byte_count = %return math.mul(usize, @sizeOf(T), n);
        const byte_slice = %return self.reallocFn(self, old_byte_slice, byte_count, alignment);
        // This loop should get optimized out in ReleaseFast mode
        for (byte_slice[old_byte_slice.len..]) |*byte| {
            *byte = undefined;
        }
        return ([]T)(@alignCast(alignment, byte_slice));
    }

    /// Reallocate, but `n` must be less than or equal to `old_mem.len`.
    /// Unlike `realloc`, this function cannot fail.
    /// Shrinking to 0 is the same as calling `free`.
    fn shrink(self: &Allocator, comptime T: type, old_mem: []T, n: usize) -> []T {
        return self.alignedShrink(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
    }

    fn alignedShrink(self: &Allocator, comptime T: type, comptime alignment: u29,
        old_mem: []align(alignment) T, n: usize) -> []align(alignment) T
    {
        if (n == 0) {
            self.free(old_mem);
            return old_mem[0..0];
        }

        assert(n <= old_mem.len);

        // Here we skip the overflow checking on the multiplication because
        // n <= old_mem.len and the multiplication didn't overflow for that operation.
        const byte_count = @sizeOf(T) * n;

        const byte_slice = %%self.reallocFn(self, ([]u8)(old_mem), byte_count, alignment);
        return ([]align(alignment) T)(@alignCast(alignment, byte_slice));
    }

    fn free(self: &Allocator, memory: var) {
        const bytes = ([]const u8)(memory);
        if (bytes.len == 0)
            return;
        const non_const_ptr = @intToPtr(&u8, @ptrToInt(bytes.ptr));
        self.freeFn(self, non_const_ptr[0..bytes.len]);
    }
};

pub const FixedBufferAllocator = struct {
    allocator: Allocator,
    end_index: usize,
    buffer: []u8,

    pub fn init(buffer: []u8) -> FixedBufferAllocator {
        return FixedBufferAllocator {
            .allocator = Allocator {
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free,
            },
            .buffer = buffer,
            .end_index = 0,
        };
    }

    fn alloc(allocator: &Allocator, n: usize, alignment: u29) -> %[]u8 {
        const self = @fieldParentPtr(FixedBufferAllocator, "allocator", allocator);
        const addr = @ptrToInt(&self.buffer[self.end_index]);
        const rem = @rem(addr, alignment);
        const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
        const adjusted_index = self.end_index + march_forward_bytes;
        const new_end_index = adjusted_index + n;
        if (new_end_index > self.buffer.len) {
            return error.OutOfMemory;
        }
        const result = self.buffer[adjusted_index .. new_end_index];
        self.end_index = new_end_index;
        return result;
    }

    fn realloc(allocator: &Allocator, old_mem: []u8, new_size: usize, alignment: u29) -> %[]u8 {
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            const result = %return alloc(allocator, new_size, alignment);
            copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(allocator: &Allocator, bytes: []u8) { }
};


/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
pub fn copy(comptime T: type, dest: []T, source: []const T) {
    // TODO instead of manually doing this check for the whole array
    // and turning off debug safety, the compiler should detect loops like
    // this and automatically omit safety checks for loops
    @setDebugSafety(this, false);
    assert(dest.len >= source.len);
    for (source) |s, i| dest[i] = s;
}

pub fn set(comptime T: type, dest: []T, value: T) {
    for (dest) |*d| *d = value;
}

/// Returns true if lhs < rhs, false otherwise
pub fn lessThan(comptime T: type, lhs: []const T, rhs: []const T) -> bool {
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
pub fn eql(comptime T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

/// Copies ::m to newly allocated memory. Caller is responsible to free it.
pub fn dupe(allocator: &Allocator, comptime T: type, m: []const T) -> %[]T {
    const new_buf = %return allocator.alloc(T, m.len);
    copy(T, new_buf, m);
    return new_buf;
}

/// Linear search for the index of a scalar value inside a slice.
pub fn indexOfScalar(comptime T: type, slice: []const T, value: T) -> ?usize {
    return indexOfScalarPos(T, slice, 0, value);
}

pub fn indexOfScalarPos(comptime T: type, slice: []const T, start_index: usize, value: T) -> ?usize {
    var i: usize = start_index;
    while (i < slice.len) : (i += 1) {
        if (slice[i] == value)
            return i;
    }
    return null;
}

pub fn indexOfAny(comptime T: type, slice: []const T, values: []const T) -> ?usize {
    return indexOfAnyPos(T, slice, 0, values);
}

pub fn indexOfAnyPos(comptime T: type, slice: []const T, start_index: usize, values: []const T) -> ?usize {
    var i: usize = start_index;
    while (i < slice.len) : (i += 1) {
        for (values) |value| {
            if (slice[i] == value)
                return i;
        }
    }
    return null;
}

pub fn indexOf(comptime T: type, haystack: []const T, needle: []const T) -> ?usize {
    return indexOfPos(T, haystack, 0, needle);
}

// TODO boyer-moore algorithm
pub fn indexOfPos(comptime T: type, haystack: []const T, start_index: usize, needle: []const T) -> ?usize {
    if (needle.len > haystack.len)
        return null;

    var i: usize = start_index;
    const end = haystack.len - needle.len;
    while (i <= end) : (i += 1) {
        if (eql(T, haystack[i .. i + needle.len], needle))
            return i;
    }
    return null;
}

test "mem.indexOf" {
    assert(??indexOf(u8, "one two three four", "four") == 14);
    assert(indexOf(u8, "one two three four", "gour") == null);
    assert(??indexOf(u8, "foo", "foo") == 0);
    assert(indexOf(u8, "foo", "fool") == null);
}

/// Reads an integer from memory with size equal to bytes.len.
/// T specifies the return type, which must be large enough to store
/// the result.
/// See also ::readIntBE or ::readIntLE.
pub fn readInt(bytes: []const u8, comptime T: type, endian: builtin.Endian) -> T {
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
                result = result | (T(b) << ShiftType(index * 8));
            }
        },
    }
    return result;
}

/// Reads a big-endian int of type T from bytes.
/// bytes.len must be exactly @sizeOf(T).
pub fn readIntBE(comptime T: type, bytes: []const u8) -> T {
    if (T.is_signed) {
        return @bitCast(T, readIntBE(@IntType(false, T.bit_count), bytes));
    }
    assert(bytes.len == @sizeOf(T));
    var result: T = 0;
    {comptime var i = 0; inline while (i < @sizeOf(T)) : (i += 1) {
        result = (result << 8) | T(bytes[i]);
    }}
    return result;
}

/// Reads a little-endian int of type T from bytes.
/// bytes.len must be exactly @sizeOf(T).
pub fn readIntLE(comptime T: type, bytes: []const u8) -> T {
    if (T.is_signed) {
        return @bitCast(T, readIntLE(@IntType(false, T.bit_count), bytes));
    }
    assert(bytes.len == @sizeOf(T));
    var result: T = 0;
    {comptime var i = 0; inline while (i < @sizeOf(T)) : (i += 1) {
        result |= T(bytes[i]) << i * 8;
    }}
    return result;
}

/// Writes an integer to memory with size equal to bytes.len. Pads with zeroes
/// to fill the entire buffer provided.
/// value must be an integer.
pub fn writeInt(buf: []u8, value: var, endian: builtin.Endian) {
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
                *b = @truncate(u8, bits);
                bits >>= 8;
            }
        },
    }
    assert(bits == 0);
}


pub fn hash_slice_u8(k: []const u8) -> u32 {
    // FNV 32-bit hash
    var h: u32 = 2166136261;
    for (k) |b| {
        h = (h ^ b) *% 16777619;
    }
    return h;
}

pub fn eql_slice_u8(a: []const u8, b: []const u8) -> bool {
    return eql(u8, a, b);
}

/// Returns an iterator that iterates over the slices of `buffer` that are not
/// any of the bytes in `split_bytes`.
/// split("   abc def    ghi  ", " ")
/// Will return slices for "abc", "def", "ghi", null, in that order.
pub fn split(buffer: []const u8, split_bytes: []const u8) -> SplitIterator {
    SplitIterator {
        .index = 0,
        .buffer = buffer,
        .split_bytes = split_bytes,
    }
}

test "mem.split" {
    var it = split("   abc def   ghi  ", " ");
    assert(eql(u8, ??it.next(), "abc"));
    assert(eql(u8, ??it.next(), "def"));
    assert(eql(u8, ??it.next(), "ghi"));
    assert(it.next() == null);
}

pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) -> bool {
    return if (needle.len > haystack.len) false else eql(T, haystack[0 .. needle.len], needle);
}

const SplitIterator = struct {
    buffer: []const u8,
    split_bytes: []const u8, 
    index: usize,

    pub fn next(self: &SplitIterator) -> ?[]const u8 {
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
    pub fn rest(self: &const SplitIterator) -> []const u8 {
        // move to beginning of token
        var index: usize = self.index;
        while (index < self.buffer.len and self.isSplitByte(self.buffer[index])) : (index += 1) {}
        return self.buffer[index..];
    }

    fn isSplitByte(self: &const SplitIterator, byte: u8) -> bool {
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
pub fn join(allocator: &Allocator, sep: u8, strings: ...) -> %[]u8 {
    comptime assert(strings.len >= 1);
    var total_strings_len: usize = strings.len; // 1 sep per string
    {
        comptime var string_i = 0;
        inline while (string_i < strings.len) : (string_i += 1) {
            const arg = ([]const u8)(strings[string_i]);
            total_strings_len += arg.len;
        }
    }

    const buf = %return allocator.alloc(u8, total_strings_len);
    %defer allocator.free(buf);

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
    assert(eql(u8, %%join(debug.global_allocator, ',', "a", "b", "c"), "a,b,c"));
    assert(eql(u8, %%join(debug.global_allocator, ',', "a"), "a"));
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
fn testReadIntImpl() {
    {
        const bytes = []u8{ 0x12, 0x34, 0x56, 0x78 };
        assert(readInt(bytes, u32, builtin.Endian.Big)  == 0x12345678);
        assert(readIntBE(u32, bytes)      == 0x12345678);
        assert(readIntBE(i32, bytes)      == 0x12345678);
        assert(readInt(bytes, u32, builtin.Endian.Little) == 0x78563412);
        assert(readIntLE(u32, bytes)      == 0x78563412);
        assert(readIntLE(i32, bytes)      == 0x78563412);
    }
    {
        const buf = []u8{0x00, 0x00, 0x12, 0x34};
        const answer = readInt(buf, u64, builtin.Endian.Big);
        assert(answer == 0x00001234);
    }
    {
        const buf = []u8{0x12, 0x34, 0x00, 0x00};
        const answer = readInt(buf, u64, builtin.Endian.Little);
        assert(answer == 0x00003412);
    }
    {
        const bytes = []u8{0xff, 0xfe};
        assert(readIntBE(u16, bytes) ==  0xfffe);
        assert(readIntBE(i16, bytes) == -0x0002);
        assert(readIntLE(u16, bytes) ==  0xfeff);
        assert(readIntLE(i16, bytes) == -0x0101);
    }
}

test "testWriteInt" {
    testWriteIntImpl();
    comptime testWriteIntImpl();
}
fn testWriteIntImpl() {
    var bytes: [4]u8 = undefined;

    writeInt(bytes[0..], u32(0x12345678), builtin.Endian.Big);
    assert(eql(u8, bytes, []u8{ 0x12, 0x34, 0x56, 0x78 }));

    writeInt(bytes[0..], u32(0x78563412), builtin.Endian.Little);
    assert(eql(u8, bytes, []u8{ 0x12, 0x34, 0x56, 0x78 }));

    writeInt(bytes[0..], u16(0x1234), builtin.Endian.Big);
    assert(eql(u8, bytes, []u8{ 0x00, 0x00, 0x12, 0x34 }));

    writeInt(bytes[0..], u16(0x1234), builtin.Endian.Little);
    assert(eql(u8, bytes, []u8{ 0x34, 0x12, 0x00, 0x00 }));
}


pub fn min(comptime T: type, slice: []const T) -> T {
    var best = slice[0];
    var i: usize = 1;
    while (i < slice.len) : (i += 1) {
        best = math.min(best, slice[i]);
    }
    return best;
}

test "mem.min" {
    assert(min(u8, "abcdefg") == 'a');
}

pub fn max(comptime T: type, slice: []const T) -> T {
    var best = slice[0];
    var i: usize = 1;
    while (i < slice.len) : (i += 1) {
        best = math.max(best, slice[i]);
    }
    return best;
}

test "mem.max" {
    assert(max(u8, "abcdefg") == 'g');
}

pub fn swap(comptime T: type, a: &T, b: &T) {
    const tmp = *a;
    *a = *b;
    *b = tmp;
}

/// In-place order reversal of a slice
pub fn reverse(comptime T: type, items: []T) {
    var i: usize = 0;
    const end = items.len / 2;
    while (i < end) : (i += 1) {
        swap(T, &items[i], &items[items.len - i - 1]);
    }
}

test "std.mem.reverse" {
    var arr = []i32{ 5, 3, 1, 2, 4 };
    reverse(i32, arr[0..]);

    assert(eql(i32, arr, []i32{ 4, 2, 1, 3, 5 }))
}

/// In-place rotation of the values in an array ([0 1 2 3] becomes [1 2 3 0] if we rotate by 1)
/// Assumes 0 <= amount <= items.len
pub fn rotate(comptime T: type, items: []T, amount: usize) {
    reverse(T, items[0..amount]);
    reverse(T, items[amount..]);
    reverse(T, items);
}

test "std.mem.rotate" {
    var arr = []i32{ 5, 3, 1, 2, 4 };
    rotate(i32, arr[0..], 2);

    assert(eql(i32, arr, []i32{ 1, 2, 4, 5, 3 }))
}
