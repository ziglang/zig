const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const alignPageAllocLen = std.heap.alignPageAllocLen;

comptime {
    if (!builtin.target.isWasm()) {
        @compileError("WasmPageAllocator is only available for wasm32 arch");
    }
}

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

const PageStatus = enum(u1) {
    used = 0,
    free = 1,

    pub const none_free: u8 = 0;
};

const FreeBlock = struct {
    data: []u128,

    const Io = std.packed_int_array.PackedIntIo(u1, .Little);

    fn totalPages(self: FreeBlock) usize {
        return self.data.len * 128;
    }

    fn isInitialized(self: FreeBlock) bool {
        return self.data.len > 0;
    }

    fn getBit(self: FreeBlock, idx: usize) PageStatus {
        const bit_offset = 0;
        return @intToEnum(PageStatus, Io.get(mem.sliceAsBytes(self.data), idx, bit_offset));
    }

    fn setBits(self: FreeBlock, start_idx: usize, len: usize, val: PageStatus) void {
        const bit_offset = 0;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            Io.set(mem.sliceAsBytes(self.data), start_idx + i, bit_offset, @enumToInt(val));
        }
    }

    // Use '0xFFFFFFFF' as a _missing_ sentinel
    // This saves ~50 bytes compared to returning a nullable

    // We can guarantee that conventional memory never gets this big,
    // and wasm32 would not be able to address this memory (32 GB > usize).

    // Revisit if this is settled: https://github.com/ziglang/zig/issues/3806
    const not_found = std.math.maxInt(usize);

    fn useRecycled(self: FreeBlock, num_pages: usize, alignment: u29) usize {
        @setCold(true);
        for (self.data) |segment, i| {
            const spills_into_next = @bitCast(i128, segment) < 0;
            const has_enough_bits = @popCount(segment) >= num_pages;

            if (!spills_into_next and !has_enough_bits) continue;

            var j: usize = i * 128;
            while (j < (i + 1) * 128) : (j += 1) {
                var count: usize = 0;
                while (j + count < self.totalPages() and self.getBit(j + count) == .free) {
                    count += 1;
                    const addr = j * mem.page_size;
                    if (count >= num_pages and mem.isAligned(addr, alignment)) {
                        self.setBits(j, num_pages, .used);
                        return j;
                    }
                }
                j += count;
            }
        }
        return not_found;
    }

    fn recycle(self: FreeBlock, start_idx: usize, len: usize) void {
        self.setBits(start_idx, len, .free);
    }
};

var _conventional_data = [_]u128{0} ** 16;
// Marking `conventional` as const saves ~40 bytes
const conventional = FreeBlock{ .data = &_conventional_data };
var extended = FreeBlock{ .data = &[_]u128{} };

fn extendedOffset() usize {
    return conventional.totalPages();
}

fn nPages(memsize: usize) usize {
    return mem.alignForward(memsize, mem.page_size) / mem.page_size;
}

fn alloc(_: *anyopaque, len: usize, alignment: u29, len_align: u29, ra: usize) error{OutOfMemory}![]u8 {
    _ = ra;
    if (len > maxInt(usize) - (mem.page_size - 1)) {
        return error.OutOfMemory;
    }
    const page_count = nPages(len);
    const page_idx = try allocPages(page_count, alignment);
    return @intToPtr([*]u8, page_idx * mem.page_size)[0..alignPageAllocLen(page_count * mem.page_size, len, len_align)];
}
fn allocPages(page_count: usize, alignment: u29) !usize {
    {
        const idx = conventional.useRecycled(page_count, alignment);
        if (idx != FreeBlock.not_found) {
            return idx;
        }
    }

    const idx = extended.useRecycled(page_count, alignment);
    if (idx != FreeBlock.not_found) {
        return idx + extendedOffset();
    }

    const next_page_idx = @wasmMemorySize(0);
    const next_page_addr = next_page_idx * mem.page_size;
    const aligned_addr = mem.alignForward(next_page_addr, alignment);
    const drop_page_count = @divExact(aligned_addr - next_page_addr, mem.page_size);
    const result = @wasmMemoryGrow(0, @intCast(u32, drop_page_count + page_count));
    if (result <= 0)
        return error.OutOfMemory;
    assert(result == next_page_idx);
    const aligned_page_idx = next_page_idx + drop_page_count;
    if (drop_page_count > 0) {
        freePages(next_page_idx, aligned_page_idx);
    }
    return @intCast(usize, aligned_page_idx);
}

fn freePages(start: usize, end: usize) void {
    if (start < extendedOffset()) {
        conventional.recycle(start, @min(extendedOffset(), end) - start);
    }
    if (end > extendedOffset()) {
        var new_end = end;
        if (!extended.isInitialized()) {
            // Steal the last page from the memory currently being recycled
            // TODO: would it be better if we use the first page instead?
            new_end -= 1;

            extended.data = @intToPtr([*]u128, new_end * mem.page_size)[0 .. mem.page_size / @sizeOf(u128)];
            // Since this is the first page being freed and we consume it, assume *nothing* is free.
            mem.set(u128, extended.data, PageStatus.none_free);
        }
        const clamped_start = std.math.max(extendedOffset(), start);
        extended.recycle(clamped_start - extendedOffset(), new_end - clamped_start);
    }
}

fn resize(
    _: *anyopaque,
    buf: []u8,
    buf_align: u29,
    new_len: usize,
    len_align: u29,
    return_address: usize,
) ?usize {
    _ = buf_align;
    _ = return_address;
    const aligned_len = mem.alignForward(buf.len, mem.page_size);
    if (new_len > aligned_len) return null;
    const current_n = nPages(aligned_len);
    const new_n = nPages(new_len);
    if (new_n != current_n) {
        const base = nPages(@ptrToInt(buf.ptr));
        freePages(base + new_n, base + current_n);
    }
    return alignPageAllocLen(new_n * mem.page_size, new_len, len_align);
}

fn free(
    _: *anyopaque,
    buf: []u8,
    buf_align: u29,
    return_address: usize,
) void {
    _ = buf_align;
    _ = return_address;
    const aligned_len = mem.alignForward(buf.len, mem.page_size);
    const current_n = nPages(aligned_len);
    const base = nPages(@ptrToInt(buf.ptr));
    freePages(base, base + current_n);
}
