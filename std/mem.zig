const debug = @import("debug.zig");
const assert = debug.assert;
const math = @import("math.zig");
const os = @import("os/index.zig");
const io = @import("io.zig");
const builtin = @import("builtin");
const Os = builtin.Os;

pub const Cmp = math.Cmp;

error NoMem;

pub const Allocator = struct {
    allocFn: fn (self: &Allocator, n: usize) -> %[]u8,
    /// Note that old_mem may be a slice of length 0, in which case reallocFn
    /// should simply call allocFn.
    reallocFn: fn (self: &Allocator, old_mem: []u8, new_size: usize) -> %[]u8,
    /// Note that mem may be a slice of length 0, in which case freeFn
    /// should do nothing.
    freeFn: fn (self: &Allocator, mem: []u8),

    /// Aborts the program if an allocation fails.
    fn checkedAlloc(self: &Allocator, comptime T: type, n: usize) -> []T {
        alloc(self, T, n) %% |err| {
            %%io.stderr.printf("allocation failure: {}\n", @errorName(err));
            os.abort()
        }
    }

    fn create(self: &Allocator, comptime T: type) -> %&T {
        &(%return self.alloc(T, 1))[0]
    }

    fn destroy(self: &Allocator, ptr: var) {
        self.free(ptr[0..1]);
    }

    fn alloc(self: &Allocator, comptime T: type, n: usize) -> %[]T {
        const byte_count = %return math.mul(usize, @sizeOf(T), n);
        ([]T)(%return self.allocFn(self, byte_count))
    }

    fn realloc(self: &Allocator, comptime T: type, old_mem: []T, n: usize) -> %[]T {
        const byte_count = %return math.mul(usize, @sizeOf(T), n);
        ([]T)(%return self.reallocFn(self, ([]u8)(old_mem), byte_count))
    }

    fn free(self: &Allocator, mem: var) {
        self.freeFn(self, ([]u8)(mem));
    }
};

