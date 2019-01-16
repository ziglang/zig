const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const os = std.os;
const builtin = @import("builtin");
const Os = builtin.Os;
const c = std.c;
const maxInt = std.math.maxInt;

const Allocator = mem.Allocator;
const AllocatorInterface = mem.AllocatorInterface;
const AbstractAllocator = mem.AbstractAllocator;

pub const CAllocator = struct
{
    //We can't wrap a 0-size type with AbstractAllocator because it requires
    // a pointer type
    
    _: u8,
    
    const Error = mem.AllocatorError;
    
    pub fn alloc(self: CAllocator, n: usize, alignment: u29) Error![]u8 {
        assert(alignment <= @alignOf(c_longdouble));
        return if (c.malloc(n)) |buf| @ptrCast([*]u8, buf)[0..n] else error.OutOfMemory;
    }
    
    pub fn realloc(self: CAllocator, old_mem: []u8, new_size: usize, alignment: u29) Error![]u8 {
        const old_ptr = @ptrCast(*c_void, old_mem.ptr);
        if (c.realloc(old_ptr, new_size)) |buf| {
            return @ptrCast([*]u8, buf)[0..new_size];
        } else if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            return error.OutOfMemory;
        }
    }
    
    pub fn free(self: CAllocator, old_mem: []u8) void {
        const old_ptr = @ptrCast(*c_void, old_mem.ptr);
        c.free(old_ptr);
    }
    
    pub fn allocatorInterface(self: CAllocator) AllocatorInterface(*CAllocator) {
        return AllocatorInterface(CAllocator).init(self);
    }
    
    pub fn allocator(self:*CAllocator) Allocator {
        return Allocator.init(AbstractAllocator.init(@alignCast(1, self)));
    }
};

pub const c_allocator = (CAllocator{._ = 0, }).allocator();



