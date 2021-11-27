const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

test "for loop with pointer elem var" {
    const source = "abcdefg";
    var target: [source.len]u8 = undefined;
    mem.copy(u8, target[0..], source);
    mangleString(target[0..]);
    try expect(mem.eql(u8, &target, "bcdefgh"));

    for (source) |*c, i| {
        _ = i;
        try expect(@TypeOf(c) == *const u8);
    }
    for (target) |*c, i| {
        _ = i;
        try expect(@TypeOf(c) == *u8);
    }
}

fn mangleString(s: []u8) void {
    for (s) |*c| {
        c.* += 1;
    }
}

test "2 break statements and an else" {
    const S = struct {
        fn entry(t: bool, f: bool) !void {
            var buf: [10]u8 = undefined;
            var ok = false;
            ok = for (buf) |item| {
                _ = item;
                if (f) break false;
                if (t) break true;
            } else false;
            try expect(ok);
        }
    };
    try S.entry(true, false);
    comptime try S.entry(true, false);
}

test "for copies its payload" {
    const S = struct {
        fn doTheTest() !void {
            var x = [_]usize{ 1, 2, 3 };
            for (x) |value, i| {
                // Modify the original array
                x[i] += 99;
                try expectEqual(value, i + 1);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "for on slice with allowzero ptr" {
    const S = struct {
        fn doTheTest(slice: []const u8) !void {
            var ptr = @ptrCast([*]allowzero const u8, slice.ptr)[0..slice.len];
            for (ptr) |x, i| try expect(x == i + 1);
            for (ptr) |*x, i| try expect(x.* == i + 1);
        }
    };
    try S.doTheTest(&[_]u8{ 1, 2, 3, 4 });
    comptime try S.doTheTest(&[_]u8{ 1, 2, 3, 4 });
}
