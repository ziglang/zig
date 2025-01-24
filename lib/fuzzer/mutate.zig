//! This file contains implementations of individual mutations we can do on a
//! string and a big function that executes multiple mutations in a sequence.
//!
//! The mutation sequence and individual mutation arguments are generated from
//! a seeded rng. Mutating is completly deterministic. Because of that, we can
//! implement *reverse* mutations that reverse the original mutation given the
//! same seed. We use this to avoid memcpying the input data and instead
//! mutating a single copy in place many times.
//!
//! Note that some mutations delete information (such as the erase bytes one)
//! so we need to have a scratch array where we write deleted information for
//! undoing the mutation later.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

/// Used in tests
const test_data: [128]u8 = blk: {
    var b: [128]u8 = undefined;
    var r: std.Random.DefaultPrng = .init(0);
    r.fill(&b);
    break :blk b;
};

const MutationTag = enum(u8) {
    shuffle_bytes,
    erase_bytes,
    insert_byte,
    insert_repeated_byte,
    change_byte,
    change_bit,
};

// Choice of mutations copied from llvm's libfuzzer
const Mutation = union(MutationTag) {
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

pub fn mutate(str: *ArrayListUnmanaged(u8), seed: u64, scr: *ArrayListUnmanaged(u8), gpa: Allocator) error{OutOfMemory}!void {
    var a = str.toManaged(gpa);
    var b = scr.toManaged(gpa);
    var rng = std.Random.DefaultPrng.init(seed);
    const muts = generateRandomMutationSequence(rng.random());
    try executeMutation(&a, muts, &b);
    str.* = a.moveToUnmanaged();
    scr.* = b.moveToUnmanaged();
}

pub fn mutateReverse(str: *ArrayListUnmanaged(u8), seed: u64, scr: *ArrayListUnmanaged(u8)) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const muts = generateRandomMutationSequence(rng.random());
    executeMutationReverse(str, muts, scr);
}

fn generateRandomMutationSequence(rng: std.Random) MutationSequence {
    var muts: MutationSequence = .{};

    for (0..rng.uintLessThanBiased(usize, muts.capacity())) |_| {
        const r = rng.int(u64);
        const mutation_tag_count = std.meta.tags(MutationTag).len;
        const random_mutation_tag: MutationTag =
            @enumFromInt(rng.int(u32) % mutation_tag_count); // enumValue would be great but it is missing a biased variant
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
            .change_byte => |a| try mutateChangeByte(str.items, scr, a.index, a.byte),
            .change_bit => |a| mutateChangeBit(str.items, a.index, a.bit),
        }
    }
}

fn executeMutationReverse(str: *ArrayListUnmanaged(u8), muts: MutationSequence, scr: *ArrayListUnmanaged(u8)) void {
    const slice = muts.slice();
    for (0..slice.len) |i| {
        const mut = slice[slice.len - i - 1];
        switch (mut) {
            .shuffle_bytes => {},
            .erase_bytes => |a| mutateEraseBytesReverse(str, scr, a.index),
            .insert_byte => |a| mutateInsertByteReverse(str, a.index),
            .insert_repeated_byte => |a| mutateInsertRepeatedByteReverse(str, a.index, a.len),
            .change_byte => |a| mutateChangeByteReverse(str.items, scr, a.index),
            .change_bit => |a| mutateChangeBitReverse(str.items, a.index, a.bit),
        }
    }
}

