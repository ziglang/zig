const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const os = std.os;
const builtin = @import("builtin");
const Os = builtin.Os;
const c = std.c;

const Allocator = mem.Allocator;

error OutOfMemory;

pub const c_allocator = &c_allocator_state;
var c_allocator_state = Allocator {
    .allocFn = cAlloc,
    .reallocFn = cRealloc,
    .freeFn = cFree,
};

fn cAlloc(self: &Allocator, n: usize, alignment: u29) -> %[]u8 {
    return if (c.malloc(usize(n))) |buf|
        @ptrCast(&u8, buf)[0..n]
    else
        error.OutOfMemory;
}

fn cRealloc(self: &Allocator, old_mem: []u8, new_size: usize, alignment: u29) -> %[]u8 {
    const old_ptr = @ptrCast(&c_void, old_mem.ptr);
    if (c.realloc(old_ptr, new_size)) |buf| {
        return @ptrCast(&u8, buf)[0..new_size];
    } else if (new_size <= old_mem.len) {
        return old_mem[0..new_size];
    } else {
        return error.OutOfMemory;
    }
}

fn cFree(self: &Allocator, old_mem: []u8) {
    const old_ptr = @ptrCast(&c_void, old_mem.ptr);
    c.free(old_ptr);
}

pub const IncrementingAllocator = struct {
    allocator: Allocator,
    bytes: []u8,
    end_index: usize,
    heap_handle: if (builtin.os == Os.windows) os.windows.HANDLE else void,

    fn init(capacity: usize) -> %IncrementingAllocator {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
                const p = os.posix;
                const addr = p.mmap(null, capacity, p.PROT_READ|p.PROT_WRITE,
                    p.MAP_PRIVATE|p.MAP_ANONYMOUS|p.MAP_NORESERVE, -1, 0);
                if (addr == p.MAP_FAILED) {
                    return error.OutOfMemory;
                }
                return IncrementingAllocator {
                    .allocator = Allocator {
                        .allocFn = alloc,
                        .reallocFn = realloc,
                        .freeFn = free,
                    },
                    .bytes = @intToPtr(&u8, addr)[0..capacity],
                    .end_index = 0,
                    .heap_handle = {},
                };
            },
            Os.windows => {
                const heap_handle = os.windows.GetProcessHeap() ?? return error.OutOfMemory;
                const ptr = os.windows.HeapAlloc(heap_handle, 0, capacity) ?? return error.OutOfMemory;
                return IncrementingAllocator {
                    .allocator = Allocator {
                        .allocFn = alloc,
                        .reallocFn = realloc,
                        .freeFn = free,
                    },
                    .bytes = @ptrCast(&u8, ptr)[0..capacity],
                    .end_index = 0,
                    .heap_handle = heap_handle,
                };
            },
            else => @compileError("Unsupported OS"),
        }
    }

    fn deinit(self: &IncrementingAllocator) {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
                _ = os.posix.munmap(self.bytes.ptr, self.bytes.len);
            },
            Os.windows => {
                _ = os.windows.HeapFree(self.heap_handle, 0, @ptrCast(os.windows.LPVOID, self.bytes.ptr));
            },
            else => @compileError("Unsupported OS"),
        }
    }

    fn reset(self: &IncrementingAllocator) {
        self.end_index = 0;
    }

    fn bytesLeft(self: &const IncrementingAllocator) -> usize {
        return self.bytes.len - self.end_index;
    }

    fn alloc(allocator: &Allocator, n: usize, alignment: u29) -> %[]u8 {
        const self = @fieldParentPtr(IncrementingAllocator, "allocator", allocator);
        const addr = @ptrToInt(&self.bytes[self.end_index]);
        const rem = @rem(addr, alignment);
        const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
        const adjusted_index = self.end_index + march_forward_bytes;
        const new_end_index = adjusted_index + n;
        if (new_end_index > self.bytes.len) {
            return error.OutOfMemory;
        }
        const result = self.bytes[adjusted_index .. new_end_index];
        self.end_index = new_end_index;
        return result;
    }

    fn realloc(allocator: &Allocator, old_mem: []u8, new_size: usize, alignment: u29) -> %[]u8 {
        if (new_size <= old_mem.len) {
            return old_mem[0..new_size];
        } else {
            const result = try alloc(allocator, new_size, alignment);
            mem.copy(u8, result, old_mem);
            return result;
        }
    }

    fn free(allocator: &Allocator, bytes: []u8) {
        // Do nothing. That's the point of an incrementing allocator.
    }
};

test "c_allocator" {
    if (builtin.link_libc) {
        var slice = c_allocator.alloc(u8, 50) catch return;
        defer c_allocator.free(slice);
        slice = c_allocator.realloc(u8, slice, 100) catch return;
    }
}

test "IncrementingAllocator" {
    const total_bytes = 100 * 1024 * 1024;
    var inc_allocator = %%IncrementingAllocator.init(total_bytes);
    defer inc_allocator.deinit();

    const allocator = &inc_allocator.allocator;
    const slice = %%allocator.alloc(&i32, 100);

    for (slice) |*item, i| {
        *item = %%allocator.create(i32);
        **item = i32(i);
    }

    assert(inc_allocator.bytesLeft() == total_bytes - @sizeOf(i32) * 100 - @sizeOf(usize) * 100);

    inc_allocator.reset();

    assert(inc_allocator.bytesLeft() == total_bytes);
}

