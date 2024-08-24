const std = @import("std");
const assert = std.debug.assert;
// Key observations:
// * string are either deleted or inserted, never resized
// * we dont need stable pointers to strings.
//   * we need to get random string or iterate over all of them
// * string deletions are somewhat rare (TODO: verify)

// therefore

// All strings live in a giant buffer
// We pack them densly one after another
// When freeing, the bytes go unused
// Repack everything sometimes

// TODO: need to store the features list somewhere

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

/// Bookkeeping of the ends of stored strings
/// Given index i, string i starts at stringEnds[i-1].v and first byte outside
/// the string is at stringEnds[i].v (unless i==0 in which case the first byte
/// is at 0)
var stringEnds = std.ArrayList(Entry).init(std.heap.page_allocator);
var stringPool = std.ArrayList(u8).init(std.heap.page_allocator);

/// Sum of lengths of all deleted strings. Used to decide if we want to repack
/// everything.
var deletedBytes: usize = 0;

fn sliceContainsPtr(container: []const u8, ptr: [*]const u8) bool {
    return @intFromPtr(ptr) >= @intFromPtr(container.ptr) and
        @intFromPtr(ptr) < (@intFromPtr(container.ptr) + container.len);
}

fn sliceContainsSlice(container: []const u8, slice: []const u8) bool {
    return @intFromPtr(slice.ptr) >= @intFromPtr(container.ptr) and
        (@intFromPtr(slice.ptr) + slice.len) <= (@intFromPtr(container.ptr) + container.len);
}

/// Given string is copied
pub fn insertString(str: []const u8) error{OutOfMemory}!void {
    const maybeRelocatedStr = b: {
        // we have to be careful because the inserted string can live inside
        // stringPool and the growing of stringPool might invalidate the
        // pointer that was given to us.
        if (sliceContainsPtr(stringPool.items, str.ptr)) {
            std.debug.print("inserting from inside\n", .{});
            assert(sliceContainsSlice(stringPool.items, str));
            const index = str.ptr - stringPool.items.ptr;

            try stringPool.ensureUnusedCapacity(str.len + InputExtraBytes);
            try stringEnds.ensureUnusedCapacity(1);

            // the slice needs to happen *after* the growing
            break :b stringPool.items[index..][0..str.len];
        } else {
            std.debug.print("inserting from outside\n", .{});
            try stringPool.ensureUnusedCapacity(str.len + InputExtraBytes);
            try stringEnds.ensureUnusedCapacity(1);

            break :b str;
        }
    };

    errdefer comptime unreachable; // no partially writter string on OOM

    stringEnds.appendAssumeCapacity(Entry.init(stringPool.items.len + str.len));
    stringPool.appendSliceAssumeCapacity(maybeRelocatedStr);
    stringPool.appendNTimesAssumeCapacity(undefined, InputExtraBytes);
}

pub fn deleteString(index: Index) void {
    stringEnds.items[index].deleted = true;
    deletedBytes += getString(index).len;
}

/// Invalidates all indexes
pub fn maybeRepack() void {
    const total = stringPool.items.len;
    if (deletedBytes > 4096 and deletedBytes > total / 2) {
        repack();
    }
}

fn repack() void {
    // end of copied-over inputs
    var poolWriteHead: usize = 0;
    var endsWriteHead: usize = 0;

    for (0..stringEnds.items.len) |i| {
        const start = if (i == 0) 0 else stringEnds.items[i - 1].v;
        const one_past_end = stringEnds.items[i].v;
        const str = stringPool.items[start..one_past_end];
        const dest = stringPool.items[poolWriteHead..][0..str.len];

        if (stringEnds.items[i].deleted) {
            continue;
        }

        if (str.ptr != dest.ptr) {
            std.mem.copyForwards(u8, dest, str);
            stringEnds.items[endsWriteHead] = Entry.init(poolWriteHead + str.len);
        }
        poolWriteHead += str.len;
        endsWriteHead += 1;
    }

    stringEnds.items.len = endsWriteHead;
    stringPool.items.len = poolWriteHead;
}

/// Number of strings stored
pub fn len() Index {
    return @intCast(stringEnds.items.len);
}

/// Returns string under this index. indexes are not stable
pub fn getString(index: Index) []u8 {
    const start = if (index == 0) 0 else stringEnds.items[index - 1].v;
    const one_past_end = stringEnds.items[index].v;
    return stringPool.items[start..one_past_end];
}

/// Just for testing
fn reset() void {
    stringPool.items.len = 0;
    stringEnds.items.len = 0;
    deletedBytes = 0;
}

const t = std.testing;

test {
    defer reset();

    try insertString("hello");
    try insertString("test");
    try insertString("123");

    try t.expectEqualSlices(u8, "hello", getString(0));
    try t.expectEqualSlices(u8, "test", getString(1));
    try t.expectEqualSlices(u8, "123", getString(2));
    try t.expectEqualSlices(u8, "hellotest123", stringPool.items);
    try t.expectEqual(3, len());

    deleteString(1);
    repack();

    try t.expectEqualSlices(u8, "hello", getString(0));
    try t.expectEqualSlices(u8, "123", getString(1));
    try t.expectEqualSlices(u8, "hello123", stringPool.items);
    try t.expectEqual(2, len());

    deleteString(0);
    repack();

    try t.expectEqualSlices(u8, "123", getString(0));
    try t.expectEqualSlices(u8, "123", stringPool.items);
    try t.expectEqual(1, len());

    deleteString(0);
    repack();

    try t.expectEqualSlices(u8, "", stringPool.items);
    try t.expectEqual(0, len());
}