/// This allocator makes a syscall directly for every allocation and free.
/// Thread-safe and lock-free.
pub const DirectAllocator = struct {
    heap_handle: ?HeapHandle,

    const HeapHandle = if (builtin.os == Os.windows) os.windows.HANDLE else void;
    const Error = mem.AllocatorError;
    
    pub fn init() DirectAllocator {
        return DirectAllocator{
            .heap_handle = if (builtin.os == Os.windows) null else {},
        };
    }

    pub fn deinit(self: *DirectAllocator) void {
        switch (builtin.os) {
            Os.windows => if (self.heap_handle) |heap_handle| {
                _ = os.windows.HeapDestroy(heap_handle);
            },
            else => {},
        }
    }

    fn alloc(self: *DirectAllocator, n: usize, alignment: u29) Error![]u8 {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.freebsd => {
                const p = os.posix;
                const alloc_size = if (alignment <= os.page_size) n else n + alignment;
                const addr = p.mmap(null, alloc_size, p.PROT_READ | p.PROT_WRITE, p.MAP_PRIVATE | p.MAP_ANONYMOUS, -1, 0);
                if (addr == p.MAP_FAILED) return error.OutOfMemory;
                if (alloc_size == n) return @intToPtr([*]u8, addr)[0..n];

                const aligned_addr = (addr & ~usize(alignment - 1)) + alignment;

                // We can unmap the unused portions of our mmap, but we must only
                // pass munmap bytes that exist outside our allocated pages or it
                // will happily eat us too.

                // Since alignment > page_size, we are by definition on a page boundary.
                const unused_start = addr;
                const unused_len = aligned_addr - 1 - unused_start;

                const err = p.munmap(unused_start, unused_len);
                assert(p.getErrno(err) == 0);

                // It is impossible that there is an unoccupied page at the top of our
                // mmap.

                return @intToPtr([*]u8, aligned_addr)[0..n];
            },
            Os.windows => {
                const amt = n + alignment + @sizeOf(usize);
                const optional_heap_handle = @atomicLoad(?HeapHandle, &self.heap_handle, builtin.AtomicOrder.SeqCst);
                const heap_handle = optional_heap_handle orelse blk: {
                    const hh = os.windows.HeapCreate(0, amt, 0) orelse return error.OutOfMemory;
                    const other_hh = @cmpxchgStrong(?HeapHandle, &self.heap_handle, null, hh, builtin.AtomicOrder.SeqCst, builtin.AtomicOrder.SeqCst) orelse break :blk hh;
                    _ = os.windows.HeapDestroy(hh);
                    break :blk other_hh.?; // can't be null because of the cmpxchg
                };
                const ptr = os.windows.HeapAlloc(heap_handle, 0, amt) orelse return error.OutOfMemory;
                const root_addr = @ptrToInt(ptr);
                const rem = @rem(root_addr, alignment);
                const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
                const adjusted_addr = root_addr + march_forward_bytes;
                const record_addr = adjusted_addr + n;
                @intToPtr(*align(1) usize, record_addr).* = root_addr;
                return @intToPtr([*]u8, adjusted_addr)[0..n];
            },
            else => @compileError("Unsupported OS"),
        }
    }

    fn realloc(self: *DirectAllocator, old_mem: []u8, new_size: usize, alignment: u29) Error![]u8 {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.freebsd => {
                if (new_size <= old_mem.len) {
                    const base_addr = @ptrToInt(old_mem.ptr);
                    const old_addr_end = base_addr + old_mem.len;
                    const new_addr_end = base_addr + new_size;
                    const rem = @rem(new_addr_end, os.page_size);
                    const new_addr_end_rounded = new_addr_end + if (rem == 0) 0 else (os.page_size - rem);
                    if (old_addr_end > new_addr_end_rounded) {
                        _ = os.posix.munmap(new_addr_end_rounded, old_addr_end - new_addr_end_rounded);
                    }
                    return old_mem[0..new_size];
                }

                const result = try self.alloc(new_size, alignment);
                mem.copy(u8, result, old_mem);
                return result;
            },
            Os.windows => {
                const old_adjusted_addr = @ptrToInt(old_mem.ptr);
                const old_record_addr = old_adjusted_addr + old_mem.len;
                const root_addr = @intToPtr(*align(1) usize, old_record_addr).*;
                const old_ptr = @intToPtr(*c_void, root_addr);
                const amt = new_size + alignment + @sizeOf(usize);
                const new_ptr = os.windows.HeapReAlloc(self.heap_handle.?, 0, old_ptr, amt) orelse blk: {
                    if (new_size > old_mem.len) return error.OutOfMemory;
                    const new_record_addr = old_record_addr - new_size + old_mem.len;
                    @intToPtr(*align(1) usize, new_record_addr).* = root_addr;
                    return old_mem[0..new_size];
                };
                const offset = old_adjusted_addr - root_addr;
                const new_root_addr = @ptrToInt(new_ptr);
                const new_adjusted_addr = new_root_addr + offset;
                assert(new_adjusted_addr % alignment == 0);
                const new_record_addr = new_adjusted_addr + new_size;
                @intToPtr(*align(1) usize, new_record_addr).* = new_root_addr;
                return @intToPtr([*]u8, new_adjusted_addr)[0..new_size];
            },
            else => @compileError("Unsupported OS"),
        }
    }

    fn free(self: *DirectAllocator, bytes: []u8) void {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.freebsd => {
                _ = os.posix.munmap(@ptrToInt(bytes.ptr), bytes.len);
            },
            Os.windows => {
                const record_addr = @ptrToInt(bytes.ptr) + bytes.len;
                const root_addr = @intToPtr(*align(1) usize, record_addr).*;
                const ptr = @intToPtr(*c_void, root_addr);
                _ = os.windows.HeapFree(self.heap_handle.?, 0, ptr);
            },
            else => @compileError("Unsupported OS"),
        }
    }
    
    pub fn allocatorInterface(self: *DirectAllocator) AllocatorInterface(*DirectAllocator) {
        return AllocatorInterface(*DirectAllocator).init(self);
    }
    
    pub fn allocator(self: *DirectAllocator) Allocator {
        return Allocator.init(AbstractAllocator.init(self));
    }
};

