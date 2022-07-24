const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "break and continue inside loop inside defer expression" {
    testBreakContInDefer(10);
    comptime testBreakContInDefer(10);
}

fn testBreakContInDefer(x: usize) void {
    defer {
        var i: usize = 0;
        while (i < x) : (i += 1) {
            if (i < 5) continue;
            if (i == 5) break;
        }
        expect(i == 5) catch @panic("test failure");
    }
}

test "defer and labeled break" {
    var i = @as(usize, 0);

    blk: {
        defer i += 1;
        break :blk;
    }

    try expect(i == 1);
}

test "errdefer does not apply to fn inside fn" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    if (testNestedFnErrDefer()) |_| @panic("expected error") else |e| try expect(e == error.Bad);
}

fn testNestedFnErrDefer() anyerror!void {
    var a: i32 = 0;
    errdefer a += 1;
    const S = struct {
        fn baz() anyerror {
            return error.Bad;
        }
    };
    return S.baz();
}

test "return variable while defer expression in scope to modify it" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try expect(notNull().? == 1);
        }

        fn notNull() ?u8 {
            var res: ?u8 = 1;
            defer res = null;
            return res;
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

var result: [3]u8 = undefined;
var index: usize = undefined;

fn runSomeErrorDefers(x: bool) !bool {
    index = 0;
    defer {
        result[index] = 'a';
        index += 1;
    }
    errdefer {
        result[index] = 'b';
        index += 1;
    }
    defer {
        result[index] = 'c';
        index += 1;
    }
    return if (x) x else error.FalseNotAllowed;
}

test "mixing normal and error defers" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try expect(runSomeErrorDefers(true) catch unreachable);
    try expect(result[0] == 'c');
    try expect(result[1] == 'a');

    const ok = runSomeErrorDefers(false) catch |err| x: {
        try expect(err == error.FalseNotAllowed);
        break :x true;
    };
    try expect(ok);
    try expect(result[0] == 'c');
    try expect(result[1] == 'b');
    try expect(result[2] == 'a');
}

test "errdefer with payload" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() !i32 {
            errdefer |a| {
                expectEqual(error.One, a) catch @panic("test failure");
            }
            return error.One;
        }
        fn doTheTest() !void {
            try expectError(error.One, foo());
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
