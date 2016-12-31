const assert = @import("debug.zig").assert;
const math = @import("math.zig");
const os = @import("os.zig");
const io = @import("io.zig");

pub const Cmp = math.Cmp;

error NoMem;

pub type Context = u8;
pub const Allocator = struct {
    allocFn: fn (self: &Allocator, n: usize) -> %[]u8,
    reallocFn: fn (self: &Allocator, old_mem: []u8, new_size: usize) -> %[]u8,
    freeFn: fn (self: &Allocator, mem: []u8),
    context: ?&Context,

    /// Aborts the program if an allocation fails.
    fn checkedAlloc(self: &Allocator, inline T: type, n: usize) -> []T {
        alloc(self, T, n) %% |err| {
            // TODO var args printf
            %%io.stderr.write("allocation failure: ");
            %%io.stderr.write(@errorName(err));
            %%io.stderr.printf("\n");
            os.abort()
        }
    }

    fn alloc(self: &Allocator, inline T: type, n: usize) -> %[]T {
        const byte_count = %return math.mulOverflow(usize, @sizeOf(T), n);
        ([]T)(%return self.allocFn(self, byte_count))
    }

    fn realloc(self: &Allocator, inline T: type, old_mem: []T, n: usize) -> %[]T {
        const byte_count = %return math.mulOverflow(usize, @sizeOf(T), n);
        ([]T)(%return self.reallocFn(self, ([]u8)(old_mem), byte_count))
    }

    // TODO mem: []var and get rid of 2nd param
    fn free(self: &Allocator, inline T: type, mem: []T) {
        self.freeFn(self, ([]u8)(mem));
    }
};

/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
pub fn copy(inline T: type, dest: []T, source: []const T) {
    @setDebugSafety(this, false);
    assert(dest.len >= source.len);
    for (source) |s, i| dest[i] = s;
}

pub fn set(inline T: type, dest: []T, value: T) {
    for (dest) |*d| *d = value;
}

/// Return < 0, == 0, or > 0 if memory a is less than, equal to, or greater than,
/// memory b, respectively.
pub fn cmp(inline T: type, a: []const T, b: []const T) -> Cmp {
    const n = math.min(a.len, b.len);
    var i: usize = 0;
    while (i < n; i += 1) {
        if (a[i] == b[i]) continue;
        return if (a[i] > b[i]) Cmp.Greater else if (a[i] < b[i]) Cmp.Less else Cmp.Equal;
    }

    return if (a.len > b.len) Cmp.Greater else if (a.len < b.len) Cmp.Less else Cmp.Equal;
}

pub fn sliceAsInt(buf: []u8, is_be: bool, inline T: type) -> T {
    var result: T = undefined;
    const result_slice = ([]u8)((&result)[0...1]);
    const padding = @sizeOf(T) - buf.len;

    if (is_be == @compileVar("is_big_endian")) {
        copy(u8, result_slice, buf);
    } else {
        for (buf) |b, i| {
            const index = result_slice.len - i - 1 - padding;
            result_slice[index] = b;
        }
    }
    return result;
}

fn testSliceAsInt() {
    @setFnTest(this, true);
    {
        const buf = []u8{0x00, 0x00, 0x12, 0x34};
        const answer = sliceAsInt(buf[0...], true, u64);
        assert(answer == 0x00001234);
    }
    {
        const buf = []u8{0x12, 0x34, 0x00, 0x00};
        const answer = sliceAsInt(buf[0...], false, u64);
        assert(answer == 0x00003412);
    }
}
