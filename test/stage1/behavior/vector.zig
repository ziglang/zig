const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Vector = std.meta.Vector;

test "implicit cast vector to array - bool" {
    const S = struct {
        fn doTheTest() void {
            const a: Vector(4, bool) = [_]bool{ true, false, true, false };
            const result_array: [4]bool = a;
            expect(mem.eql(bool, &result_array, &[4]bool{ true, false, true, false }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector wrap operators" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var x: Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
            expect(mem.eql(i32, &@as([4]i32, v +% x), &[4]i32{ -2147483648, 2147483645, 33, 44 }));
            expect(mem.eql(i32, &@as([4]i32, v -% x), &[4]i32{ 2147483646, 2147483647, 27, 36 }));
            expect(mem.eql(i32, &@as([4]i32, v *% x), &[4]i32{ 2147483647, 2, 90, 160 }));
            var z: Vector(4, i32) = [4]i32{ 1, 2, 3, -2147483648 };
            expect(mem.eql(i32, &@as([4]i32, -%z), &[4]i32{ -1, -2, -3, -2147483648 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector bin compares with mem.eql" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var x: Vector(4, i32) = [4]i32{ 1, 2147483647, 30, 4 };
            expect(mem.eql(bool, &@as([4]bool, v == x), &[4]bool{ false, false, true, false }));
            expect(mem.eql(bool, &@as([4]bool, v != x), &[4]bool{ true, true, false, true }));
            expect(mem.eql(bool, &@as([4]bool, v < x), &[4]bool{ false, true, false, false }));
            expect(mem.eql(bool, &@as([4]bool, v > x), &[4]bool{ true, false, false, true }));
            expect(mem.eql(bool, &@as([4]bool, v <= x), &[4]bool{ false, true, true, false }));
            expect(mem.eql(bool, &@as([4]bool, v >= x), &[4]bool{ true, false, true, true }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector int operators" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, i32) = [4]i32{ 10, 20, 30, 40 };
            var x: Vector(4, i32) = [4]i32{ 1, 2, 3, 4 };
            expect(mem.eql(i32, &@as([4]i32, v + x), &[4]i32{ 11, 22, 33, 44 }));
            expect(mem.eql(i32, &@as([4]i32, v - x), &[4]i32{ 9, 18, 27, 36 }));
            expect(mem.eql(i32, &@as([4]i32, v * x), &[4]i32{ 10, 40, 90, 160 }));
            expect(mem.eql(i32, &@as([4]i32, -v), &[4]i32{ -10, -20, -30, -40 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector float operators" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, f32) = [4]f32{ 10, 20, 30, 40 };
            var x: Vector(4, f32) = [4]f32{ 1, 2, 3, 4 };
            expect(mem.eql(f32, &@as([4]f32, v + x), &[4]f32{ 11, 22, 33, 44 }));
            expect(mem.eql(f32, &@as([4]f32, v - x), &[4]f32{ 9, 18, 27, 36 }));
            expect(mem.eql(f32, &@as([4]f32, v * x), &[4]f32{ 10, 40, 90, 160 }));
            expect(mem.eql(f32, &@as([4]f32, -x), &[4]f32{ -1, -2, -3, -4 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector bit operators" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, u8) = [4]u8{ 0b10101010, 0b10101010, 0b10101010, 0b10101010 };
            var x: Vector(4, u8) = [4]u8{ 0b11110000, 0b00001111, 0b10101010, 0b01010101 };
            expect(mem.eql(u8, &@as([4]u8, v ^ x), &[4]u8{ 0b01011010, 0b10100101, 0b00000000, 0b11111111 }));
            expect(mem.eql(u8, &@as([4]u8, v | x), &[4]u8{ 0b11111010, 0b10101111, 0b10101010, 0b11111111 }));
            expect(mem.eql(u8, &@as([4]u8, v & x), &[4]u8{ 0b10100000, 0b00001010, 0b10101010, 0b00000000 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "implicit cast vector to array" {
    const S = struct {
        fn doTheTest() void {
            var a: Vector(4, i32) = [_]i32{ 1, 2, 3, 4 };
            var result_array: [4]i32 = a;
            result_array = a;
            expect(mem.eql(i32, &result_array, &[4]i32{ 1, 2, 3, 4 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "array to vector" {
    var foo: f32 = 3.14;
    var arr = [4]f32{ foo, 1.5, 0.0, 0.0 };
    var vec: Vector(4, f32) = arr;
}

test "vector casts of sizes not divisable by 8" {
    // https://github.com/ziglang/zig/issues/3563
    if (std.Target.current.os.tag == .dragonfly) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() void {
            {
                var v: Vector(4, u3) = [4]u3{ 5, 2, 3, 0 };
                var x: [4]u3 = v;
                expect(mem.eql(u3, &x, &@as([4]u3, v)));
            }
            {
                var v: Vector(4, u2) = [4]u2{ 1, 2, 3, 0 };
                var x: [4]u2 = v;
                expect(mem.eql(u2, &x, &@as([4]u2, v)));
            }
            {
                var v: Vector(4, u1) = [4]u1{ 1, 0, 1, 0 };
                var x: [4]u1 = v;
                expect(mem.eql(u1, &x, &@as([4]u1, v)));
            }
            {
                var v: Vector(4, bool) = [4]bool{ false, false, true, false };
                var x: [4]bool = v;
                expect(mem.eql(bool, &x, &@as([4]bool, v)));
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector @splat" {
    const S = struct {
        fn doTheTest() void {
            var v: u32 = 5;
            var x = @splat(4, v);
            expect(@TypeOf(x) == Vector(4, u32));
            var array_x: [4]u32 = x;
            expect(array_x[0] == 5);
            expect(array_x[1] == 5);
            expect(array_x[2] == 5);
            expect(array_x[3] == 5);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "load vector elements via comptime index" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, i32) = [_]i32{ 1, 2, 3, undefined };
            expect(v[0] == 1);
            expect(v[1] == 2);
            expect(loadv(&v[2]) == 3);
        }
        fn loadv(ptr: anytype) i32 {
            return ptr.*;
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "store vector elements via comptime index" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, i32) = [_]i32{ 1, 5, 3, undefined };

            v[2] = 42;
            expect(v[1] == 5);
            v[3] = -364;
            expect(v[2] == 42);
            expect(-364 == v[3]);

            storev(&v[0], 100);
            expect(v[0] == 100);
        }
        fn storev(ptr: anytype, x: i32) void {
            ptr.* = x;
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "load vector elements via runtime index" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, i32) = [_]i32{ 1, 2, 3, undefined };
            var i: u32 = 0;
            expect(v[i] == 1);
            i += 1;
            expect(v[i] == 2);
            i += 1;
            expect(v[i] == 3);
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "store vector elements via runtime index" {
    const S = struct {
        fn doTheTest() void {
            var v: Vector(4, i32) = [_]i32{ 1, 5, 3, undefined };
            var i: u32 = 2;
            v[i] = 1;
            expect(v[1] == 5);
            expect(v[2] == 1);
            i += 1;
            v[i] = -364;
            expect(-364 == v[3]);
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "initialize vector which is a struct field" {
    const Vec4Obj = struct {
        data: Vector(4, f32),
    };

    const S = struct {
        fn doTheTest() void {
            var foo = Vec4Obj{
                .data = [_]f32{ 1, 2, 3, 4 },
            };
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector comparison operators" {
    const S = struct {
        fn doTheTest() void {
            {
                const v1: Vector(4, bool) = [_]bool{ true, false, true, false };
                const v2: Vector(4, bool) = [_]bool{ false, true, false, true };
                expectEqual(@splat(4, true), v1 == v1);
                expectEqual(@splat(4, false), v1 == v2);
                expectEqual(@splat(4, true), v1 != v2);
                expectEqual(@splat(4, false), v2 != v2);
            }
            {
                const v1 = @splat(4, @as(u32, 0xc0ffeeee));
                const v2: Vector(4, c_uint) = v1;
                const v3 = @splat(4, @as(u32, 0xdeadbeef));
                expectEqual(@splat(4, true), v1 == v2);
                expectEqual(@splat(4, false), v1 == v3);
                expectEqual(@splat(4, true), v1 != v3);
                expectEqual(@splat(4, false), v1 != v2);
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector division operators" {
    const S = struct {
        fn doTheTestDiv(comptime T: type, x: Vector(4, T), y: Vector(4, T)) void {
            if (!comptime std.meta.trait.isSignedInt(T)) {
                const d0 = x / y;
                for (@as([4]T, d0)) |v, i| {
                    expectEqual(x[i] / y[i], v);
                }
            }
            const d1 = @divExact(x, y);
            for (@as([4]T, d1)) |v, i| {
                expectEqual(@divExact(x[i], y[i]), v);
            }
            const d2 = @divFloor(x, y);
            for (@as([4]T, d2)) |v, i| {
                expectEqual(@divFloor(x[i], y[i]), v);
            }
            const d3 = @divTrunc(x, y);
            for (@as([4]T, d3)) |v, i| {
                expectEqual(@divTrunc(x[i], y[i]), v);
            }
        }

        fn doTheTestMod(comptime T: type, x: Vector(4, T), y: Vector(4, T)) void {
            if ((!comptime std.meta.trait.isSignedInt(T)) and @typeInfo(T) != .Float) {
                const r0 = x % y;
                for (@as([4]T, r0)) |v, i| {
                    expectEqual(x[i] % y[i], v);
                }
            }
            const r1 = @mod(x, y);
            for (@as([4]T, r1)) |v, i| {
                expectEqual(@mod(x[i], y[i]), v);
            }
            const r2 = @rem(x, y);
            for (@as([4]T, r2)) |v, i| {
                expectEqual(@rem(x[i], y[i]), v);
            }
        }

        fn doTheTest() void {
            // https://github.com/ziglang/zig/issues/4952
            if (std.builtin.os.tag != .windows) {
                doTheTestDiv(f16, [4]f16{ 4.0, -4.0, 4.0, -4.0 }, [4]f16{ 1.0, 2.0, -1.0, -2.0 });
            }

            doTheTestDiv(f32, [4]f32{ 4.0, -4.0, 4.0, -4.0 }, [4]f32{ 1.0, 2.0, -1.0, -2.0 });
            doTheTestDiv(f64, [4]f64{ 4.0, -4.0, 4.0, -4.0 }, [4]f64{ 1.0, 2.0, -1.0, -2.0 });

            // https://github.com/ziglang/zig/issues/4952
            if (std.builtin.os.tag != .windows) {
                doTheTestMod(f16, [4]f16{ 4.0, -4.0, 4.0, -4.0 }, [4]f16{ 1.0, 2.0, 0.5, 3.0 });
            }
            doTheTestMod(f32, [4]f32{ 4.0, -4.0, 4.0, -4.0 }, [4]f32{ 1.0, 2.0, 0.5, 3.0 });
            doTheTestMod(f64, [4]f64{ 4.0, -4.0, 4.0, -4.0 }, [4]f64{ 1.0, 2.0, 0.5, 3.0 });

            doTheTestDiv(i8, [4]i8{ 4, -4, 4, -4 }, [4]i8{ 1, 2, -1, -2 });
            doTheTestDiv(i16, [4]i16{ 4, -4, 4, -4 }, [4]i16{ 1, 2, -1, -2 });
            doTheTestDiv(i32, [4]i32{ 4, -4, 4, -4 }, [4]i32{ 1, 2, -1, -2 });
            doTheTestDiv(i64, [4]i64{ 4, -4, 4, -4 }, [4]i64{ 1, 2, -1, -2 });

            doTheTestMod(i8, [4]i8{ 4, -4, 4, -4 }, [4]i8{ 1, 2, 4, 8 });
            doTheTestMod(i16, [4]i16{ 4, -4, 4, -4 }, [4]i16{ 1, 2, 4, 8 });
            doTheTestMod(i32, [4]i32{ 4, -4, 4, -4 }, [4]i32{ 1, 2, 4, 8 });
            doTheTestMod(i64, [4]i64{ 4, -4, 4, -4 }, [4]i64{ 1, 2, 4, 8 });

            doTheTestDiv(u8, [4]u8{ 1, 2, 4, 8 }, [4]u8{ 1, 1, 2, 4 });
            doTheTestDiv(u16, [4]u16{ 1, 2, 4, 8 }, [4]u16{ 1, 1, 2, 4 });
            doTheTestDiv(u32, [4]u32{ 1, 2, 4, 8 }, [4]u32{ 1, 1, 2, 4 });
            doTheTestDiv(u64, [4]u64{ 1, 2, 4, 8 }, [4]u64{ 1, 1, 2, 4 });

            doTheTestMod(u8, [4]u8{ 1, 2, 4, 8 }, [4]u8{ 1, 1, 2, 4 });
            doTheTestMod(u16, [4]u16{ 1, 2, 4, 8 }, [4]u16{ 1, 1, 2, 4 });
            doTheTestMod(u32, [4]u32{ 1, 2, 4, 8 }, [4]u32{ 1, 1, 2, 4 });
            doTheTestMod(u64, [4]u64{ 1, 2, 4, 8 }, [4]u64{ 1, 1, 2, 4 });
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "vector bitwise not operator" {
    const S = struct {
        fn doTheTestNot(comptime T: type, x: Vector(4, T)) void {
            var y = ~x;
            for (@as([4]T, y)) |v, i| {
                expectEqual(~x[i], v);
            }
        }
        fn doTheTest() void {
            doTheTestNot(u8, [_]u8{ 0, 2, 4, 255 });
            doTheTestNot(u16, [_]u16{ 0, 2, 4, 255 });
            doTheTestNot(u32, [_]u32{ 0, 2, 4, 255 });
            doTheTestNot(u64, [_]u64{ 0, 2, 4, 255 });

            doTheTestNot(u8, [_]u8{ 0, 2, 4, 255 });
            doTheTestNot(u16, [_]u16{ 0, 2, 4, 255 });
            doTheTestNot(u32, [_]u32{ 0, 2, 4, 255 });
            doTheTestNot(u64, [_]u64{ 0, 2, 4, 255 });
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "vector shift operators" {
    // TODO investigate why this fails when cross-compiled to wasm.
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const S = struct {
        fn doTheTestShift(x: anytype, y: anytype) void {
            const N = @typeInfo(@TypeOf(x)).Array.len;
            const TX = @typeInfo(@TypeOf(x)).Array.child;
            const TY = @typeInfo(@TypeOf(y)).Array.child;

            var xv = @as(Vector(N, TX), x);
            var yv = @as(Vector(N, TY), y);

            var z0 = xv >> yv;
            for (@as([N]TX, z0)) |v, i| {
                expectEqual(x[i] >> y[i], v);
            }
            var z1 = xv << yv;
            for (@as([N]TX, z1)) |v, i| {
                expectEqual(x[i] << y[i], v);
            }
        }
        fn doTheTestShiftExact(x: anytype, y: anytype, dir: enum { Left, Right }) void {
            const N = @typeInfo(@TypeOf(x)).Array.len;
            const TX = @typeInfo(@TypeOf(x)).Array.child;
            const TY = @typeInfo(@TypeOf(y)).Array.child;

            var xv = @as(Vector(N, TX), x);
            var yv = @as(Vector(N, TY), y);

            var z = if (dir == .Left) @shlExact(xv, yv) else @shrExact(xv, yv);
            for (@as([N]TX, z)) |v, i| {
                const check = if (dir == .Left) x[i] << y[i] else x[i] >> y[i];
                expectEqual(check, v);
            }
        }
        fn doTheTest() void {
            doTheTestShift([_]u8{ 0, 2, 4, math.maxInt(u8) }, [_]u3{ 2, 0, 2, 7 });
            doTheTestShift([_]u16{ 0, 2, 4, math.maxInt(u16) }, [_]u4{ 2, 0, 2, 15 });
            doTheTestShift([_]u24{ 0, 2, 4, math.maxInt(u24) }, [_]u5{ 2, 0, 2, 23 });
            doTheTestShift([_]u32{ 0, 2, 4, math.maxInt(u32) }, [_]u5{ 2, 0, 2, 31 });
            doTheTestShift([_]u64{ 0xfe, math.maxInt(u64) }, [_]u6{ 0, 63 });

            doTheTestShift([_]i8{ 0, 2, 4, math.maxInt(i8) }, [_]u3{ 2, 0, 2, 7 });
            doTheTestShift([_]i16{ 0, 2, 4, math.maxInt(i16) }, [_]u4{ 2, 0, 2, 7 });
            doTheTestShift([_]i24{ 0, 2, 4, math.maxInt(i24) }, [_]u5{ 2, 0, 2, 7 });
            doTheTestShift([_]i32{ 0, 2, 4, math.maxInt(i32) }, [_]u5{ 2, 0, 2, 7 });
            doTheTestShift([_]i64{ 0xfe, math.maxInt(i64) }, [_]u6{ 0, 63 });

            doTheTestShiftExact([_]u8{ 0, 1, 1 << 7, math.maxInt(u8) ^ 1 }, [_]u3{ 4, 0, 7, 1 }, .Right);
            doTheTestShiftExact([_]u16{ 0, 1, 1 << 15, math.maxInt(u16) ^ 1 }, [_]u4{ 4, 0, 15, 1 }, .Right);
            doTheTestShiftExact([_]u24{ 0, 1, 1 << 23, math.maxInt(u24) ^ 1 }, [_]u5{ 4, 0, 23, 1 }, .Right);
            doTheTestShiftExact([_]u32{ 0, 1, 1 << 31, math.maxInt(u32) ^ 1 }, [_]u5{ 4, 0, 31, 1 }, .Right);
            doTheTestShiftExact([_]u64{ 1 << 63, 1 }, [_]u6{ 63, 0 }, .Right);

            doTheTestShiftExact([_]u8{ 0, 1, 1, math.maxInt(u8) ^ (1 << 7) }, [_]u3{ 4, 0, 7, 1 }, .Left);
            doTheTestShiftExact([_]u16{ 0, 1, 1, math.maxInt(u16) ^ (1 << 15) }, [_]u4{ 4, 0, 15, 1 }, .Left);
            doTheTestShiftExact([_]u24{ 0, 1, 1, math.maxInt(u24) ^ (1 << 23) }, [_]u5{ 4, 0, 23, 1 }, .Left);
            doTheTestShiftExact([_]u32{ 0, 1, 1, math.maxInt(u32) ^ (1 << 31) }, [_]u5{ 4, 0, 31, 1 }, .Left);
            doTheTestShiftExact([_]u64{ 1 << 63, 1 }, [_]u6{ 0, 63 }, .Left);
        }
    };

    switch (std.builtin.arch) {
        .i386,
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .riscv64,
        .sparcv9,
        => {
            // LLVM miscompiles on this architecture
            // https://github.com/ziglang/zig/issues/4951
            return error.SkipZigTest;
        },
        else => {},
    }

    S.doTheTest();
    comptime S.doTheTest();
}
