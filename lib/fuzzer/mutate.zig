// We pick a random input, mutate it, run it, maybe save because it is good and
// then we undo the mutation to get the original input.
//
// Data is copied only when we decide that the mutation was good. Otherwise the
// entire process is using the same string.
//
// There is a scratch space that may hold some aux data for the undo at the
// end.
//
// TODO: This design disallows mutations that grow the string a lot. For a
// mutation to grow the string, it needs place to grow into but the input pool
// allocates strings densly one after another. We spend couple of bytes at the
// end of each string in inputpool for this purpose but it is very limited.
//
// If this proves to be a problem, we can copy the string out into a large
// buffer and mutate-grow it there.
//
// It might be good that the fuzzer has to explore short inputs extensively and
// the grow is limited.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Rng = std.Random.DefaultPrng;
const ArrayList = std.ArrayList;

// Mutation list copied from llvm's libfuzzer
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

pub fn mutate(str: []u8, cap: usize, seed: u64, scratch: *ArrayList(u8)) ![]u8 {
    const muts = generateRandomMutationSequence(Rng.init(seed));
    return try executeMutation(str, cap, muts, scratch);
}

pub fn mutateReverse(str: []u8, seed: u64, scratch: *ArrayList(u8)) []u8 {
    const muts = generateRandomMutationSequence(Rng.init(seed));
    return executeMutationReverse(str, muts, scratch);
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

fn executeMutation(str_: []u8, cap: usize, muts: MutationSequence, scr: *ArrayList(u8)) ![]u8 {
    var str = str_;
    for (muts.slice()) |mut| {
        str = switch (mut) {
            .shuffle_bytes => str,
            .erase_bytes => |a| try mutateEraseBytes(str, scr, a.index, a.len),
            .insert_byte => |a| try mutateInsertByte(str, cap, scr, a.index, a.byte),
            .insert_repeated_byte => |a| try mutateInsertRepeatedByte(str, cap, scr, a.index, a.len, a.byte),
            .change_byte => |a| try mutateChangeByte(str, scr, a.index, a.byte),
            .change_bit => |a| mutateChangeBit(str, a.index, a.bit),
        };
    }
    return str;
}

fn executeMutationReverse(str_: []u8, muts: MutationSequence, scr: *ArrayList(u8)) []u8 {
    var str = str_;
    const slice = muts.slice();
    for (0..slice.len) |i| {
        const mut = slice[slice.len - i - 1];
        str = switch (mut) {
            .shuffle_bytes => str,
            .erase_bytes => |a| mutateEraseBytesReverse(str, scr, a.index),
            .insert_byte => |a| mutateInsertByteReverse(str, scr, a.index),
            .insert_repeated_byte => |a| mutateInsertRepeatedByteReverse(str, scr, a.index, a.len),
            .change_byte => |a| mutateChangeByteReverse(str, scr, a.index),
            .change_bit => |a| mutateChangeBitReverse(str, a.index, a.bit),
        };
    }
    return str;
}

test "mutate" {
    var str = "fhasjkrhuepqviwpvbybch<D-,>yreoqvyrbvbyr0yvrbzlyc13748ff10 cb1 7cbru".*;
    var scratch = ArrayList(u8).init(std.testing.allocator);
    defer scratch.deinit();

    var rng = Rng.init(0);
    for (0..100) |_| {
        const seed = rng.next();
        const str2 = try mutate(&str, str.len, seed, &scratch);
        const str3 = mutateReverse(str2, seed, &scratch);
        try std.testing.expectEqualStrings(&str, str3);
        try std.testing.expectEqual(0, scratch.items.len);
    }
}

fn mutateChangeBit(str: []u8, index: u32, bit: u3) []u8 {
    const mask = @as(u8, 1) << bit;
    str[index % str.len] ^= mask;
    return str;
}

fn mutateChangeBitReverse(str: []u8, index: u32, bit: u3) []u8 {
    return mutateChangeBit(str, index, bit);
}

test "mutate change bit" {
    var str = "fhasjkrhuepqviwpvbybch<D-,>yreoqvyrbvbyr0yvrbzlyc13748ff10 cb1 7cbru".*;
    var scratch = ArrayList(u8).init(std.testing.allocator);
    defer scratch.deinit();

    var rng = Rng.init(0);
    for (0..100) |_| {
        const index: u32 = @truncate(rng.next());
        const bit: u3 = @truncate(rng.next());
        const str2 = mutateChangeBit(&str, index, bit);
        const str3 = mutateChangeBitReverse(str2, index, bit);
        try std.testing.expectEqualStrings(&str, str3);
        try std.testing.expectEqual(0, scratch.items.len);
    }
}

fn mutateChangeByte(str: []u8, scr: *ArrayList(u8), index: u32, byte: u8) ![]u8 {
    const target = &str[index % str.len];
    try scr.append(target.*);
    target.* = byte;
    return str;
}

fn mutateChangeByteReverse(str: []u8, scr: *ArrayList(u8), index: u32) []u8 {
    str[index % str.len] = scr.pop();
    return str;
}

test "mutate change byte" {
    var str = "fhasjkrhuepqviwpvbybch<D-,>yreoqvyrbvbyr0yvrbzlyc13748ff10 cb1 7cbru".*;
    var scratch = ArrayList(u8).init(std.testing.allocator);
    defer scratch.deinit();

    var rng = Rng.init(0);
    for (0..100) |_| {
        const index: u32 = @truncate(rng.next());
        const byte: u8 = @truncate(rng.next());
        const str2 = try mutateChangeByte(&str, &scratch, index, byte);
        const str3 = mutateChangeByteReverse(str2, &scratch, index);
        try std.testing.expectEqualStrings(&str, str3);
        try std.testing.expectEqual(0, scratch.items.len);
    }
}

fn mutateInsertRepeatedByte(str: []u8, cap: usize, scr: *ArrayList(u8), index: u32, len: u8, byte: u8) ![]u8 {
    if (str.len + len > cap) {
        try scr.append(0);
        return str;
    }
    try scr.append(1);

    var new_str = str;
    new_str.len += len;

    const insert_index = index % str.len;
    std.mem.copyForwards(u8, new_str[insert_index + len ..], str[insert_index..]);
    new_str[insert_index] = byte;
    return new_str;
}

fn mutateInsertRepeatedByteReverse(str: []u8, scr: *ArrayList(u8), index: u32, len: u8) []u8 {
    if (scr.pop() == 0) {
        return str;
    }
    const new_str = str[0 .. str.len - len];

    const insert_index = index % new_str.len;

    std.mem.copyBackwards(u8, new_str[insert_index..], str[insert_index + len ..]);

    return new_str;
}

test "mutate insert repeated byte" {
    var str = "fhasjkrhuepqviwpvbybch<D-,>yreoqvyrbvbyr0yvrbzlyc13748ff10 cb1 7cbru".*;
    var scratch = ArrayList(u8).init(std.testing.allocator);
    defer scratch.deinit();

    var rng = Rng.init(0);
    for (0..100) |_| {
        const index: u32 = @truncate(rng.next());
        const byte: u8 = @truncate(rng.next());
        const len: u8 = @truncate(rng.next());
        const str2 = try mutateInsertRepeatedByte(&str, str.len, &scratch, index, len, byte);
        const str3 = mutateInsertRepeatedByteReverse(str2, &scratch, index, len);
        try std.testing.expectEqualStrings(&str, str3);
        try std.testing.expectEqual(0, scratch.items.len);
    }
}

fn mutateInsertByte(str: []u8, cap: usize, scr: *ArrayList(u8), index: u32, byte: u8) ![]u8 {
    return mutateInsertRepeatedByte(str, cap, scr, index, 1, byte);
}

fn mutateInsertByteReverse(str: []u8, scr: *ArrayList(u8), index: u32) []u8 {
    return mutateInsertRepeatedByteReverse(str, scr, index, 1);
}

test "mutate insert byte" {
    var str = "fhasjkrhuepqviwpvbybch<D-,>yreoqvyrbvbyr0yvrbzlyc13748ff10 cb1 7cbru".*;
    var scratch = ArrayList(u8).init(std.testing.allocator);
    defer scratch.deinit();

    var rng = Rng.init(0);
    for (0..100) |_| {
        const index: u32 = @truncate(rng.next());
        const byte: u8 = @truncate(rng.next());
        const str2 = try mutateInsertByte(&str, str.len, &scratch, index, byte);
        const str3 = mutateInsertByteReverse(str2, &scratch, index);
        try std.testing.expectEqualStrings(&str, str3);
        try std.testing.expectEqual(0, scratch.items.len);
    }
}

fn mutateEraseBytes(str: []u8, scratch: *ArrayList(u8), index: u32, len_: u8) ![]u8 {
    const len = @min(str.len / 3, len_);
    const insert_index = index % (str.len - len);

    const cut = str[insert_index..][0..len];
    const after_cut = str[insert_index + len ..];
    try scratch.appendSlice(cut);
    std.mem.copyForwards(u8, str[insert_index..], after_cut);
    try scratch.append(len);

    return str[0 .. str.len - len];
}

fn mutateEraseBytesReverse(str_: []u8, scratch: *ArrayList(u8), index: u32) []u8 {
    var str = str_;
    const len = scratch.pop();

    const insert_index = index % str.len;

    var src = str[insert_index..];
    str.len += len;
    std.mem.copyBackwards(u8, str[len..], src);
    src.len += len;

    const scratch_slice = scratch.items[scratch.items.len - len ..];
    @memcpy(src[0..len], scratch_slice);
    scratch.items.len -= len;

    return str;
}

test "mutate erase bytes" {
    var str = "fhasjkrhuepqviwpvbybch<D-,>yreoqvyrbvbyr0yvrbzlyc13748ff10 cb1 7cbru".*;
    var scratch = ArrayList(u8).init(std.testing.allocator);
    defer scratch.deinit();

    var rng = Rng.init(0);
    for (0..100) |_| {
        const index: u32 = @truncate(rng.next());
        const len: u8 = @truncate(rng.next());
        const str2 = try mutateEraseBytes(&str, &scratch, index, len);
        const str3 = mutateEraseBytesReverse(str2, &scratch, index);
        try std.testing.expectEqualStrings(&str, str3);
        try std.testing.expectEqual(0, scratch.items.len);
    }
}
