const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

test "continue in for loop" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const array = [_]i32{ 1, 2, 3, 4, 5 };
    var sum: i32 = 0;
    for (array) |x| {
        sum += x;
        if (x < 3) {
            continue;
        }
        break;
    }
    if (sum != 6) unreachable;
}

test "break from outer for loop" {
    try testBreakOuter();
    comptime try testBreakOuter();
}

fn testBreakOuter() !void {
    var array = "aoeu";
    var count: usize = 0;
    outer: for (array) |_| {
        for (array) |_| {
            count += 1;
            break :outer;
        }
    }
    try expect(count == 1);
}

test "continue outer for loop" {
    try testContinueOuter();
    comptime try testContinueOuter();
}

fn testContinueOuter() !void {
    var array = "aoeu";
    var counter: usize = 0;
    outer: for (array) |_| {
        for (array) |_| {
            counter += 1;
            continue :outer;
        }
    }
    try expect(counter == array.len);
}

test "ignore lval with underscore (for loop)" {
    for ([_]void{}) |_, i| {
        _ = i;
        for ([_]void{}) |_, j| {
            _ = j;
            break;
        }
        break;
    }
}

test "basic for loop" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const expected_result = [_]u8{ 9, 8, 7, 6, 0, 1, 2, 3 } ** 3;

    var buffer: [expected_result.len]u8 = undefined;
    var buf_index: usize = 0;

    const array = [_]u8{ 9, 8, 7, 6 };
    for (array) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (array) |item, index| {
        _ = item;
        buffer[buf_index] = @intCast(u8, index);
        buf_index += 1;
    }
    const array_ptr = &array;
    for (array_ptr) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (array_ptr) |item, index| {
        _ = item;
        buffer[buf_index] = @intCast(u8, index);
        buf_index += 1;
    }
    const unknown_size: []const u8 = &array;
    for (unknown_size) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (unknown_size) |_, index| {
        buffer[buf_index] = @intCast(u8, index);
        buf_index += 1;
    }

    try expect(mem.eql(u8, buffer[0..buf_index], &expected_result));
}

test "for with null and T peer types and inferred result location type" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(slice: []const u8) !void {
            if (for (slice) |item| {
                if (item == 10) {
                    break item;
                }
            } else null) |v| {
                _ = v;
                @panic("fail");
            }
        }
    };
    try S.doTheTest(&[_]u8{ 1, 2 });
    comptime try S.doTheTest(&[_]u8{ 1, 2 });
}

test "2 break statements and an else" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

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

test "for loop with pointer elem var" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

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

test "for copies its payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x = [_]usize{ 1, 2, 3 };
            for (x) |value, i| {
                // Modify the original array
                x[i] += 99;
                try expect(value == i + 1);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "for on slice with allowzero ptr" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

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

test "else continue outer for" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var i: usize = 6;
    var buf: [5]u8 = undefined;
    while (true) {
        i -= 1;
        for (buf[i..5]) |_| {
            return;
        } else continue;
    }
}
