const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

test "continue in for loop" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime testBreakOuter();
}

fn testBreakOuter() !void {
    const array = "aoeu";
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
    try comptime testContinueOuter();
}

fn testContinueOuter() !void {
    const array = "aoeu";
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
    for ([_]void{}, 0..) |_, i| {
        _ = i;
        for ([_]void{}, 0..) |_, j| {
            _ = j;
            break;
        }
        break;
    }
}

test "basic for loop" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const expected_result = [_]u8{ 9, 8, 7, 6, 0, 1, 2, 3 } ** 3;

    var buffer: [expected_result.len]u8 = undefined;
    var buf_index: usize = 0;

    const array = [_]u8{ 9, 8, 7, 6 };
    for (array) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (array, 0..) |item, index| {
        _ = item;
        buffer[buf_index] = @as(u8, @intCast(index));
        buf_index += 1;
    }
    const array_ptr = &array;
    for (array_ptr) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (array_ptr, 0..) |item, index| {
        _ = item;
        buffer[buf_index] = @as(u8, @intCast(index));
        buf_index += 1;
    }
    const unknown_size: []const u8 = &array;
    for (unknown_size) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (unknown_size, 0..) |_, index| {
        buffer[buf_index] = @as(u8, @intCast(index));
        buf_index += 1;
    }

    try expect(mem.eql(u8, buffer[0..buf_index], &expected_result));
}

test "for with null and T peer types and inferred result location type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime S.doTheTest(&[_]u8{ 1, 2 });
}

test "2 break statements and an else" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn entry(t: bool, f: bool) !void {
            var buf: [10]u8 = undefined;
            var ok = false;
            ok = for (&buf) |*item| {
                _ = item;
                if (f) break false;
                if (t) break true;
            } else false;
            try expect(ok);
        }
    };
    try S.entry(true, false);
    try comptime S.entry(true, false);
}

test "for loop with pointer elem var" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const source = "abcdefg";
    var target: [source.len]u8 = undefined;
    @memcpy(target[0..], source);
    mangleString(target[0..]);
    try expect(mem.eql(u8, &target, "bcdefgh"));

    for (source, 0..) |*c, i| {
        _ = i;
        try expect(@TypeOf(c) == *const u8);
    }
    for (&target, 0..) |*c, i| {
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x = [_]usize{ 1, 2, 3 };
            for (x, 0..) |value, i| {
                // Modify the original array
                x[i] += 99;
                try expect(value == i + 1);
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "for on slice with allowzero ptr" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(slice: []const u8) !void {
            const ptr = @as([*]allowzero const u8, @ptrCast(slice.ptr))[0..slice.len];
            for (ptr, 0..) |x, i| try expect(x == i + 1);
            for (ptr, 0..) |*x, i| try expect(x.* == i + 1);
        }
    };
    try S.doTheTest(&[_]u8{ 1, 2, 3, 4 });
    try comptime S.doTheTest(&[_]u8{ 1, 2, 3, 4 });
}

test "else continue outer for" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var i: usize = 6;
    var buf: [5]u8 = undefined;
    while (true) {
        i -= 1;
        for (buf[i..5]) |_| {
            return;
        } else continue;
    }
}

test "for loop with else branch" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    {
        var x = [_]u32{ 1, 2 };
        _ = &x;
        const q = for (x) |y| {
            if ((y & 1) != 0) continue;
            break y * 2;
        } else @as(u32, 1);
        try expect(q == 4);
    }
    {
        var x = [_]u32{ 1, 2 };
        _ = &x;
        const q = for (x) |y| {
            if ((y & 1) != 0) continue;
            break y * 2;
        } else @panic("");
        try expect(q == 4);
    }
}

test "count over fixed range" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var sum: usize = 0;
    for (0..6) |i| {
        sum += i;
    }

    try expect(sum == 15);
}

test "two counters" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var sum: usize = 0;
    for (0..10, 10..20) |i, j| {
        sum += 1;
        try expect(i + 10 == j);
    }

    try expect(sum == 10);
}

test "1-based counter and ptr to array" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var ok: usize = 0;

    for (1..6, "hello") |i, b| {
        if (i == 1) {
            try expect(b == 'h');
            ok += 1;
        }
        if (i == 2) {
            try expect(b == 'e');
            ok += 1;
        }
        if (i == 3) {
            try expect(b == 'l');
            ok += 1;
        }
        if (i == 4) {
            try expect(b == 'l');
            ok += 1;
        }
        if (i == 5) {
            try expect(b == 'o');
            ok += 1;
        }
    }

    try expect(ok == 5);
}

