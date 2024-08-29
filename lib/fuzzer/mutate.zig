// This file contains implementations of individual mutations we can do on a
// string and a big function that executes multiple of mutations in a sequence.
//
// The mutation sequence and individual mutation arguments are generated from a
// seeded rng. Mutating is completly deterministic. Because of that, we can
// implement *reverse* mutations that reverse the original mutation given the
// same seed. We use this to avoid memcpying the input data and instead
// mutating a single copy in place many times.
//
// Note that some mutations delete information (such as the erase bytes one) so
// we need to have a scratch array where we write deleted information for
// undoing the mutation later.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Rng = std.Random.DefaultPrng;
const ArrayList = std.ArrayList;

const test_data: [128]u8 = blk: {
    var b: [128]u8 = undefined;
    var r = std.Random.DefaultPrng.init(69);
    r.fill(&b);
    break :blk b;
};

// Choice of mutations copied from llvm's libfuzzer
const Mutation = union(enum) {
    shuffle_bytes: struct { seed: u64 },
    erase_bytes: struct { index: u32, len: u8 },
    insert_byte: struct { index: u32, byte: u8 },
    insert_repeated_byte: struct { index: u32, len: u8, byte: u8 },
    change_byte: struct { index: u32, byte: u8 },
    change_bit: struct { index: u32, bit: u3 },

    // TODO:
    // copy_part: void,
    // add_word_from_manual_dictionary: void,
    // add_word_from_torc: void, // Table of Recently Compared data
    // add_word_from_persistent_auto_dictionary: void
    // change_ascii_integer: void,
    // change_binary_integer: void,
};

const MutationSequence = std.BoundedArray(Mutation, 8);

pub fn mutate(str: *ArrayList(u8), seed: u64, scr: *ArrayList(u8)) error{OutOfMemory}!void {
    const muts = generateRandomMutationSequence(Rng.init(seed));
    try executeMutation(str, muts, scr);
}

pub fn mutateReverse(str: *ArrayList(u8), seed: u64, scr: *ArrayList(u8)) void {
    const muts = generateRandomMutationSequence(Rng.init(seed));
    executeMutationReverse(str, muts, scr);
}

fn generateRandomMutationSequence(rand_: Rng) MutationSequence {
    var rand = rand_;
    var muts: MutationSequence = .{};
    for (0..rand.next() % muts.capacity()) |_| {
        const r = rand.next();
        const MutationTag = std.meta.Tag(Mutation);
        const mutation_tag_count = std.meta.tags(MutationTag).len;
        const random_mutation_tag: MutationTag = @enumFromInt(rand.next() % mutation_tag_count);
        muts.appendAssumeCapacity(switch (random_mutation_tag) {
            .shuffle_bytes => .{ .shuffle_bytes = .{ .seed = r } },
            .erase_bytes => .{ .erase_bytes = .{ .index = @intCast(r >> 32), .len = @truncate(r) } },
            .insert_byte => .{ .insert_byte = .{ .index = @intCast(r >> 32), .byte = @truncate(r) } },
            .insert_repeated_byte => .{ .insert_repeated_byte = .{ .index = @intCast(r >> 32), .len = @truncate(r >> 8), .byte = @truncate(r) } },
            .change_byte => .{ .change_byte = .{ .index = @intCast(r >> 32), .byte = @truncate(r) } },
            .change_bit => .{ .change_bit = .{ .index = @intCast(r >> 32), .bit = @truncate(r) } },
        });
    }
    return muts;
}

fn executeMutation(str: *ArrayList(u8), muts: MutationSequence, scr: *ArrayList(u8)) !void {
    for (muts.slice()) |mut| {
        switch (mut) {
            .shuffle_bytes => {},
            .erase_bytes => |a| try mutateEraseBytes(str, scr, a.index, a.len),
            .insert_byte => |a| try mutateInsertByte(str, a.index, a.byte),
            .insert_repeated_byte => |a| try mutateInsertRepeatedByte(str, a.index, a.len, a.byte),
            .change_byte => |a| try mutateChangeByte(str, scr, a.index, a.byte),
            .change_bit => |a| mutateChangeBit(str, a.index, a.bit),
        }
    }
}

