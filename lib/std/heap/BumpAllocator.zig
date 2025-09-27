const std = @import("../std.zig");
const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

unused: usize,
buffer_end: [*]u8,

pub fn init(buffer: []u8) @This() {
    return .{
        .unused = buffer.len,
        .buffer_end = buffer.ptr + buffer.len,
    };
}

pub fn allocator(self: *@This()) Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        },
    };
}

/// Save the current state of the allocator
pub fn savestate(self: *@This()) usize {
    return self.unused;
}

/// Restore a previously saved allocator state
pub fn restore(self: *@This(), state: usize) void {
    self.unused = state;
}

pub fn alloc(
    ctx: *anyopaque,
    length: usize,
    alignment: Alignment,
    _: usize,
) ?[*]u8 {
    const self: *@This() = @ptrCast(@alignCast(ctx));

    const buffer_base = self.buffer_end - self.unused;
    const align_bytes = alignment.toByteUnits();
    const ptr_adjust = std.mem.alignPointerOffset(buffer_base, align_bytes);
    const align_overhead = ptr_adjust orelse return null;

    // Only allocate if we have enough space
    const allocated_length = length + align_overhead;
    if (allocated_length > self.unused) return null;

    self.unused = self.unused - allocated_length;
    return buffer_base + align_overhead;
}

pub fn resize(
    ctx: *anyopaque,
    memory: []u8,
    _: Alignment,
    new_length: usize,
    _: usize,
) bool {
    const self: *@This() = @ptrCast(@alignCast(ctx));

    // Prior allocations can be shrunk, but not grown
    const next_alloc = memory.ptr + memory.len;
    const buffer_base = self.buffer_end - self.unused;
    const shrinking = memory.len >= new_length;
    if (next_alloc != buffer_base) return shrinking;

    // Grow allocations only if we have enough space
    const overflow = new_length > self.unused + memory.len;
    if (!shrinking and overflow) return false;

    self.unused = (self.unused + memory.len) - new_length;
    return true;
}

pub fn remap(
    ctx: *anyopaque,
    memory: []u8,
    _: Alignment,
    new_length: usize,
    _: usize,
) ?[*]u8 {
    if (resize(ctx, memory, undefined, new_length, undefined)) {
        return memory.ptr;
    } else {
        return null;
    }
}

pub fn free(
    ctx: *anyopaque,
    memory: []u8,
    _: Alignment,
    _: usize,
) void {
    const self: *@This() = @ptrCast(@alignCast(ctx));

    // Only free the immediate last allocation
    const next_alloc = memory.ptr + memory.len;
    const buffer_base = self.buffer_end - self.unused;
    if (next_alloc != buffer_base) return;

    self.unused = self.unused + memory.len;
}

test "BumpAllocator" {
    var buffer: [1 << 20]u8 = undefined;
    var bump_allocator: @This() = .init(&buffer);
    const gpa = bump_allocator.allocator();

    try std.heap.testAllocator(gpa);
    try std.heap.testAllocatorAligned(gpa);
    try std.heap.testAllocatorAlignedShrink(gpa);
    try std.heap.testAllocatorLargeAlignment(gpa);
}

test "savestate and restore" {
    var buffer: [256]u8 = undefined;
    var bump_allocator: @This() = .init(&buffer);
    const gpa = bump_allocator.allocator();

    const state_before = bump_allocator.savestate();
    _ = try gpa.alloc(u8, buffer.len);

    bump_allocator.restore(state_before);
    _ = try gpa.alloc(u8, buffer.len);
}

test "reuse memory on realloc" {
    var buffer: [10]u8 = undefined;
    var bump_allocator: @This() = .init(&buffer);
    const gpa = bump_allocator.allocator();

    const slice_0 = try gpa.alloc(u8, 5);
    const slice_1 = try gpa.realloc(slice_0, 10);
    try std.testing.expect(slice_1.ptr == slice_0.ptr);
}

test "don't grow one allocation into another" {
    var buffer: [10]u8 = undefined;
    var bump_allocator: @This() = .init(&buffer);
    const gpa = bump_allocator.allocator();

    const slice_0 = try gpa.alloc(u8, 3);
    const slice_1 = try gpa.alloc(u8, 3);
    const slice_2 = try gpa.realloc(slice_0, 4);
    try std.testing.expect(slice_2.ptr == slice_1.ptr + 3);
}

test "avoid integer overflow for obscene allocations" {
    var buffer: [10]u8 = undefined;
    var bump_allocator: @This() = .init(&buffer);
    const gpa = bump_allocator.allocator();

    _ = try gpa.alloc(u8, 5);
    const problem = gpa.alloc(u8, std.math.maxInt(usize));
    try std.testing.expectError(error.OutOfMemory, problem);
}

test "works at comptime" {
    comptime {
        var buffer: [256]u8 = undefined;
        var bump_allocator: @This() = .init(&buffer);
        const gpa = bump_allocator.allocator();

        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(gpa);
        for ("Hello, World!\n") |byte| {
            try list.append(gpa, byte);
        }
    }
}

/// Deprecated; to be removed after 0.16.0 is tagged.
/// Provides a lock free thread safe `Allocator` interface to the underlying `FixedBufferAllocator`
/// Using this at the same time as the interface returned by `allocator` is not thread safe.
pub fn threadSafeAllocator(self: *@This()) Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = threadSafeAlloc,
            .resize = Allocator.noResize,
            .remap = Allocator.noRemap,
            .free = Allocator.noFree,
        },
    };
}

// Remove after 0.16.0 is tagged.
fn threadSafeAlloc(
    ctx: *anyopaque,
    length: usize,
    alignment: Alignment,
    _: usize,
) ?[*]u8 {
    const self: *@This() = @ptrCast(@alignCast(ctx));
    const align_bytes = alignment.toByteUnits();

    var old_unused = @atomicLoad(usize, &self.unused, .seq_cst);

    while (true) {
        const buffer_base = self.buffer_end - old_unused;
        const align_overhead = std.mem.alignPointerOffset(buffer_base, align_bytes) orelse return null;

        const allocated_length = length + align_overhead;
        if (allocated_length > old_unused) return null;

        const new_unused = old_unused - allocated_length;

        if (@cmpxchgWeak(usize, &self.unused, old_unused, new_unused, .seq_cst, .seq_cst)) |prev| {
            old_unused = prev;
            continue;
        }

        return buffer_base + align_overhead;
    }
}

// Remove after 0.16.0 is tagged.
test "thread safe version" {
    var buffer: [1 << 20]u8 = undefined;
    var bump_allocator: @This() = .init(&buffer);
    const gpa = bump_allocator.threadSafeAllocator();

    try std.heap.testAllocator(gpa);
    try std.heap.testAllocatorAligned(gpa);
    try std.heap.testAllocatorAlignedShrink(gpa);
    try std.heap.testAllocatorLargeAlignment(gpa);
}
