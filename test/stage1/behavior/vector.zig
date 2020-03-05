const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "implicit cast vector to array - bool" {
    const S = struct {
        fn doTheTest() void {
            const a: @Vector(4, bool) = [_]bool{ true, false, true, false };
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
            var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
            expect(mem.eql(i32, &@as([4]i32, v +% x), &[4]i32{ -2147483648, 2147483645, 33, 44 }));
            expect(mem.eql(i32, &@as([4]i32, v -% x), &[4]i32{ 2147483646, 2147483647, 27, 36 }));
            expect(mem.eql(i32, &@as([4]i32, v *% x), &[4]i32{ 2147483647, 2, 90, 160 }));
            var z: @Vector(4, i32) = [4]i32{ 1, 2, 3, -2147483648 };
            expect(mem.eql(i32, &@as([4]i32, -%z), &[4]i32{ -1, -2, -3, -2147483648 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector bin compares with mem.eql" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 30, 4 };
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
            var v: @Vector(4, i32) = [4]i32{ 10, 20, 30, 40 };
            var x: @Vector(4, i32) = [4]i32{ 1, 2, 3, 4 };
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
            var v: @Vector(4, f32) = [4]f32{ 10, 20, 30, 40 };
            var x: @Vector(4, f32) = [4]f32{ 1, 2, 3, 4 };
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
            var v: @Vector(4, u8) = [4]u8{ 0b10101010, 0b10101010, 0b10101010, 0b10101010 };
            var x: @Vector(4, u8) = [4]u8{ 0b11110000, 0b00001111, 0b10101010, 0b01010101 };
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
            var a: @Vector(4, i32) = [_]i32{ 1, 2, 3, 4 };
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
    var vec: @Vector(4, f32) = arr;
}

test "vector casts of sizes not divisable by 8" {
    // https://github.com/ziglang/zig/issues/3563
    if (std.Target.current.os.tag == .dragonfly) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() void {
            {
                var v: @Vector(4, u3) = [4]u3{ 5, 2, 3, 0 };
                var x: [4]u3 = v;
                expect(mem.eql(u3, &x, &@as([4]u3, v)));
            }
            {
                var v: @Vector(4, u2) = [4]u2{ 1, 2, 3, 0 };
                var x: [4]u2 = v;
                expect(mem.eql(u2, &x, &@as([4]u2, v)));
            }
            {
                var v: @Vector(4, u1) = [4]u1{ 1, 0, 1, 0 };
                var x: [4]u1 = v;
                expect(mem.eql(u1, &x, &@as([4]u1, v)));
            }
            {
                var v: @Vector(4, bool) = [4]bool{ false, false, true, false };
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
            expect(@TypeOf(x) == @Vector(4, u32));
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
            var v: @Vector(4, i32) = [_]i32{ 1, 2, 3, undefined };
            expect(v[0] == 1);
            expect(v[1] == 2);
            expect(loadv(&v[2]) == 3);
        }
        fn loadv(ptr: var) i32 {
            return ptr.*;
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "store vector elements via comptime index" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, i32) = [_]i32{ 1, 5, 3, undefined };

            v[2] = 42;
            expect(v[1] == 5);
            v[3] = -364;
            expect(v[2] == 42);
            expect(-364 == v[3]);

            storev(&v[0], 100);
            expect(v[0] == 100);
        }
        fn storev(ptr: var, x: i32) void {
            ptr.* = x;
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "load vector elements via runtime index" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, i32) = [_]i32{ 1, 2, 3, undefined };
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
            var v: @Vector(4, i32) = [_]i32{ 1, 5, 3, undefined };
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
        data: @Vector(4, f32),
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
                const v1: @Vector(4, bool) = [_]bool{ true, false, true, false };
                const v2: @Vector(4, bool) = [_]bool{ false, true, false, true };
                expectEqual(@splat(4, true), v1 == v1);
                expectEqual(@splat(4, false), v1 == v2);
                expectEqual(@splat(4, true), v1 != v2);
                expectEqual(@splat(4, false), v2 != v2);
            }
            {
                const v1 = @splat(4, @as(u32, 0xc0ffeeee));
                const v2: @Vector(4, c_uint) = v1;
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
