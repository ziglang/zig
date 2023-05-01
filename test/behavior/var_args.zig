const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

fn add(args: anytype) i32 {
    var sum = @as(i32, 0);
    {
        comptime var i: usize = 0;
        inline while (i < args.len) : (i += 1) {
            sum += args[i];
        }
    }
    return sum;
}

test "add arbitrary args" {
    try expect(add(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3), @as(i32, 4) }) == 10);
    try expect(add(.{@as(i32, 1234)}) == 1234);
    try expect(add(.{}) == 0);
}

fn readFirstVarArg(args: anytype) void {
    _ = args[0];
}

test "send void arg to var args" {
    readFirstVarArg(.{{}});
}

test "pass args directly" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(addSomeStuff(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3), @as(i32, 4) }) == 10);
    try expect(addSomeStuff(.{@as(i32, 1234)}) == 1234);
    try expect(addSomeStuff(.{}) == 0);
}

fn addSomeStuff(args: anytype) i32 {
    return add(args);
}

test "runtime parameter before var args" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect((try extraFn(10, .{})) == 0);
    try expect((try extraFn(10, .{false})) == 1);
    try expect((try extraFn(10, .{ false, true })) == 2);

    comptime {
        try expect((try extraFn(10, .{})) == 0);
        try expect((try extraFn(10, .{false})) == 1);
        try expect((try extraFn(10, .{ false, true })) == 2);
    }
}

fn extraFn(extra: u32, args: anytype) !usize {
    _ = extra;
    if (args.len >= 1) {
        try expect(args[0] == false);
    }
    if (args.len >= 2) {
        try expect(args[1] == true);
    }
    return args.len;
}

const foos = [_]fn (anytype) bool{
    foo1,
    foo2,
};

fn foo1(args: anytype) bool {
    _ = args;
    return true;
}
fn foo2(args: anytype) bool {
    _ = args;
    return false;
}

test "array of var args functions" {
    try expect(foos[0](.{}));
    try expect(!foos[1](.{}));
}

test "pass zero length array to var args param" {
    doNothingWithFirstArg(.{""});
}

fn doNothingWithFirstArg(args: anytype) void {
    _ = args[0];
}

test "simple variadic function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag != .macos) {
        // https://github.com/ziglang/zig/issues/14096
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .x86_64 and builtin.os.tag == .windows) return error.SkipZigTest; // TODO

    const S = struct {
        fn simple(...) callconv(.C) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            return @cVaArg(&ap, c_int);
        }

        fn compatible(_: c_int, ...) callconv(.C) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            return @cVaArg(&ap, c_int);
        }

        fn add(count: c_int, ...) callconv(.C) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            var i: usize = 0;
            var sum: c_int = 0;
            while (i < count) : (i += 1) {
                sum += @cVaArg(&ap, c_int);
            }
            return sum;
        }
    };

    if (builtin.zig_backend != .stage2_c) {
        // pre C23 doesn't support varargs without a preceding runtime arg.
        try std.testing.expectEqual(@as(c_int, 0), S.simple(@as(c_int, 0)));
        try std.testing.expectEqual(@as(c_int, 1024), S.simple(@as(c_int, 1024)));
    }
    try std.testing.expectEqual(@as(c_int, 0), S.compatible(undefined, @as(c_int, 0)));
    try std.testing.expectEqual(@as(c_int, 1024), S.compatible(undefined, @as(c_int, 1024)));
    try std.testing.expectEqual(@as(c_int, 0), S.add(0));
    try std.testing.expectEqual(@as(c_int, 1), S.add(1, @as(c_int, 1)));
    try std.testing.expectEqual(@as(c_int, 3), S.add(2, @as(c_int, 1), @as(c_int, 2)));
}

test "variadic functions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag != .macos) {
        // https://github.com/ziglang/zig/issues/14096
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .x86_64 and builtin.os.tag == .windows) return error.SkipZigTest; // TODO

    const S = struct {
        fn printf(list_ptr: *std.ArrayList(u8), format: [*:0]const u8, ...) callconv(.C) void {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            vprintf(list_ptr, format, &ap);
        }

        fn vprintf(
            list: *std.ArrayList(u8),
            format: [*:0]const u8,
            ap: *std.builtin.VaList,
        ) callconv(.C) void {
            for (std.mem.span(format)) |c| switch (c) {
                's' => {
                    const arg = @cVaArg(ap, [*:0]const u8);
                    list.writer().print("{s}", .{arg}) catch return;
                },
                'd' => {
                    const arg = @cVaArg(ap, c_int);
                    list.writer().print("{d}", .{arg}) catch return;
                },
                else => unreachable,
            };
        }
    };

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    S.printf(&list, "dsd", @as(c_int, 1), @as([*:0]const u8, "hello"), @as(c_int, 5));
    try std.testing.expectEqualStrings("1hello5", list.items);
}

test "copy VaList" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag != .macos) {
        // https://github.com/ziglang/zig/issues/14096
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .x86_64 and builtin.os.tag == .windows) return error.SkipZigTest; // TODO

    const S = struct {
        fn add(count: c_int, ...) callconv(.C) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            var copy = @cVaCopy(&ap);
            defer @cVaEnd(&copy);
            var i: usize = 0;
            var sum: c_int = 0;
            while (i < count) : (i += 1) {
                sum += @cVaArg(&ap, c_int);
                sum += @cVaArg(&copy, c_int) * 2;
            }
            return sum;
        }
    };

    try std.testing.expectEqual(@as(c_int, 0), S.add(0));
    try std.testing.expectEqual(@as(c_int, 3), S.add(1, @as(c_int, 1)));
    try std.testing.expectEqual(@as(c_int, 9), S.add(2, @as(c_int, 1), @as(c_int, 2)));
}

test "unused VaList arg" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag != .macos) {
        // https://github.com/ziglang/zig/issues/14096
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .x86_64 and builtin.os.tag == .windows) return error.SkipZigTest; // TODO

    const S = struct {
        fn thirdArg(dummy: c_int, ...) callconv(.C) c_int {
            _ = dummy;

            var ap = @cVaStart();
            defer @cVaEnd(&ap);

            _ = @cVaArg(&ap, c_int);
            return @cVaArg(&ap, c_int);
        }
    };
    const x = S.thirdArg(0, @as(c_int, 1), @as(c_int, 2));
    try std.testing.expectEqual(@as(c_int, 2), x);
}
