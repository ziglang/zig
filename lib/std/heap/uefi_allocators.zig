pub var global_page_allocator = PageAllocator{};
pub var global_pool_allocator = PoolAllocator{};

pub const PageAllocator = @import("uefi/PageAllocator.zig");
pub const PoolAllocator = @import("uefi/PoolAllocator.zig");
pub const RawPoolAllocator = @import("uefi/RawPoolAllocator.zig");