test "mutate" {
    var scr: ArrayListUnmanaged(u8) = .empty;
    defer scr.deinit(std.testing.allocator);
    var str: ArrayListUnmanaged(u8) = .empty;
    defer str.deinit(std.testing.allocator);
    var rng = std.Random.DefaultPrng.init(0);
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(std.testing.allocator, test_data[0..l]);
        for (0..1000) |_| {
            const seed = rng.next();
            try mutate(&str, seed, &scr, std.testing.allocator);
            mutateReverse(&str, seed, &scr);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}

/// Writes names of the mutations that correspond to this seed. Used to make
/// the log pretty
pub fn writeMutation(seed: u64, writer: anytype) !void {
    var rng = std.Random.DefaultPrng.init(seed);
    const muts = generateRandomMutationSequence(rng.random());
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

fn mutateChangeBit(str: []u8, index: u32, bit: u3) void {
    if (str.len == 0) return;
    const mask = @as(u8, 1) << bit;
    str[index % str.len] ^= mask;
}

fn mutateChangeBitReverse(str: []u8, index: u32, bit: u3) void {
    return mutateChangeBit(str, index, bit);
}

test "mutate change bit" {
    var scr: ArrayListUnmanaged(u8) = .empty;
    defer scr.deinit(std.testing.allocator);
    var str: ArrayListUnmanaged(u8) = .empty;
    defer str.deinit(std.testing.allocator);
    var rng_impl = std.Random.DefaultPrng.init(0);
    const rng = rng_impl.random();
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(std.testing.allocator, test_data[0..l]);
        for (0..1000) |_| {
            const index = rng.int(u32);
            const bit = rng.int(u3);
            mutateChangeBit(str.items, index, bit);
            mutateChangeBitReverse(str.items, index, bit);
            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}

fn mutateChangeByte(str: []u8, scr: *ArrayList(u8), index: u32, byte: u8) !void {
    if (str.len == 0) return;
    const target = &str[index % str.len];
    try scr.append(target.*);
    target.* = byte;
}

fn mutateChangeByteReverse(str: []u8, scr: *ArrayListUnmanaged(u8), index: u32) void {
    if (str.len == 0) return;
    str[index % str.len] = scr.pop();
}

test "mutate change byte" {
    var scr: ArrayList(u8) = .init(std.testing.allocator);
    defer scr.deinit();
    var str: ArrayList(u8) = .init(std.testing.allocator);
    defer str.deinit();
    var rng_impl = std.Random.DefaultPrng.init(0);
    const rng = rng_impl.random();
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index = rng.int(u32);
            const byte = rng.int(u8);

            try mutateChangeByte(str.items, &scr, index, byte);

            var u = scr.moveToUnmanaged();
            mutateChangeByteReverse(str.items, &u, index);
            scr = u.toManaged(std.testing.allocator);

            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}

fn mutateInsertRepeatedByte(str: *ArrayList(u8), index: u32, len_: u8, byte: u8) !void {
    const len = @min(24, @max(1, len_)); // arbitrary. good idea to tune
    const str_len = str.items.len;
    const insert_index = index % (str_len + 1);

    const slice = try str.addManyAt(insert_index, len);

    @memset(slice, byte);
}

fn mutateInsertRepeatedByteReverse(str: *ArrayListUnmanaged(u8), index: u32, len_: u8) void {
    const len = @min(24, @max(1, len_));
    const str_len = str.items.len - len;
    const insert_index = index % (str_len + 1);

    // TODO: add this operation to ArrayList
    const src = str.items[insert_index + len ..];
    str.items.len -= len;
    const dest = str.items[insert_index..];
    std.mem.copyForwards(u8, dest, src);
}

test "mutate insert repeated byte" {
    var str: ArrayList(u8) = .init(std.testing.allocator);
    defer str.deinit();
    var rng_impl = std.Random.DefaultPrng.init(0);
    const rng = rng_impl.random();
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index = rng.int(u32);
            const byte = rng.int(u8);
            const len = rng.int(u8);
            try mutateInsertRepeatedByte(&str, index, len, byte);

            var u = str.moveToUnmanaged();
            mutateInsertRepeatedByteReverse(&u, index, len);
            str = u.toManaged(std.testing.allocator);

            try std.testing.expectEqualStrings(test_data[0..l], str.items);
        }
    }
}

fn mutateInsertByte(str: *ArrayList(u8), index: u32, byte: u8) !void {
    return mutateInsertRepeatedByte(str, index, 1, byte);
}

fn mutateInsertByteReverse(str: *ArrayListUnmanaged(u8), index: u32) void {
    return mutateInsertRepeatedByteReverse(str, index, 1);
}

test "mutate insert byte" {
    var scr: ArrayListUnmanaged(u8) = .empty;
    defer scr.deinit(std.testing.allocator);
    var str: ArrayList(u8) = .init(std.testing.allocator);
    defer str.deinit();
    var rng_impl = std.Random.DefaultPrng.init(0);
    const rng = rng_impl.random();
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index = rng.int(u32);
            const byte = rng.int(u8);
            try mutateInsertByte(&str, index, byte);

            var u = str.moveToUnmanaged();
            mutateInsertByteReverse(&u, index);
            str = u.toManaged(std.testing.allocator);

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

    // TODO: add this operation to ArrayList

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

fn mutateEraseBytesReverse(str: *ArrayListUnmanaged(u8), scr: *ArrayListUnmanaged(u8), index: u32) void {
    const len = scr.pop();
    if (len == 0) return;
    const erase_index = index % (str.items.len + 1);

    const dest = str.addManyAtAssumeCapacity(erase_index, len);
    const src = scr.items[scr.items.len - len ..];

    // copy in the erased bytes
    @memcpy(dest, src);

    scr.items.len -= len;
}

test "mutate erase bytes" {
    var scr: ArrayList(u8) = .init(std.testing.allocator);
    defer scr.deinit();
    var str: ArrayList(u8) = .init(std.testing.allocator);
    defer str.deinit();
    var rng_impl = std.Random.DefaultPrng.init(0);
    const rng = rng_impl.random();
    for (0..test_data.len) |l| {
        str.clearRetainingCapacity();
        try str.appendSlice(test_data[0..l]);
        for (0..1000) |_| {
            const index = rng.int(u32);
            const len = rng.int(u8);
            try mutateEraseBytes(&str, &scr, index, len);

            var scru = scr.moveToUnmanaged();
            var stru = str.moveToUnmanaged();

            mutateEraseBytesReverse(&stru, &scru, index);
            scr = scru.toManaged(std.testing.allocator);
            str = stru.toManaged(std.testing.allocator);

            try std.testing.expectEqualStrings(test_data[0..l], str.items);
            try std.testing.expectEqual(0, scr.items.len);
        }
    }
}