pub const IncrementingAllocator = struct {
    allocator: Allocator,
    bytes: []u8,
    end_index: usize,

    fn init(capacity: usize) -> %IncrementingAllocator {
        switch (builtin.os) {
            Os.linux, Os.darwin, Os.macosx, Os.ios => {
                const p = os.posix;
                const addr = p.mmap(null, capacity, p.PROT_READ|p.PROT_WRITE,
                    p.MAP_PRIVATE|p.MAP_ANONYMOUS|p.MAP_NORESERVE, -1, 0);
                if (addr == p.MAP_FAILED) {
                    return error.NoMem;
                }
                return IncrementingAllocator {
                    .allocator = Allocator {
                        .allocFn = alloc,
                        .reallocFn = realloc,
                        .freeFn = free,
                    },
                    .bytes = @intToPtr(&u8, addr)[0..capacity],
                    .end_index = 0,
                };
            },
            else => @compileError("Unsupported OS"),
        }
    }

    fn deinit(self: &IncrementingAllocator) {
        _ = os.posix.munmap(self.bytes.ptr, self.bytes.len);
    }

    fn alloc(allocator: &Allocator, n: usize) -> %[]u8 {
        const self = @fieldParentPtr(IncrementingAllocator, "allocator", allocator);
        const new_end_index = self.end_index + n;
        if (new_end_index > self.bytes.len) {
            return error.NoMem;
        }
        const result = self.bytes[self.end_index..new_end_index];
        self.end_index = new_end_index;
        return result;
    }

    fn realloc(allocator: &Allocator, old_mem: []u8, new_size: usize) -> %[]u8 {
        const result = %return alloc(allocator, new_size);
        copy(u8, result, old_mem);
        return result;
    }

    fn free(allocator: &Allocator, bytes: []u8) {
        // Do nothing. That's the point of an incrementing allocator.
    }
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

/// Return < 0, == 0, or > 0 if memory a is less than, equal to, or greater than,
/// memory b, respectively.
pub fn cmp(comptime T: type, a: []const T, b: []const T) -> Cmp {
    const n = math.min(a.len, b.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (a[i] == b[i]) continue;
        return if (a[i] > b[i]) Cmp.Greater else if (a[i] < b[i]) Cmp.Less else Cmp.Equal;
    }

    return if (a.len > b.len) Cmp.Greater else if (a.len < b.len) Cmp.Less else Cmp.Equal;
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
    for (slice) |item, i| {
        if (item == value) {
            return i;
        }
    }
    return null;
}

// TODO boyer-moore algorithm
pub fn indexOf(comptime T: type, haystack: []const T, needle: []const T) -> ?usize {
    if (needle.len > haystack.len)
        return null;

    var i: usize = 0;
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
pub fn readInt(bytes: []const u8, comptime T: type, big_endian: bool) -> T {
    var result: T = 0;
    if (big_endian) {
        for (bytes) |b| {
            result = (result << 8) | b;
        }
    } else {
        for (bytes) |b, index| {
            result = result | (T(b) << T(index * 8));
        }
    }
    return result;
}

/// Writes an integer to memory with size equal to bytes.len. Pads with zeroes
/// to fill the entire buffer provided.
/// value must be an integer.
pub fn writeInt(buf: []u8, value: var, big_endian: bool) {
    const uint = @IntType(false, @typeOf(value).bit_count);
    var bits = @truncate(uint, value);
    if (big_endian) {
        var index: usize = buf.len;
        while (index != 0) {
            index -= 1;

            buf[index] = @truncate(u8, bits);
            bits >>= 8;
        }
    } else {
        for (buf) |*b| {
            *b = @truncate(u8, bits);
            bits >>= 8;
        }
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

/// Returns an iterator that iterates over the slices of ::s that are not
/// the byte ::c.
/// split("   abc def    ghi  ")
/// Will return slices for "abc", "def", "ghi", null, in that order.
pub fn split(s: []const u8, c: u8) -> SplitIterator {
    SplitIterator {
        .index = 0,
        .s = s,
        .c = c,
    }
}

test "mem.split" {
    var it = split("   abc def   ghi  ", ' ');
    assert(eql(u8, ??it.next(), "abc"));
    assert(eql(u8, ??it.next(), "def"));
    assert(eql(u8, ??it.next(), "ghi"));
    assert(it.next() == null);
}

pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) -> bool {
    return if (needle.len > haystack.len) false else eql(T, haystack[0 .. needle.len], needle);
}

const SplitIterator = struct {
    s: []const u8,
    c: u8,
    index: usize,

    pub fn next(self: &SplitIterator) -> ?[]const u8 {
        // move to beginning of token
        while (self.index < self.s.len and self.s[self.index] == self.c) : (self.index += 1) {}
        const start = self.index;
        if (start == self.s.len) {
            return null;
        }

        // move to end of token
        while (self.index < self.s.len and self.s[self.index] != self.c) : (self.index += 1) {}
        const end = self.index;

        return self.s[start..end];
    }

    /// Returns a slice of the remaining bytes. Does not affect iterator state.
    pub fn rest(self: &const SplitIterator) -> []const u8 {
        // move to beginning of token
        var index: usize = self.index;
        while (index < self.s.len and self.s[index] == self.c) : (index += 1) {}
        return self.s[index..];
    }
};

/// Naively combines a series of strings with a separator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: &Allocator, sep: u8, strings: ...) -> %[]u8 {
    comptime assert(strings.len >= 1);
    var total_strings_len: usize = strings.len; // 1 slash per string
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
    assert(eql(u8, %%join(&debug.global_allocator, ',', "a", "b", "c"), "a,b,c"));
    assert(eql(u8, %%join(&debug.global_allocator, ',', "a"), "a"));
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
        assert(readInt(bytes, u32, true) == 0x12345678);
        assert(readInt(bytes, u32, false) == 0x78563412);
    }
    {
        const buf = []u8{0x00, 0x00, 0x12, 0x34};
        const answer = readInt(buf, u64, true);
        assert(answer == 0x00001234);
    }
    {
        const buf = []u8{0x12, 0x34, 0x00, 0x00};
        const answer = readInt(buf, u64, false);
        assert(answer == 0x00003412);
    }
}

test "testWriteInt" {
    testWriteIntImpl();
    comptime testWriteIntImpl();
}
fn testWriteIntImpl() {
    var bytes: [4]u8 = undefined;

    writeInt(bytes[0..], u32(0x12345678), true);
    assert(eql(u8, bytes, []u8{ 0x12, 0x34, 0x56, 0x78 }));

    writeInt(bytes[0..], u32(0x78563412), false);
    assert(eql(u8, bytes, []u8{ 0x12, 0x34, 0x56, 0x78 }));

    writeInt(bytes[0..], u16(0x1234), true);
    assert(eql(u8, bytes, []u8{ 0x00, 0x00, 0x12, 0x34 }));

    writeInt(bytes[0..], u16(0x1234), false);
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
