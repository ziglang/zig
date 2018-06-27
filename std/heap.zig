const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const os = std.os;
const builtin = @import("builtin");
const Os = builtin.Os;
const c = std.c;

const Allocator = mem.Allocator;

pub const c_allocator = &c_allocator_state;
var c_allocator_state = Allocator{
    .allocFn = cAlloc,
    .reallocFn = cRealloc,
    .freeFn = cFree,
};

fn cAlloc(self: *Allocator, n: usize, alignment: u29) ![]u8 {
    assert(alignment <= @alignOf(c_longdouble));
    return if (c.malloc(n)) |buf| @ptrCast([*]u8, buf)[0..n] else error.OutOfMemory;
}

fn cRealloc(self: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
    const old_ptr = @ptrCast(*c_void, old_mem.ptr);
    if (c.realloc(old_ptr, new_size)) |buf| {
        return @ptrCast([*]u8, buf)[0..new_size];
    } else if (new_size <= old_mem.len) {
        return old_mem[0..new_size];
    } else {
        return error.OutOfMemory;
    }
}

fn cFree(self: *Allocator, old_mem: []u8) void {
    const old_ptr = @ptrCast(*c_void, old_mem.ptr);
    c.free(old_ptr);
}

/// This allocator makes a syscall directly for every allocation and free.
pub const DirectAllocator = struct {
    allocator: Allocator,
    heap_handle: ?HeapHandle,

    const HeapHandle = if (builtin.os == Os.windows) os.windows.HANDLE else void;

    pub fn init() DirectAllocator {
        return DirectAllocator{
            .allocator = Allocator{
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free,
            },
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

    fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(DirectAllocator, "allocator", allocator);

        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
                const p = os.posix;
                const alloc_size = if (alignment <= os.page_size) n else n + alignment;
                const addr = p.mmap(null, alloc_size, p.PROT_READ | p.PROT_WRITE, p.MAP_PRIVATE | p.MAP_ANONYMOUS, -1, 0);
                if (addr == p.MAP_FAILED) return error.OutOfMemory;

                if (alloc_size == n) return @intToPtr([*]u8, addr)[0..n];

                var aligned_addr = addr & ~usize(alignment - 1);
                aligned_addr += alignment;

                //We can unmap the unused portions of our mmap, but we must only
                //  pass munmap bytes that exist outside our allocated pages or it
                //  will happily eat us too

                //Since alignment > page_size, we are by definition on a page boundry
                const unused_start = addr;
                const unused_len = aligned_addr - 1 - unused_start;

                var err = p.munmap(unused_start, unused_len);
                debug.assert(p.getErrno(err) == 0);

                //It is impossible that there is an unoccupied page at the top of our
                //  mmap.

                return @intToPtr([*]u8, aligned_addr)[0..n];
            },
            Os.windows => {
                const amt = n + alignment + @sizeOf(usize);
                const heap_handle = self.heap_handle orelse blk: {
                    const hh = os.windows.HeapCreate(os.windows.HEAP_NO_SERIALIZE, amt, 0) orelse return error.OutOfMemory;
                    self.heap_handle = hh;
                    break :blk hh;
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

    fn realloc(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(DirectAllocator, "allocator", allocator);

        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
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

                const result = try alloc(allocator, new_size, alignment);
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

    fn free(allocator: *Allocator, bytes: []u8) void {
        const self = @fieldParentPtr(DirectAllocator, "allocator", allocator);

        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
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
};

/// This allocator takes an existing allocator, wraps it, and provides an interface
/// where you can allocate without freeing, and then free it all together.
pub const ArenaAllocator = struct {
    pub allocator: Allocator,

    child_allocator: *Allocator,
    buffer_list: std.LinkedList([]u8),
    end_index: usize,

    const BufNode = std.LinkedList([]u8).Node;

    pub fn init(child_allocator: *Allocator) ArenaAllocator {
        return ArenaAllocator{
            .allocator = Allocator{
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free,
            },
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

    fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(ArenaAllocator, "allocator", allocator);

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

    fn realloc(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            const result = try alloc(allocator, new_size, alignment);
            mem.copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(allocator: *Allocator, bytes: []u8) void {}
};

pub const FixedBufferAllocator = struct {
    allocator: Allocator,
    end_index: usize,
    buffer: []u8,

    pub fn init(buffer: []u8) FixedBufferAllocator {
        return FixedBufferAllocator{
            .allocator = Allocator{
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free,
            },
            .buffer = buffer,
            .end_index = 0,
        };
    }

    fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(FixedBufferAllocator, "allocator", allocator);
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

    fn realloc(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            const result = try alloc(allocator, new_size, alignment);
            mem.copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(allocator: *Allocator, bytes: []u8) void {}
};

/// lock free
pub const ThreadSafeFixedBufferAllocator = struct {
    allocator: Allocator,
    end_index: usize,
    buffer: []u8,

    pub fn init(buffer: []u8) ThreadSafeFixedBufferAllocator {
        return ThreadSafeFixedBufferAllocator{
            .allocator = Allocator{
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free,
            },
            .buffer = buffer,
            .end_index = 0,
        };
    }

    fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(ThreadSafeFixedBufferAllocator, "allocator", allocator);
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

    fn realloc(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            const result = try alloc(allocator, new_size, alignment);
            mem.copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(allocator: *Allocator, bytes: []u8) void {}
};

test "c_allocator" {
    if (builtin.link_libc) {
        var slice = c_allocator.alloc(u8, 50) catch return;
        defer c_allocator.free(slice);
        slice = c_allocator.realloc(u8, slice, 100) catch return;
    }
}

test "DirectAllocator" {
    var direct_allocator = DirectAllocator.init();
    defer direct_allocator.deinit();

    const allocator = &direct_allocator.allocator;
    try testAllocator(allocator);
    try testAllocatorLargeAlignment(allocator);
}

test "ArenaAllocator" {
    var direct_allocator = DirectAllocator.init();
    defer direct_allocator.deinit();

    var arena_allocator = ArenaAllocator.init(&direct_allocator.allocator);
    defer arena_allocator.deinit();

    try testAllocator(&arena_allocator.allocator);
    try testAllocatorLargeAlignment(&arena_allocator.allocator);
}

var test_fixed_buffer_allocator_memory: [30000 * @sizeOf(usize)]u8 = undefined;
test "FixedBufferAllocator" {
    var fixed_buffer_allocator = FixedBufferAllocator.init(test_fixed_buffer_allocator_memory[0..]);

    try testAllocator(&fixed_buffer_allocator.allocator);
    try testAllocatorLargeAlignment(&fixed_buffer_allocator.allocator);
}

test "ThreadSafeFixedBufferAllocator" {
    var fixed_buffer_allocator = ThreadSafeFixedBufferAllocator.init(test_fixed_buffer_allocator_memory[0..]);

    try testAllocator(&fixed_buffer_allocator.allocator);
    try testAllocatorLargeAlignment(&fixed_buffer_allocator.allocator);
}

fn testAllocator(allocator: *mem.Allocator) !void {
    var slice = try allocator.alloc(*i32, 100);

    for (slice) |*item, i| {
        item.* = try allocator.create(@intCast(i32, i));
    }

    for (slice) |item, i| {
        allocator.destroy(item);
    }

    slice = try allocator.realloc(*i32, slice, 20000);
    slice = try allocator.realloc(*i32, slice, 50);
    slice = try allocator.realloc(*i32, slice, 25);
    slice = try allocator.realloc(*i32, slice, 10);

    allocator.free(slice);
}

fn testAllocatorLargeAlignment(allocator: *mem.Allocator) mem.Allocator.Error!void {
    //Maybe a platform's page_size is actually the same as or
    //  very near usize?
    if (os.page_size << 2 > @maxValue(usize)) return;

    const USizeShift = @IntType(false, std.math.log2(usize.bit_count));
    const large_align = u29(os.page_size << 2);

    var align_mask: usize = undefined;
    _ = @shlWithOverflow(usize, ~usize(0), USizeShift(@ctz(large_align)), &align_mask);

    var slice = try allocator.allocFn(allocator, 500, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.reallocFn(allocator, slice, 100, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.reallocFn(allocator, slice, 5000, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.reallocFn(allocator, slice, 10, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    slice = try allocator.reallocFn(allocator, slice, 20000, large_align);
    debug.assert(@ptrToInt(slice.ptr) & align_mask == @ptrToInt(slice.ptr));

    allocator.free(slice);
}