fn executeMutationReverse(str: *ArrayList(u8), muts: MutationSequence, scr: *ArrayList(u8)) void {
    const slice = muts.slice();
    for (0..slice.len) |i| {
        const mut = slice[slice.len - i - 1];
        switch (mut) {
            .shuffle_bytes => {},
            .erase_bytes => |a| mutateEraseBytesReverse(str, scr, a.index),
            .insert_byte => |a| mutateInsertByteReverse(str, a.index),
            .insert_repeated_byte => |a| mutateInsertRepeatedByteReverse(str, a.index, a.len),
            .change_byte => |a| mutateChangeByteReverse(str, scr, a.index),
            .change_bit => |a| mutateChangeBitReverse(str, a.index, a.bit),
        }
    }
}

test "mutate" {
    var scr = ArrayList(u8).init(std.testing.allocator);
    defer scr.deinit();
    var str = ArrayList(u8).init(std.testing.allocator);
    defer str.deinit();
    var rng = Rng.init(0);
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const seed = rng.next();
            try mutate(&str, seed, &scr);
            mutateReverse(&str, seed, &scr);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}

/// Writes names of the mutations that correspond to this seed. Used to make
/// the log pretty
pub fn writeMutation(seed: u64, writer: anytype) !void {
    const muts = generateRandomMutationSequence(Rng.init(seed));
    for (muts.slice(), 0..) |mut, i| {
        if (i != 0) try writer.writeAll(", ");
        try writer.writeAll(switch (mut) {
            .shuffle_bytes => "Shuffle",
            .erase_bytes => "DelBytes",
            .insert_byte => "InsByte",
            .insert_repeated_byte => "InsBytes",
            .change_byte => "ChByte",
            .change_bit => "ChBit",
        });
    }
}

fn mutateChangeBit(str: *ArrayList(u8), index: u32, bit: u3) void {
    if (str.items.len == 0) return;
    const mask = @as(u8, 1) << bit;
    str.items[index % str.items.len] ^= mask;
}

fn mutateChangeBitReverse(str: *ArrayList(u8), index: u32, bit: u3) void {
    return mutateChangeBit(str, index, bit);
}

test "mutate change bit" {
    var scr = ArrayList(u8).init(std.testing.allocator);
    var str = ArrayList(u8).init(std.testing.allocator);
    defer str.deinit();
    defer scr.deinit();
    var rng = Rng.init(0);
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index: u32 = @truncate(rng.next());
            const bit: u3 = @truncate(rng.next());
            mutateChangeBit(&str, index, bit);
            mutateChangeBitReverse(&str, index, bit);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}

fn mutateChangeByte(str: *ArrayList(u8), scr: *ArrayList(u8), index: u32, byte: u8) !void {
    if (str.items.len == 0) return;
    const target = &str.items[index % str.items.len];
    try scr.append(target.*);
    target.* = byte;
}

fn mutateChangeByteReverse(str: *ArrayList(u8), scr: *ArrayList(u8), index: u32) void {
    if (str.items.len == 0) return;
    str.items[index % str.items.len] = scr.pop();
}

test "mutate change byte" {
    var scr = ArrayList(u8).init(std.testing.allocator);
    defer scr.deinit();
    var str = ArrayList(u8).init(std.testing.allocator);
    defer str.deinit();
    var rng = Rng.init(0);
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index: u32 = @truncate(rng.next());
            const byte: u8 = @truncate(rng.next());
            try mutateChangeByte(&str, &scr, index, byte);
            mutateChangeByteReverse(&str, &scr, index);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}

