const std = @import("std");
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

const Entry = packed struct {
    deleted: bool,
    v: u31, // total 2GiB of input data should be enough
    fn init(v: usize) Entry {
        return .{
            .v = std.math.cast(u31, v) orelse @panic("fuzzer input address space exhaused"),
            .deleted = false,
        };
    }
};

/// Bookkeeping of the ends of stored strings
/// Given index i, string i starts at stringEnds[i-1].v and first byte outside
/// the string is at stringEnds[i].v
var stringEnds = std.ArrayList(Entry).init(std.heap.page_allocator);

var stringPool = std.ArrayList(u8).init(std.heap.page_allocator);

/// Sum of lengths of all deleted strings. Used to decide if we want to repack
/// everything.
var deletedBytes: usize = 0;

/// Given string is copied
pub fn insertString(str: []const u8) error{OutOfMemory}!void {
    try stringPool.ensureUnusedCapacity(str.len);
    try stringEnds.ensureUnusedCapacity(1);

    errdefer comptime unreachable; // no partially writter string on OOM

    stringPool.appendSliceAssumeCapacity(str);
    stringEnds.appendAssumeCapacity(Entry.init(stringPool.items.len));
}

pub fn deleteString(index: u31) void {
    deleteStringNoRepack(index);
    maybeRepack();
}

fn deleteStringNoRepack(index: u31) void {
    stringEnds.items[index].deleted = true;
    deletedBytes += getString(index).len;
}

fn maybeRepack() void {
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
pub fn len() u31 {
    return @intCast(stringEnds.items.len);
}

/// Returns string under this index. indexes are not stable
pub fn getString(index: u31) []u8 {
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

    deleteStringNoRepack(1);
    repack();

    try t.expectEqualSlices(u8, "hello", getString(0));
    try t.expectEqualSlices(u8, "123", getString(1));
    try t.expectEqualSlices(u8, "hello123", stringPool.items);
    try t.expectEqual(2, len());

    deleteStringNoRepack(0);
    repack();

    try t.expectEqualSlices(u8, "123", getString(0));
    try t.expectEqualSlices(u8, "123", stringPool.items);
    try t.expectEqual(1, len());

    deleteStringNoRepack(0);
    repack();

    try t.expectEqualSlices(u8, "", stringPool.items);
    try t.expectEqual(0, len());
}
