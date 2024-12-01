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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime S.doTheTest();
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}

test "reference to errdefer payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn foo() !i32 {
            errdefer |a| {
                const ptr = &a;
                const ptr2 = &ptr;
                expectEqual(error.One, ptr2.*.*) catch @panic("test failure");
                expectEqual(error.One, ptr.*) catch @panic("test failure");
            }
            return error.One;
        }
        fn doTheTest() !void {
            try expectError(error.One, foo());
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "simple else prong doesn't emit an error for unreachable else prong" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() error{Foo}!void {
            return error.Foo;
        }
    };
    var a: u32 = 0;
    defer a += 1;
    S.foo() catch |err| switch (err) {
        error.Foo => a += 1,
        else => |e| return e,
    };
    try expect(a == 1);
}

test "errdefer used in function that doesn't return an error" {
    const S = struct {
        fn foo() u8 {
            var a: u8 = 5;
            errdefer a += 1;
            return a;
        }
    };
    try expect(S.foo() == 5);
}

// Originally reported at https://github.com/ziglang/zig/issues/10591
const defer_assign = switch (block: {
    var x = 0;
    defer x = 1;
    break :block x;
}) {
    else => |i| i,
};
comptime {
    if (defer_assign != 0) @compileError("defer_assign failed!");
}

test "errdefer capture" {
    const S = struct {
        fail: bool = undefined,
        fn bar0(self: *@This()) error{a}!void {
            self.fail = false;
            errdefer |err| if (@TypeOf(err) != error{a}) {
                self.fail = true;
            };
            return error.a;
        }
        fn bar1(self: *@This()) error{a}!void {
            self.fail = false;
            errdefer |err| if (@TypeOf(err) != error{a}) {
                self.fail = true;
            };
            const rv: error{a}!void = @errorCast(@as(error{a}!void, error.a));
            return rv;
        }
        // https://github.com/ziglang/zig/issues/20371
        fn bar2(self: *@This()) error{a}!void {
            self.fail = false;
            errdefer |err| if (@TypeOf(err) != error{a}) {
                self.fail = true;
            };
            return @errorCast(@as(error{a}!void, error.a));
        }
    };

    var s: S = .{};
    s.bar0() catch {};
    if (s.fail) return error.TestExpectedError;
    s.bar1() catch {};
    if (s.fail) return error.TestExpectedError;
    s.bar2() catch {};
    if (s.fail) return error.TestExpectedError;
}
