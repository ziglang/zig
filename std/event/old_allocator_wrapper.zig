const std = @import("../index.zig");
const mem = std.mem;

const Error = mem.AllocatorError;

//This is necessary because of how async<allocator> is implemented.
// It will be unnecessary after #1260

pub const OldAllocator = struct {
    
    /// Allocate byte_count bytes and return them in a slice, with the
    /// slice's pointer aligned at least to alignment bytes.
    /// The returned newly allocated memory is undefined.
    /// `alignment` is guaranteed to be >= 1
    /// `alignment` is guaranteed to be a power of 2
    allocFn: fn (self: *OldAllocator, byte_count: usize, alignment: u29) Error![]u8,

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
    reallocFn: fn (self: *OldAllocator, old_mem: []u8, new_byte_count: usize, alignment: u29) Error![]u8,

    /// Guaranteed: `old_mem.len` is the same as what was returned from `allocFn` or `reallocFn`
    freeFn: fn (self: *OldAllocator, old_mem: []u8) void,

    /// Call `destroy` with the result
    /// TODO this is deprecated. use createOne instead
    pub fn create(self: *OldAllocator, init: var) Error!*@typeOf(init) {
        const T = @typeOf(init);
        if (@sizeOf(T) == 0) return &(T{});
        const slice = try self.alloc(T, 1);
        const ptr = &slice[0];
        ptr.* = init;
        return ptr;
    }

    /// Call `destroy` with the result.
    /// Returns undefined memory.
    pub fn createOne(self: *OldAllocator, comptime T: type) Error!*T {
        if (@sizeOf(T) == 0) return &(T{});
        const slice = try self.alloc(T, 1);
        return &slice[0];
    }

    /// `ptr` should be the return value of `create`
    pub fn destroy(self: *OldAllocator, ptr: var) void {
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(ptr));
        self.freeFn(self, non_const_ptr[0..@sizeOf(@typeOf(ptr).Child)]);
    }

    pub fn alloc(self: *OldAllocator, comptime T: type, n: usize) ![]T {
        return self.alignedAlloc(T, @alignOf(T), n);
    }

    pub fn alignedAlloc(self: *OldAllocator, comptime T: type, comptime alignment: u29, n: usize) ![]align(alignment) T {
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

    pub fn realloc(self: *OldAllocator, comptime T: type, old_mem: []T, n: usize) ![]T {
        return self.alignedRealloc(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
    }

    pub fn alignedRealloc(self: *OldAllocator, comptime T: type, comptime alignment: u29, old_mem: []align(alignment) T, n: usize) ![]align(alignment) T {
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
    pub fn shrink(self: *OldAllocator, comptime T: type, old_mem: []T, n: usize) []T {
        return self.alignedShrink(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
    }

    pub fn alignedShrink(self: *OldAllocator, comptime T: type, comptime alignment: u29, old_mem: []align(alignment) T, n: usize) []align(alignment) T {
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

    pub fn free(self: *OldAllocator, memory: var) void {
        const bytes = @sliceToBytes(memory);
        if (bytes.len == 0) return;
        const non_const_ptr = @intToPtr([*]u8, @ptrToInt(bytes.ptr));
        self.freeFn(self, non_const_ptr[0..bytes.len]);
    }
};

pub const OldAllocatorWrapper = struct {
    old_allocator: OldAllocator,
    real_allocator: mem.Allocator,
    
    pub fn init(real_allocator: mem.Allocator) OldAllocatorWrapper {
        return OldAllocatorWrapper {
            .real_allocator = real_allocator,
            .old_allocator = OldAllocator {
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free,
            },
        };
    }
    
    pub fn alloc(allocator: *OldAllocator, byte_count: usize, alignment: u29) Error![]u8 {
        const self = @fieldParentPtr(OldAllocatorWrapper, "old_allocator", allocator);
        return self.real_allocator.impl.alloc(byte_count, alignment);
    }
    
    pub fn realloc(allocator: *OldAllocator, old_mem: []u8, new_byte_count: usize, alignment: u29) Error![]u8 {
        const self = @fieldParentPtr(OldAllocatorWrapper, "old_allocator", allocator);
        return self.real_allocator.impl.realloc(old_mem, new_byte_count, alignment);
    }

    /// Guaranteed: `old_mem.len` is the same as what was returned from `allocFn` or `reallocFn`
    pub fn free(allocator: *OldAllocator, old_mem: []u8) void {
        const self = @fieldParentPtr(OldAllocatorWrapper, "old_allocator", allocator);
        self.real_allocator.impl.free(old_mem);
    }
};