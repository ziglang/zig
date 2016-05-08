pub error NoMem;

pub type Context = u8;
pub struct Allocator {
    alloc: fn (self: &Allocator, n: isize) -> %[]u8,
    realloc: fn (self: &Allocator, old_mem: []u8, new_size: isize) -> %[]u8,
    free: fn (self: &Allocator, mem: []u8),
    context: ?&Context,
}

