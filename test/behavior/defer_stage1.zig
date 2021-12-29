const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

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
