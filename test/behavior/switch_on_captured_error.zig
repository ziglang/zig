const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");

test "switch on error union catch capture" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    const S = struct {
        const Error = error{ A, B, C };
        fn doTheTest() !void {
            try testScalar();
            try testMulti();
            try testElse();
            try testCapture();
            try testInline();
            try testEmptyErrSet();
            try testAddressOf();
        }

        fn testScalar() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    error.B => 1,
                    error.C => 2,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    error.B => @intFromError(err) + 4,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    error.B => @intFromError(err) + 4,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
        }

        fn testMulti() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A, error.B => 0,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A, error.B => 0,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testElse() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    else => 1,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 1,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 1), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    else => 1,
                };
                try expectEqual(@as(u64, 1), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testCapture() !void {
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    else => 0,
                };
                try expectEqual(@as(u64, @intFromError(error.A) + 4), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testInline() !void {
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    inline else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    inline else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    inline else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.A => 0,
                    inline error.B, error.C => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testEmptyErrSet() !void {
            {
                var a: error{}!u64 = 0;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    else => |e| return e,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: error{}!u64 = 0;
                _ = &a;
                const b: u64 = a catch |err| switch (err) {
                    error.UnknownError => return error.Fail,
                    else => |e| return e,
                };
                try expectEqual(@as(u64, 0), b);
            }
        }

        fn testAddressOf() !void {
            {
                const a: anyerror!usize = 0;
                const ptr = &(a catch |e| switch (e) {
                    else => 3,
                });
                comptime assert(@TypeOf(ptr) == *const usize);
                try expectEqual(ptr, &(a catch unreachable));
            }
            {
                const a: anyerror!usize = error.A;
                const ptr = &(a catch |e| switch (e) {
                    else => 3,
                });
                comptime assert(@TypeOf(ptr) == *const comptime_int);
                try expectEqual(3, ptr.*);
            }
            {
                var a: anyerror!usize = 0;
                _ = &a;
                const ptr = &(a catch |e| switch (e) {
                    else => return,
                });
                comptime assert(@TypeOf(ptr) == *usize);
                ptr.* += 1;
                try expectEqual(@as(usize, 1), a catch unreachable);
            }
            {
                var a: anyerror!usize = error.A;
                _ = &a;
                const ptr = &(a catch |e| switch (e) {
                    else => return,
                });
                comptime assert(@TypeOf(ptr) == *usize);
                unreachable;
            }
        }
    };

    try comptime S.doTheTest();
    try S.doTheTest();
}

test "switch on error union if else capture" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    const S = struct {
        const Error = error{ A, B, C };
        fn doTheTest() !void {
            try testScalar();
            try testScalarPtr();
            try testMulti();
            try testMultiPtr();
            try testElse();
            try testElsePtr();
            try testCapture();
            try testCapturePtr();
            try testInline();
            try testInlinePtr();
            try testEmptyErrSet();
            try testEmptyErrSetPtr();
            try testAddressOf();
        }

        fn testScalar() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    error.B => 1,
                    error.C => 2,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    error.B => @intFromError(err) + 4,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    error.B => @intFromError(err) + 4,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
        }

        fn testScalarPtr() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    error.B => 1,
                    error.C => 2,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    error.B => @intFromError(err) + 4,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    error.B => @intFromError(err) + 4,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
        }

        fn testMulti() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A, error.B => 0,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A, error.B => 0,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testMultiPtr() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A, error.B => 0,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A, error.B => 0,
                    error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testElse() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    else => 1,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 1,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 1), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    else => 1,
                };
                try expectEqual(@as(u64, 1), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testElsePtr() !void {
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    else => 1,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = 3;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 3), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 1,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, 1), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    else => 1,
                };
                try expectEqual(@as(u64, 1), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testCapture() !void {
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    else => 0,
                };
                try expectEqual(@as(u64, @intFromError(error.A) + 4), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testCapturePtr() !void {
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    else => 0,
                };
                try expectEqual(@as(u64, @intFromError(error.A) + 4), b);
            }
            {
                var a: Error!u64 = error.A;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    error.B, error.C => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testInline() !void {
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    inline else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    inline else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    inline else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.A => 0,
                    inline error.B, error.C => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testInlinePtr() !void {
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    inline else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => |e| @intFromError(e) + 4,
                    inline else => @intFromError(err) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    inline else => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
            {
                var a: Error!u64 = error.B;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.A => 0,
                    inline error.B, error.C => |e| @intFromError(e) + 4,
                };
                try expectEqual(@as(u64, @intFromError(error.B) + 4), b);
            }
        }

        fn testEmptyErrSet() !void {
            {
                var a: error{}!u64 = 0;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    else => |e| return e,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: error{}!u64 = 0;
                _ = &a;
                const b: u64 = if (a) |x| x else |err| switch (err) {
                    error.UnknownError => return error.Fail,
                    else => |e| return e,
                };
                try expectEqual(@as(u64, 0), b);
            }
        }

        fn testEmptyErrSetPtr() !void {
            {
                var a: error{}!u64 = 0;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    else => |e| return e,
                };
                try expectEqual(@as(u64, 0), b);
            }
            {
                var a: error{}!u64 = 0;
                _ = &a;
                const b: u64 = if (a) |*x| x.* else |err| switch (err) {
                    error.UnknownError => return error.Fail,
                    else => |e| return e,
                };
                try expectEqual(@as(u64, 0), b);
            }
        }

        fn testAddressOf() !void {
            if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
            {
                const a: anyerror!usize = 0;
                const ptr = &(if (a) |*v| v.* else |e| switch (e) {
                    else => 3,
                });
                comptime assert(@TypeOf(ptr) == *const usize);
                try expectEqual(ptr, &(a catch unreachable));
            }
            {
                const a: anyerror!usize = error.A;
                const ptr = &(if (a) |*v| v.* else |e| switch (e) {
                    else => 3,
                });
                comptime assert(@TypeOf(ptr) == *const comptime_int);
                try expectEqual(3, ptr.*);
            }
            {
                var a: anyerror!usize = 0;
                _ = &a;
                const ptr = &(if (a) |*v| v.* else |e| switch (e) {
                    else => return,
                });
                comptime assert(@TypeOf(ptr) == *usize);
                ptr.* += 1;
                try expectEqual(@as(usize, 1), a catch unreachable);
            }
            {
                var a: anyerror!usize = error.A;
                _ = &a;
                const ptr = &(if (a) |*v| v.* else |e| switch (e) {
                    else => return,
                });
                comptime assert(@TypeOf(ptr) == *usize);
                unreachable;
            }
        }
    };

    try comptime S.doTheTest();
    try S.doTheTest();
}