test "slice and two counters, one is offset and one is runtime" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const slice: []const u8 = "blah";
    var start: usize = 0;
    _ = &start;

    for (slice, start..4, 1..5) |a, b, c| {
        if (a == 'b') {
            try expect(b == 0);
            try expect(c == 1);
        }
        if (a == 'l') {
            try expect(b == 1);
            try expect(c == 2);
        }
        if (a == 'a') {
            try expect(b == 2);
            try expect(c == 3);
        }
        if (a == 'h') {
            try expect(b == 3);
            try expect(c == 4);
        }
    }
}

test "two slices, one captured by-ref" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var buf: [10]u8 = undefined;
    const slice1: []const u8 = "blah";
    const slice2: []u8 = buf[0..4];

    for (slice1, slice2) |a, *b| {
        b.* = a;
    }

    try expect(slice2[0] == 'b');
    try expect(slice2[1] == 'l');
    try expect(slice2[2] == 'a');
    try expect(slice2[3] == 'h');
}

test "raw pointer and slice" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var buf: [10]u8 = undefined;
    const slice: []const u8 = "blah";
    const ptr: [*]u8 = buf[0..4];

    for (ptr, slice) |*a, b| {
        a.* = b;
    }

    try expect(buf[0] == 'b');
    try expect(buf[1] == 'l');
    try expect(buf[2] == 'a');
    try expect(buf[3] == 'h');
}

test "raw pointer and counter" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var buf: [10]u8 = undefined;
    const ptr: [*]u8 = &buf;

    for (ptr, 0..4) |*a, b| {
        a.* = @as(u8, @intCast('A' + b));
    }

    try expect(buf[0] == 'A');
    try expect(buf[1] == 'B');
    try expect(buf[2] == 'C');
    try expect(buf[3] == 'D');
}

test "inline for with slice as the comptime-known" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const comptime_slice = "hello";
    var runtime_i: usize = 3;
    _ = &runtime_i;

    const S = struct {
        var ok: usize = 0;
        fn check(comptime a: u8, b: usize) !void {
            if (a == 'l') {
                try expect(b == 3);
                ok += 1;
            } else if (a == 'o') {
                try expect(b == 4);
                ok += 1;
            } else {
                @compileError("fail");
            }
        }
    };

    inline for (comptime_slice[3..5], runtime_i..5) |a, b| {
        try S.check(a, b);
    }

    try expect(S.ok == 2);
}

test "inline for with counter as the comptime-known" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var runtime_slice = "hello";
    var runtime_i: usize = 3;
    _ = &runtime_i;

    const S = struct {
        var ok: usize = 0;
        fn check(a: u8, comptime b: usize) !void {
            if (b == 3) {
                try expect(a == 'l');
                ok += 1;
            } else if (b == 4) {
                try expect(a == 'o');
                ok += 1;
            } else {
                @compileError("fail");
            }
        }
    };

    inline for (runtime_slice[runtime_i..5], 3..5) |a, b| {
        try S.check(a, b);
    }

    try expect(S.ok == 2);
}

test "inline for on tuple pointer" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct { u32, u32, u32 };
    var s: S = .{ 100, 200, 300 };

    inline for (&s, 0..) |*x, i| {
        x.* = i;
    }

    try expectEqual(S{ 0, 1, 2 }, s);
}

test "ref counter that starts at zero" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    for ([_]usize{ 0, 1, 2 }, 0..) |i, j| {
        try expectEqual(i, j);
        try expectEqual((&i).*, (&j).*);
    }
    inline for (.{ 0, 1, 2 }, 0..) |i, j| {
        try expectEqual(i, j);
        try expectEqual((&i).*, (&j).*);
    }
}

test "inferred alloc ptr of for loop" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    {
        var cond = false;
        _ = &cond;
        const opt = for (0..1) |_| {
            if (cond) break cond;
        } else null;
        try expectEqual(@as(?bool, null), opt);
    }
    {
        var cond = true;
        _ = &cond;
        const opt = for (0..1) |_| {
            if (cond) break cond;
        } else null;
        try expectEqual(@as(?bool, true), opt);
    }
}

test "for loop results in a bool" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try std.testing.expect(for ([1]u8{0}) |x| {
        if (x == 0) break true;
    } else false);
}

test "return from inline for" {
    const S = struct {
        fn do() bool {
            inline for (.{"a"}) |_| {
                if (true) return false;
            }
            return true;
        }
    };
    try std.testing.expect(!S.do());
}