/// This allocator takes an existing allocator, wraps it, and provides an allocator
/// where you can allocate without freeing, and then free it all together.
pub const ArenaAllocator = struct {
    child_allocator: Allocator,
    buffer_list: std.LinkedList([]u8),
    end_index: usize,

    const BufNode = std.LinkedList([]u8).Node;
    const Error = mem.AllocatorError;
    
    pub fn init(child_allocator: Allocator) ArenaAllocator {
        return ArenaAllocator{
            .child_allocator = child_allocator,
            .buffer_list = std.LinkedList([]u8).init(),
            .end_index = 0,
        };
    }

    pub fn deinit(self: *ArenaAllocator) void {
        var it = self.buffer_list.first;
        while (it) |node| {
            // this has to occur before the free because the free frees node
            it = node.next;

            self.child_allocator.free(node.data);
        }
    }

    fn createNode(self: *ArenaAllocator, prev_len: usize, minimum_size: usize) !*BufNode {
        const actual_min_size = minimum_size + @sizeOf(BufNode);
        var len = prev_len;
        while (true) {
            len += len / 2;
            len += os.page_size - @rem(len, os.page_size);
            if (len >= actual_min_size) break;
        }
        const buf = try self.child_allocator.alignedAlloc(u8, @alignOf(BufNode), len);
        const buf_node_slice = @bytesToSlice(BufNode, buf[0..@sizeOf(BufNode)]);
        const buf_node = &buf_node_slice[0];
        buf_node.* = BufNode{
            .data = buf,
            .prev = null,
            .next = null,
        };
        self.buffer_list.append(buf_node);
        self.end_index = 0;
        return buf_node;
    }

    fn alloc(self: *ArenaAllocator, n: usize, alignment: u29) Error![]u8 {
        var cur_node = if (self.buffer_list.last) |last_node| last_node else try self.createNode(0, n + alignment);
        while (true) {
            const cur_buf = cur_node.data[@sizeOf(BufNode)..];
            const addr = @ptrToInt(cur_buf.ptr) + self.end_index;
            const rem = @rem(addr, alignment);
            const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
            const adjusted_index = self.end_index + march_forward_bytes;
            const new_end_index = adjusted_index + n;
            if (new_end_index > cur_buf.len) {
                cur_node = try self.createNode(cur_buf.len, n + alignment);
                continue;
            }
            const result = cur_buf[adjusted_index..new_end_index];
            self.end_index = new_end_index;
            return result;
        }
    }

    fn realloc(self: *ArenaAllocator, old_mem: []u8, new_size: usize, alignment: u29) Error![]u8 {
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            const result = try self.alloc(new_size, alignment);
            mem.copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(self: *ArenaAllocator, bytes: []u8) void {}
    
    pub fn allocatorInterface(self: *ArenaAllocator) AllocatorInterface(*ArenaAllocator) {
        return AllocatorInterface(*ArenaAllocator).init(self);
    }
    
    pub fn allocator(self: *ArenaAllocator) Allocator {
        return Allocator.init(AbstractAllocator.init(self));
    }
};

pub const FixedBufferAllocator = struct {
    end_index: usize,
    buffer: []u8,

    const Error = mem.AllocatorError;
    
    pub fn init(buffer: []u8) FixedBufferAllocator {
        return FixedBufferAllocator{
            .buffer = buffer,
            .end_index = 0,
        };
    }

    fn alloc(self: *FixedBufferAllocator, n: usize, alignment: u29) Error![]u8 {
        const addr = @ptrToInt(self.buffer.ptr) + self.end_index;
        const rem = @rem(addr, alignment);
        const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
        const adjusted_index = self.end_index + march_forward_bytes;
        const new_end_index = adjusted_index + n;
        if (new_end_index > self.buffer.len) {
            return error.OutOfMemory;
        }
        const result = self.buffer[adjusted_index..new_end_index];
        self.end_index = new_end_index;

        return result;
    }

    fn realloc(self: *FixedBufferAllocator, old_mem: []u8, new_size: usize, alignment: u29) Error![]u8 {
        assert(old_mem.len <= self.end_index);
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else if (old_mem.ptr == self.buffer.ptr + self.end_index - old_mem.len) {
            const start_index = self.end_index - old_mem.len;
            const new_end_index = start_index + new_size;
            if (new_end_index > self.buffer.len) return error.OutOfMemory;
            const result = self.buffer[start_index..new_end_index];
            self.end_index = new_end_index;
            return result;
        } else {
            const result = try self.alloc(new_size, alignment);
            mem.copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(self: *FixedBufferAllocator, bytes: []u8) void {}
    
    pub fn allocatorInterface(self: *FixedBufferAllocator) AllocatorInterface(*FixedBufferAllocator) {
        return AllocatorInterface(*FixedBufferAllocator).init(self);
    }
    
    pub fn allocator(self: *FixedBufferAllocator) Allocator {
        return Allocator.init(AbstractAllocator.init(self));
    }
};

/// lock free
pub const ThreadSafeFixedBufferAllocator = struct {
    pub const Self = @This();
    
    end_index: usize,
    buffer: []u8,
    
    const Error = mem.AllocatorError;
    
    pub fn init(buffer: []u8) ThreadSafeFixedBufferAllocator {
        return ThreadSafeFixedBufferAllocator{
            .buffer = buffer,
            .end_index = 0,
        };
    }

    fn alloc(self: *Self, n: usize, alignment: u29) Error![]u8 {
        var end_index = @atomicLoad(usize, &self.end_index, builtin.AtomicOrder.SeqCst);
        while (true) {
            const addr = @ptrToInt(self.buffer.ptr) + end_index;
            const rem = @rem(addr, alignment);
            const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
            const adjusted_index = end_index + march_forward_bytes;
            const new_end_index = adjusted_index + n;
            if (new_end_index > self.buffer.len) {
                return error.OutOfMemory;
            }
            end_index = @cmpxchgWeak(usize, &self.end_index, end_index, new_end_index, builtin.AtomicOrder.SeqCst, builtin.AtomicOrder.SeqCst) orelse return self.buffer[adjusted_index..new_end_index];
        }
    }

    fn realloc(self: *Self, old_mem: []u8, new_size: usize, alignment: u29) Error![]u8 {
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            const result = try self.alloc(new_size, alignment);
            mem.copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(self: *Self, bytes: []u8) void {}
    
    pub fn allocatorInterface(self: *Self) AllocatorInterface(*Self) {
        return AllocatorInterface(*Self).init(self);
    }
    
    pub fn allocator(self: *Self) Allocator {
        return Allocator.init(AbstractAllocator.init(self));
    }
};

pub fn stackFallback(comptime size: usize, fallback_allocator: Allocator) StackFallbackAllocator(size) {
    return StackFallbackAllocator(size){
        .buffer = undefined,
        .fallback_allocator = fallback_allocator,
        .fixed_buffer_allocator = undefined,
    };
}

pub fn StackFallbackAllocator(comptime size: usize) type {
    return struct {
        const Self = @This();

        buffer: [size]u8,
        fallback_allocator: Allocator,
        fixed_buffer_allocator: FixedBufferAllocator,

        const Error = mem.AllocatorError;
        
        pub fn get(self: *Self) Allocator {
            self.fixed_buffer_allocator = FixedBufferAllocator.init(self.buffer[0..]);
            return self.allocator();
        }

        fn alloc(self: *Self, n: usize, alignment: u29) Error![]u8 {
            return self.fixed_buffer_allocator.alloc(n, alignment) catch
                self.fallback_allocator.impl.alloc(n, alignment);
        }

        fn realloc(self: *Self, old_mem: []u8, new_size: usize, alignment: u29) Error![]u8 {
            const in_buffer = @ptrToInt(old_mem.ptr) >= @ptrToInt(&self.buffer) and
                @ptrToInt(old_mem.ptr) < @ptrToInt(&self.buffer) + self.buffer.len;
            if (in_buffer) {
                return self.fixed_buffer_allocator.realloc(
                    old_mem,
                    new_size,
                    alignment,
                ) catch {
                    const result = try self.fallback_allocator.impl.alloc(
                        new_size,
                        alignment,
                    );
                    mem.copy(u8, result, old_mem);
                    return result;
                };
            }
            return self.fallback_allocator.impl.realloc(old_mem, new_size, alignment);
        }

        fn free(self: *Self, bytes: []u8) void {
            const in_buffer = @ptrToInt(bytes.ptr) >= @ptrToInt(&self.buffer) and
                @ptrToInt(bytes.ptr) < @ptrToInt(&self.buffer) + self.buffer.len;
            if (!in_buffer) {
                return self.fallback_allocator.impl.free(bytes);
            }
        }
        
        pub fn allocatorInterface(self: *Self) AllocatorInterface(*Self) {
            return AllocatorInterface(*Self).init(self);
        }
        
        pub fn allocator(self: *Self) Allocator {
            return Allocator.init(AbstractAllocator.init(self));
        }
    };
}

test "std.heap.c_allocator" {
    if (builtin.link_libc) {
        var slice = try c_allocator.alloc(u8, 50); // catch return;
        defer c_allocator.free(slice);
        slice = try c_allocator.realloc(u8, slice, 100); // catch return;
    }
}

test "std.heap.DirectAllocator" {
    var direct_allocator = DirectAllocator.init();
    defer direct_allocator.deinit();

    const allocator = direct_allocator.allocator();
    try testAllocator(allocator);
    try testAllocatorAligned(allocator, 16);
    try testAllocatorLargeAlignment(allocator);
}

test "std.heap.ArenaAllocator" {
    var direct_allocator = DirectAllocator.init();
    defer direct_allocator.deinit();

    var arena_allocator = ArenaAllocator.init(direct_allocator.allocator());
    defer arena_allocator.deinit();

    try testAllocator(arena_allocator.allocator());
    try testAllocatorAligned(arena_allocator.allocator(), 16);
    try testAllocatorLargeAlignment(arena_allocator.allocator());
}

var test_fixed_buffer_allocator_memory: [30000 * @sizeOf(usize)]u8 = undefined;
test "std.heap.FixedBufferAllocator" {
    var fixed_buffer_allocator = FixedBufferAllocator.init(test_fixed_buffer_allocator_memory[0..]);

    try testAllocator(fixed_buffer_allocator.allocator());
    try testAllocatorAligned(fixed_buffer_allocator.allocator(), 16);
    try testAllocatorLargeAlignment(fixed_buffer_allocator.allocator());
}

test "std.heap.FixedBufferAllocator Reuse memory on realloc" {
    var small_fixed_buffer: [10]u8 = undefined;
    // check if we re-use the memory
    {
        var fixed_buffer_allocator = FixedBufferAllocator.init(small_fixed_buffer[0..]);

        var slice0 = try fixed_buffer_allocator.allocator().alloc(u8, 5);
        assert(slice0.len == 5);
        var slice1 = try fixed_buffer_allocator.allocator().realloc(u8, slice0, 10);
        assert(slice1.ptr == slice0.ptr);
        assert(slice1.len == 10);
        debug.assertError(fixed_buffer_allocator.allocator().realloc(u8, slice1, 11), error.OutOfMemory);
    }
    // check that we don't re-use the memory if it's not the most recent block
    {
        var fixed_buffer_allocator = FixedBufferAllocator.init(small_fixed_buffer[0..]);

        var slice0 = try fixed_buffer_allocator.allocator().alloc(u8, 2);
        slice0[0] = 1;
        slice0[1] = 2;
        var slice1 = try fixed_buffer_allocator.allocator().alloc(u8, 2);
        var slice2 = try fixed_buffer_allocator.allocator().realloc(u8, slice0, 4);
        assert(slice0.ptr != slice2.ptr);
        assert(slice1.ptr != slice2.ptr);
        assert(slice2[0] == 1);
        assert(slice2[1] == 2);
    }
}

test "std.heap.ThreadSafeFixedBufferAllocator" {
    var fixed_buffer_allocator = ThreadSafeFixedBufferAllocator.init(test_fixed_buffer_allocator_memory[0..]);

    try testAllocator(fixed_buffer_allocator.allocator());
    try testAllocatorAligned(fixed_buffer_allocator.allocator(), 16);
    try testAllocatorLargeAlignment(fixed_buffer_allocator.allocator());
}

fn testAllocator(allocator: mem.Allocator) !void {
    var slice = try allocator.alloc(*i32, 100);
    assert(slice.len == 100);
    for (slice) |*item, i| {
        item.* = try allocator.create(@intCast(i32, i));
    }

    slice = try allocator.realloc(*i32, slice, 20000);
    assert(slice.len == 20000);

    for (slice[0..100]) |item, i| {
        assert(item.* == @intCast(i32, i));
        allocator.destroy(item);
    }

    slice = try allocator.realloc(*i32, slice, 50);
    assert(slice.len == 50);
    slice = try allocator.realloc(*i32, slice, 25);
    assert(slice.len == 25);
    slice = try allocator.realloc(*i32, slice, 0);
    assert(slice.len == 0);
    slice = try allocator.realloc(*i32, slice, 10);
    assert(slice.len == 10);

    allocator.free(slice);
}

fn testAllocatorAligned(allocator: mem.Allocator, comptime alignment: u29) !void {
    // initial
    var slice = try allocator.alignedAlloc(u8, alignment, 10);
    assert(slice.len == 10);
    // grow
    slice = try allocator.alignedRealloc(u8, alignment, slice, 100);
    assert(slice.len == 100);
    // shrink
    slice = try allocator.alignedRealloc(u8, alignment, slice, 10);
    assert(slice.len == 10);
    // go to zero
    slice = try allocator.alignedRealloc(u8, alignment, slice, 0);
    assert(slice.len == 0);
    // realloc from zero
    slice = try allocator.alignedRealloc(u8, alignment, slice, 100);
    assert(slice.len == 100);
    // shrink with shrink
    slice = allocator.alignedShrink(u8, alignment, slice, 10);
    assert(slice.len == 10);
    // shrink to zero
    slice = allocator.alignedShrink(u8, alignment, slice, 0);
    assert(slice.len == 0);
}

fn testAllocatorLargeAlignment(allocator: mem.Allocator) !void {
    //Maybe a platform's page_size is actually the same as or
    //  very near usize?
    if (os.page_size << 2 > maxInt(usize)) return;

    const USizeShift = @IntType(false, std.math.log2(usize.bit_count));
    const large_align = u29(os.page_size << 2);

    var align_mask: usize = undefined;
    _ = @shlWithOverflow(usize, ~usize(0), USizeShift(@ctz(large_align)), &align_mask);

    var slice = try allocator.impl.alloc(500, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.impl.realloc(slice, 100, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.impl.realloc(slice, 5000, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.impl.realloc(slice, 10, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.impl.realloc(slice, 20000, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    allocator.free(slice);
}
