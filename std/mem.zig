const assert = @import("debug.zig").assert;
const math = @import("math.zig");
const os = @import("os.zig");
const io = @import("io.zig");

pub const Cmp = math.Cmp;

pub error NoMem;

pub type Context = u8;
pub struct Allocator {
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
}

/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
pub fn copy(inline T: type, dest: []T, source: []const T) {
    assert(dest.len >= source.len);
    @memcpy(dest.ptr, source.ptr, @sizeOf(T) * source.len);
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
