const std = @import("../std.zig");
const assert = std.debug.assert;
const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;
const safety = std.debug.runtime_safety;

start: if (safety) [*]u8 else void,
bump: [*]u8,
end: [*]u8,

pub fn init(buffer: []u8) @This() {
    return .{
        .start = if (safety) buffer.ptr else {},
        .bump = buffer.ptr,
        .end = buffer.ptr + buffer.len,
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

/// Provides a lock free thread safe `Allocator` interface to the underlying `FixedBufferAllocator`
/// Using this at the same time as the interface returned by `allocator` is not thread safe.
/// Deprecated; to be removed after 0.16.0 is tagged.
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

/// Save the current state of the bump allocator
pub fn savestate(self: *@This()) usize {
    return @intFromPtr(self.bump);
}

/// Restore a previously saved allocator state (see savestate).
/// Use @intFromPtr(buffer.ptr) to reset the bump allocator.
pub fn restore(self: *@This(), state: usize) void {
    if (safety) assert(state >= @intFromPtr(self.start));
    assert(state <= @intFromPtr(self.end));
    self.bump = @ptrFromInt(state);
}

pub fn alloc(
    ctx: *anyopaque,
    length: usize,
    alignment: Alignment,
    _: usize,
) ?[*]u8 {
    const self: *@This() = @ptrCast(@alignCast(ctx));

    if (@inComptime()) {
        // Alignment greater than 1 requires us to know the self.bump
        // pointer value, which is not currently possible at comptime.
        assert(alignment == .@"1" or alignment == .@"0");
        const address = self.bump;
        self.bump += length;
        return address;
    }

    // Forward alignment is slightly more expensive than backwards alignment,
    // but in exchange we can grow our last allocation without wasting memory.
    const aligned = alignment.forward(@intFromPtr(self.bump));
    const end_addr, const overflow = @addWithOverflow(aligned, length);

    // Guard against overflowing a usize, not just exceeding the end pointer.
    // Bitwise OR is used here as short-circuiting emits another branch.
    const exceed = end_addr > @intFromPtr(self.end);
    if ((overflow == 1) | exceed) return null;

    self.bump = @ptrFromInt(end_addr);
    return @ptrFromInt(aligned);
}

pub fn resize(
    ctx: *anyopaque,
    memory: []u8,
    _: Alignment,
    new_length: usize,
    _: usize,
) bool {
    const self: *@This() = @ptrCast(@alignCast(ctx));

    // We cannot compare pointer values at comptime, which is
    // required to see if growing an allocation would OOM.
    const shrinking = new_length <= memory.len;
    if (@inComptime()) return shrinking;

    // Allocating memory sets the bump pointer to the next free address.
    // If memory is not the most recent allocation, it cannot be grown.
    if (memory.ptr + memory.len != self.bump) return shrinking;

    const alloc_base = @intFromPtr(memory.ptr);
    if (safety) assert(alloc_base >= @intFromPtr(self.start));
    assert(alloc_base <= @intFromPtr(self.bump));

    // For the most recent allocation, we can OOM iff we are not shrinking the
    // allocation, and alloc_base + new_length exceeds or overflows self.end.
    const end_addr, const overflow = @addWithOverflow(alloc_base, new_length);
    const exceed = end_addr > @intFromPtr(self.end);
    if (!shrinking and ((overflow == 1) | exceed)) return false;

    self.bump = @ptrFromInt(end_addr);
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

    // Only the last allocation can be freed, and only fully
    // if the alignment cost for it's allocation was a noop.
    if (memory.ptr + memory.len != self.bump) return;
    self.bump = self.bump - memory.len;

    // The safety checks below verify that we own the memory just freed.
    // We cannot run these safety checks at comptime due to @intFromPtr.
    if (@inComptime()) return;

    const alloc_base = @intFromPtr(memory.ptr);
    if (safety) assert(alloc_base >= @intFromPtr(self.start));
    assert(alloc_base <= @intFromPtr(self.bump));
}

/// Deprecated; to be removed after 0.16.0 is tagged.
fn threadSafeAlloc(
    ctx: *anyopaque,
    length: usize,
    alignment: Alignment,
    _: usize,
) ?[*]u8 {
    const self: *@This() = @ptrCast(@alignCast(ctx));

    var old_bump: [*]u8 = @atomicLoad([*]u8, &self.bump, .seq_cst);
    while (true) {
        const aligned = alignment.forward(@intFromPtr(old_bump));
        const end_addr, const overflow = @addWithOverflow(aligned, length);

        const exceed = end_addr > @intFromPtr(self.end);
        if ((overflow == 1) | exceed) return null;

        const new_bump: [*]u8 = @ptrFromInt(end_addr);
        if (@cmpxchgWeak([*]u8, &self.bump, old_bump, new_bump, .seq_cst, .seq_cst)) |prev| {
            old_bump = prev;
            continue;
        }

        return @ptrFromInt(aligned);
    }
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

test "works at comptime for alignments <= 1" {
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

// Deprecated; to be removed after 0.16.0 is tagged.
test "thread safe version" {
    var buffer: [1 << 20]u8 = undefined;
    var bump_allocator: @This() = .init(&buffer);
    const gpa = bump_allocator.threadSafeAllocator();

    try std.heap.testAllocator(gpa);
    try std.heap.testAllocatorAligned(gpa);
    try std.heap.testAllocatorAlignedShrink(gpa);
    try std.heap.testAllocatorLargeAlignment(gpa);
}
