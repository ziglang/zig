const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const assert = std.debug.assert;

test "while loop" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var i: i32 = 0;
    while (i < 4) {
        i += 1;
    }
    try expect(i == 4);
    try expect(whileLoop1() == 1);
}
fn whileLoop1() i32 {
    return whileLoop2();
}
fn whileLoop2() i32 {
    while (true) {
        return 1;
    }
}

test "static eval while" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(static_eval_while_number == 1);
}
const static_eval_while_number = staticWhileLoop1();
fn staticWhileLoop1() i32 {
    return staticWhileLoop2();
}
fn staticWhileLoop2() i32 {
    while (true) {
        return 1;
    }
}

test "while with continue expression" {
    var sum: i32 = 0;
    {
        var i: i32 = 0;
        while (i < 10) : (i += 1) {
            if (i == 5) continue;
            sum += i;
        }
    }
    try expect(sum == 40);
}

test "while with else" {
    var sum: i32 = 0;
    var i: i32 = 0;
    var got_else: i32 = 0;
    while (i < 10) : (i += 1) {
        sum += 1;
    } else {
        got_else += 1;
    }
    try expect(sum == 10);
    try expect(got_else == 1);
}

var numbers_left: i32 = undefined;
fn getNumberOrErr() anyerror!i32 {
    return if (numbers_left == 0) error.OutOfNumbers else x: {
        numbers_left -= 1;
        break :x numbers_left;
    };
}
fn getNumberOrNull() ?i32 {
    return if (numbers_left == 0) null else x: {
        numbers_left -= 1;
        break :x numbers_left;
    };
}

test "continue outer while loop" {
    testContinueOuter();
    comptime testContinueOuter();
}

fn testContinueOuter() void {
    var i: usize = 0;
    outer: while (i < 10) : (i += 1) {
        while (true) {
            continue :outer;
        }
    }
}

test "break from outer while loop" {
    testBreakOuter();
    comptime testBreakOuter();
}

fn testBreakOuter() void {
    outer: while (true) {
        while (true) {
            break :outer;
        }
    }
}

test "while copies its payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var tmp: ?i32 = 10;
            while (tmp) |value| {
                // Modify the original variable
                tmp = null;
                try expect(value == 10);
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "continue and break" {
    if (builtin.zig_backend == .stage2_aarch64 and builtin.os.tag == .macos) return error.SkipZigTest;

    try runContinueAndBreakTest();
    try expect(continue_and_break_counter == 8);
}
var continue_and_break_counter: i32 = 0;
fn runContinueAndBreakTest() !void {
    var i: i32 = 0;
    while (true) {
        continue_and_break_counter += 2;
        i += 1;
        if (i < 4) {
            continue;
        }
        break;
    }
    try expect(i == 4);
}

test "while with optional as condition" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    numbers_left = 10;
    var sum: i32 = 0;
    while (getNumberOrNull()) |value| {
        sum += value;
    }
    try expect(sum == 45);
}

test "while with optional as condition with else" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    numbers_left = 10;
    var sum: i32 = 0;
    var got_else: i32 = 0;
    while (getNumberOrNull()) |value| {
        sum += value;
        try expect(got_else == 0);
    } else {
        got_else += 1;
    }
    try expect(sum == 45);
    try expect(got_else == 1);
}

test "while with error union condition" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    numbers_left = 10;
    var sum: i32 = 0;
    var got_else: i32 = 0;
    while (getNumberOrErr()) |value| {
        sum += value;
    } else |err| {
        try expect(err == error.OutOfNumbers);
        got_else += 1;
    }
    try expect(sum == 45);
    try expect(got_else == 1);
}

test "while on bool with else result follow else prong" {
    const result = while (returnFalse()) {
        break @as(i32, 10);
    } else @as(i32, 2);
    try expect(result == 2);
}

test "while on bool with else result follow break prong" {
    const result = while (returnTrue()) {
        break @as(i32, 10);
    } else @as(i32, 2);
    try expect(result == 10);
}

test "while on optional with else result follow else prong" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const result = while (returnNull()) |value| {
        break value;
    } else @as(i32, 2);
    try expect(result == 2);
}

test "while on optional with else result follow break prong" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const result = while (returnOptional(10)) |value| {
        break value;
    } else @as(i32, 2);
    try expect(result == 10);
}

fn returnNull() ?i32 {
    return null;
}
fn returnOptional(x: i32) ?i32 {
    return x;
}
fn returnError() anyerror!i32 {
    return error.YouWantedAnError;
}
fn returnSuccess(x: i32) anyerror!i32 {
    return x;
}
fn returnFalse() bool {
    return false;
}
fn returnTrue() bool {
    return true;
}

test "return with implicit cast from while loop" {
    returnWithImplicitCastFromWhileLoopTest() catch unreachable;
}
fn returnWithImplicitCastFromWhileLoopTest() anyerror!void {
    while (true) {
        return;
    }
}

test "while on error union with else result follow else prong" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const result = while (returnError()) |value| {
        break value;
    } else |_| @as(i32, 2);
    try expect(result == 2);
}

test "while on error union with else result follow break prong" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const result = while (returnSuccess(10)) |value| {
        break value;
    } else |_| @as(i32, 2);
    try expect(result == 10);
}

test "while bool 2 break statements and an else" {
    const S = struct {
        fn entry(t: bool, f: bool) !void {
            var ok = false;
            ok = while (t) {
                if (f) break false;
                if (t) break true;
            } else false;
            try expect(ok);
        }
    };
    try S.entry(true, false);
    try comptime S.entry(true, false);
}

test "while optional 2 break statements and an else" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn entry(opt_t: ?bool, f: bool) !void {
            var ok = false;
            ok = while (opt_t) |t| {
                if (f) break false;
                if (t) break true;
            } else false;
            try expect(ok);
        }
    };
    try S.entry(true, false);
    try comptime S.entry(true, false);
}

test "while error 2 break statements and an else" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn entry(opt_t: anyerror!bool, f: bool) !void {
            var ok = false;
            ok = while (opt_t) |t| {
                if (f) break false;
                if (t) break true;
            } else |_| false;
            try expect(ok);
        }
    };
    try S.entry(true, false);
    try comptime S.entry(true, false);
}

test "continue inline while loop" {
    comptime var i = 0;
    inline while (i < 10) : (i += 1) {
        if (i < 5) continue;
        break;
    }
    comptime assert(i == 5);
}

test "else continue outer while" {
    var i: usize = 0;
    while (true) {
        i += 1;
        while (i > 5) {
            return;
        } else continue;
    }
}

test "try terminating an infinite loop" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    // Test coverage for https://github.com/ziglang/zig/issues/13546
    const Foo = struct {
        trash: i32,

        fn bar() anyerror!@This() {
            return .{ .trash = 1234 };
        }
    };
    var t = true;
    errdefer t = false;
    try expect(while (true) {
        if (t) break t;
        _ = try Foo.bar();
    } else unreachable);
}

test "while loop with comptime true condition needs no else block to return value with break" {
    const x = while (true) {
        break @as(u32, 69);
    };
    try expect(x == 69);
}

test "int returned from switch in while" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: u32 = 3;
    const val: usize = while (true) switch (x) {
        1 => break 2,
        else => x -= 1,
    };
    try std.testing.expect(val == 2);
}

test "breaking from a loop in an if statement" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn retOpt() ?u32 {
            return null;
        }
    };

    var cond = true;
    _ = &cond;
    const opt = while (cond) {
        if (S.retOpt()) |opt| {
            break opt;
        }
        break 1;
    } else 2;
    _ = opt;
}
