const std = @import("std");

pub fn sort(a: []u32) void {
    std.mem.sort(u32, a, void{}, std.sort.asc(u32));
}

pub fn uniq(a: []u32) []u32 {
    var write: usize = 0;

    if (a.len == 0) return a;

    var last: u32 = a[0];
    a[write] = last;
    write += 1;

    for (a[1..]) |v| {
        if (v != last) {
            a[write] = v;
            write += 1;
            last = v;
        }
    }

    return a[0..write];
}

test uniq {
    var data: [9]u32 = (&[_]u32{ 0, 0, 1, 2, 2, 2, 3, 4, 4 }).*;
    const cropped = uniq(&data);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2, 3, 4 }, cropped);
}

pub const CmpResult = struct { only_a: u32, only_b: u32, both: u32 };

pub fn cmp(a: []const u32, b: []const u32) CmpResult {
    var ai: u32 = 0;
    var bi: u32 = 0;

    var only_a: u32 = 0;
    var only_b: u32 = 0;
    var both: u32 = 0;

    while (true) {
        if (ai == a.len) {
            only_b += @intCast(b[bi..].len);
            break;
        } else if (bi == b.len) {
            only_a += @intCast(a[ai..].len);
            break;
        }

        const i = a[ai];
        const j = b[bi];

        if (i < j) {
            only_a += 1;
            ai += 1;
        } else if (i > j) {
            only_b += 1;
            bi += 1;
        } else {
            both += 1;
            ai += 1;
            bi += 1;
        }
    }

    return .{
        .only_a = only_a,
        .only_b = only_b,
        .both = both,
    };
}

test cmp {
    const e = std.testing.expectEqual;
    const R = CmpResult;
    try e(R{ .only_a = 0, .only_b = 0, .both = 0 }, cmp(&.{}, &.{}));
    try e(R{ .only_a = 1, .only_b = 0, .both = 0 }, cmp(&.{1}, &.{}));
    try e(R{ .only_a = 0, .only_b = 1, .both = 0 }, cmp(&.{}, &.{1}));
    try e(R{ .only_a = 0, .only_b = 0, .both = 1 }, cmp(&.{1}, &.{1}));
    try e(R{ .only_a = 1, .only_b = 1, .both = 0 }, cmp(&.{1}, &.{2}));
    try e(R{ .only_a = 1, .only_b = 0, .both = 1 }, cmp(&.{ 1, 2 }, &.{1}));
    try e(R{ .only_a = 0, .only_b = 1, .both = 1 }, cmp(&.{1}, &.{ 1, 2 }));
    try e(R{ .only_a = 0, .only_b = 0, .both = 2 }, cmp(&.{ 1, 2 }, &.{ 1, 2 }));
    try e(R{ .only_a = 3, .only_b = 3, .both = 0 }, cmp(&.{ 1, 2, 3 }, &.{ 4, 5, 6 }));
}

pub fn merge(dest: *std.ArrayList(u32), src: []const u32) !void {
    // TODO: can be in O(n) time and O(1) space
    try dest.appendSlice(src);
    sort(dest.items);
    dest.items = uniq(dest.items);
}
