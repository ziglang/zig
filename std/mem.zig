const assert = @import("debug.zig").assert;

pub error NoMem;

pub type Context = u8;
pub struct Allocator {
    alloc: fn (self: &Allocator, n: isize) -> %[]u8,
    realloc: fn (self: &Allocator, old_mem: []u8, new_size: isize) -> %[]u8,
    free: fn (self: &Allocator, mem: []u8),
    context: ?&Context,
}

/// Copy all of source into dest at position 0.
/// dest.len must be >= source.len.
pub fn copy(T)(dest: []T, source: []T) {
    assert(dest.len >= source.len);
    @memcpy(dest.ptr, source.ptr, @sizeof(T) * source.len);
}
