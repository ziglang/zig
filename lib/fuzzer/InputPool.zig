const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const InputPool = @This();

// Key observations:
// * string are either deleted or inserted, never resized
// * we dont need stable pointers to strings.
//   * we need to get random string or iterate over all of them
// * string deletions are rare (only when minimizing corpus)

// therefore

// All strings live in a giant buffer
// We pack them densly one after another
// When freeing, the bytes go unused
// Repack everything sometimes

/// each stored input has this many extra bytes at the end available for inplace
/// growing when mutating
pub const InputExtraBytes = 8;

pub const Index = u31; // total 2GiB of input data should be enough

const Entry = packed struct {
    deleted: bool,
    v: Index,
    fn init(v: usize) Entry {
        return .{
            .v = std.math.cast(Index, v) orelse @panic("fuzzer input address space exhaused"),
            .deleted = false,
        };
    }
};

/// Stores the strings
buffer: std.ArrayListUnmanaged(u8) = .{},

/// Bookkeeping of the ends of stored strings
/// Given index i, string i starts at ends[i-1].v and first byte outside the
/// string is at ends[i].v (unless i==0 in which case the first byte is at 0)
ends: std.ArrayListUnmanaged(Entry) = .{},

/// Sum of lengths of all deleted strings. Used to decide if we want to repack
/// everything.
deletedBytes: usize = 0,

pub fn deinit(ip: *InputPool, a: Allocator) void {
    ip.buffer.deinit(a);
    ip.ends.deinit(a);
}

fn sliceContainsPtr(container: []const u8, ptr: [*]const u8) bool {
    return @intFromPtr(ptr) >= @intFromPtr(container.ptr) and
        @intFromPtr(ptr) < (@intFromPtr(container.ptr) + container.len);
}

fn sliceContainsSlice(container: []const u8, slice: []const u8) bool {
    return @intFromPtr(slice.ptr) >= @intFromPtr(container.ptr) and
        (@intFromPtr(slice.ptr) + slice.len) <= (@intFromPtr(container.ptr) + container.len);
}

/// Given string is copied
pub fn insertString(ip: *InputPool, a: Allocator, str: []const u8) error{OutOfMemory}!void {
    const maybeRelocatedStr = b: {
        // we have to be careful because the inserted string can live inside
        // the buffer and growing the buffer might invalidate the pointer that
        // was given to us.
        if (sliceContainsPtr(ip.buffer.items, str.ptr)) {
            assert(sliceContainsSlice(ip.buffer.items, str));
            const index = @intFromPtr(str.ptr) - @intFromPtr(ip.buffer.items.ptr);

            try ip.buffer.ensureUnusedCapacity(a, str.len + InputExtraBytes);
            try ip.ends.ensureUnusedCapacity(a, 1);

            // the slice needs to happen *after* the growing
            break :b ip.buffer.items[index..][0..str.len];
        } else {
            try ip.buffer.ensureUnusedCapacity(a, str.len + InputExtraBytes);
            try ip.ends.ensureUnusedCapacity(a, 1);

            break :b str;
        }
    };

    errdefer comptime unreachable; // no partially writter string on OOM

    ip.buffer.appendSliceAssumeCapacity(maybeRelocatedStr);
    ip.buffer.appendNTimesAssumeCapacity(undefined, InputExtraBytes);
    ip.ends.appendAssumeCapacity(Entry.init(ip.buffer.items.len));
}

/// Marks string as deleted but bytes are reused only after a call to repack
pub fn deleteString(ip: *InputPool, index: Index) void {
    ip.ends.items[index].deleted = true;
    ip.deletedBytes += ip.getString(index).len + InputExtraBytes;
}

/// Invalidates all indexes
pub fn maybeRepack(ip: *InputPool) void {
    const total = ip.buffer.items.len;
    if (ip.deletedBytes > 4096 and ip.deletedBytes > total / 2) {
        ip.repack();
    }
}

fn repack(ip: *InputPool) void {
    // end of copied-over inputs
    var poolWriteHead: usize = 0;
    var endsWriteHead: usize = 0;

    for (0..ip.ends.items.len) |i| {
        const start = if (i == 0) 0 else ip.ends.items[i - 1].v;
        const one_past_end = ip.ends.items[i].v;
        const str = ip.buffer.items[start..one_past_end];
        const dest = ip.buffer.items[poolWriteHead..][0..str.len];

        if (ip.ends.items[i].deleted) {
            continue;
        }

        if (str.ptr != dest.ptr) {
            std.mem.copyForwards(u8, dest, str);
            ip.ends.items[endsWriteHead] = Entry.init(poolWriteHead + str.len);
        }
        poolWriteHead += str.len;
        endsWriteHead += 1;
    }

    ip.ends.items.len = endsWriteHead;
    ip.buffer.items.len = poolWriteHead;
}

/// Number of strings stored
pub fn len(ip: InputPool) Index {
    return @intCast(ip.ends.items.len);
}

/// Returns string under this index. indexes are not stable
pub fn getString(ip: InputPool, index: Index) []u8 {
    const start = if (index == 0) 0 else (ip.ends.items[index - 1].v);
    const one_past_end = ip.ends.items[index].v;
    return ip.buffer.items[start..one_past_end];
}

fn x(s: []u8) []u8 {
    return s[0 .. s.len - InputExtraBytes];
}

test {
    const t = std.testing;

    const a = t.allocator;
    var ip = InputPool.init();
    defer ip.deinit(a);

    try ip.insertString(a, "hello");
    try ip.insertString(a, "test");
    try ip.insertString(a, "123");

    try t.expectEqualSlices(u8, "hello", x(ip.getString(0)));
    try t.expectEqualSlices(u8, "test", x(ip.getString(1)));
    try t.expectEqualSlices(u8, "123", x(ip.getString(2)));
    try t.expectEqual(3, ip.len());

    ip.deleteString(1);
    ip.repack();

    try t.expectEqualSlices(u8, "hello", x(ip.getString(0)));
    try t.expectEqualSlices(u8, "123", x(ip.getString(1)));
    try t.expectEqual(2, ip.len());

    ip.deleteString(0);
    ip.repack();

    try t.expectEqualSlices(u8, "123", x(ip.getString(0)));
    try t.expectEqual(1, ip.len());

    ip.deleteString(0);
    ip.repack();

    try t.expectEqual(0, ip.len());
}
