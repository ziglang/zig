const assert = @import("debug.zig").assert;
const math = @import("math.zig");
const os = @import("os.zig");
const io = @import("io.zig");

pub error NoMem;

pub type Context = u8;
pub struct Allocator {
    alloc_fn: fn (self: &Allocator, n: isize) -> %[]u8,
    realloc_fn: fn (self: &Allocator, old_mem: []u8, new_size: isize) -> %[]u8,
    free_fn: fn (self: &Allocator, mem: []u8),
    context: ?&Context,

    /// Aborts the program if an allocation fails.
    fn checked_alloc(self: &Allocator, inline T: type, n: isize) -> []T {
        alloc(self, T, n) %% |err| {
            // TODO var args printf
            %%io.stderr.write("allocation failure: ");
            %%io.stderr.write(@err_name(err));
            %%io.stderr.printf("\n");
            os.abort()
        }
    }

    fn alloc(self: &Allocator, inline T: type, n: isize) -> %[]T {
        const byte_count = %return math.mul_overflow(isize, @sizeof(T), n);
        ([]T)(%return self.alloc_fn(self, byte_count))
    }

    fn realloc(self: &Allocator, inline T: type, old_mem: []T, n: isize) -> %[]T {
        const byte_count = %return math.mul_overflow(isize, @sizeof(T), n);
        ([]T)(%return self.realloc_fn(self, ([]u8)(old_mem), byte_count))
    }

    fn free(self: &Allocator, inline T: type, mem: []T) {
        self.free_fn(self, ([]u8)(mem));
    }
}

/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
pub fn copy(inline T: type, dest: []T, source: []T) {
    assert(dest.len >= source.len);
    @memcpy(dest.ptr, source.ptr, @sizeof(T) * source.len);
}