fn mutateInsertRepeatedByte(str: *ArrayList(u8), index: u32, len_: u8, byte: u8) !void {
    const len = @min(24, @max(1, len_));
    const str_len = str.items.len;
    const insert_index = index % (str_len + 1);

    try str.ensureUnusedCapacity(len);

    const src = str.items[insert_index..];
    str.items.len += len;
    const dest = str.items[insert_index + len ..];
    std.mem.copyBackwards(u8, dest, src);
    @memset(str.items[insert_index..][0..len], byte);
}

fn mutateInsertRepeatedByteReverse(str: *ArrayList(u8), index: u32, len_: u8) void {
    const len = @min(24, @max(1, len_));
    const str_len = str.items.len - len;
    const insert_index = index % (str_len + 1);

    const src = str.items[insert_index + len ..];
    str.items.len -= len;
    const dest = str.items[insert_index..];
    std.mem.copyForwards(u8, dest, src);
}

test "mutate insert repeated byte" {
    var str = ArrayList(u8).init(std.testing.allocator);
    defer str.deinit();
    var rng = Rng.init(0);
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index: u32 = @truncate(rng.next());
            const byte: u8 = @truncate(rng.next());
            const len: u8 = @truncate(rng.next());
            try mutateInsertRepeatedByte(&str, index, len, byte);
            mutateInsertRepeatedByteReverse(&str, index, len);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
        }
    }
}

fn mutateInsertByte(str: *ArrayList(u8), index: u32, byte: u8) !void {
    return mutateInsertRepeatedByte(str, index, 1, byte);
}

fn mutateInsertByteReverse(str: *ArrayList(u8), index: u32) void {
    return mutateInsertRepeatedByteReverse(str, index, 1);
}

test "mutate insert byte" {
    var scr = ArrayList(u8).init(std.testing.allocator);
    defer scr.deinit();
    var str = ArrayList(u8).init(std.testing.allocator);
    defer str.deinit();
    var rng = Rng.init(0);
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index: u32 = @truncate(rng.next());
            const byte: u8 = @truncate(rng.next());
            try mutateInsertByte(&str, index, byte);
            mutateInsertByteReverse(&str, index);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}

fn mutateEraseBytes(str: *ArrayList(u8), scr: *ArrayList(u8), index: u32, len_: u8) !void {
    const upper_bound = @min(str.items.len / 3, 32);
    const len = @min(upper_bound, len_);
    if (len == 0) {
        return scr.append(len);
    }
    const erase_index = index % (str.items.len - len + 1);

    // copy out the erased bytes
    const cut = str.items[erase_index..][0..len];
    try scr.appendSlice(cut);

    // shift down
    const src = str.items[erase_index + len ..];
    const dest = str.items[erase_index..];
    std.mem.copyForwards(u8, dest, src);

    try scr.append(len);
    str.items.len -= len;
}

fn mutateEraseBytesReverse(str: *ArrayList(u8), scr: *ArrayList(u8), index: u32) void {
    const len = scr.pop();
    if (len == 0) return;
    const erase_index = index % (str.items.len + 1);

    { // shift up
        const src = str.items[erase_index..];
        str.items.len += len;
        const dest = str.items[erase_index + len ..];
        std.mem.copyBackwards(u8, dest, src);
    }

    { // copy in the erased bytes
        const dest = str.items[erase_index..][0..len];
        const src = scr.items[scr.items.len - len ..];
        @memcpy(dest, src);
    }

    scr.items.len -= len;
}

test "mutate erase bytes" {
    var scr = ArrayList(u8).init(std.testing.allocator);
    defer scr.deinit();
    var str = ArrayList(u8).init(std.testing.allocator);
    defer str.deinit();
    var rng = Rng.init(0);
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index: u32 = @truncate(rng.next());
            const len: u8 = @truncate(rng.next());
            try mutateEraseBytes(&str, &scr, index, len);
            mutateEraseBytesReverse(&str, &scr, index);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}
