const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;

test "vector integer addition" {
    const S = struct {
        fn doTheTest() void {
            var a: @Vector(4, i32) = []i32{ 1, 2, 3, 4 };
            var b: @Vector(4, i32) = []i32{ 5, 6, 7, 8 };
            var result = a + b;
            var result_array: [4]i32 = result;
            const expected = []i32{ 6, 8, 10, 12 };
            expectEqualSlices(i32, &expected, &result_array);
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
            expect(mem.eql(i32, ([4]i32)(v +% x), [4]i32{ -2147483648, 2147483645, 33, 44 }));
            expect(mem.eql(i32, ([4]i32)(v -% x), [4]i32{ 2147483646, 2147483647, 27, 36 }));
            expect(mem.eql(i32, ([4]i32)(v *% x), [4]i32{ 2147483647, 2, 90, 160 }));
            var z: @Vector(4, i32) = [4]i32{ 1, 2, 3, -2147483648 };
            expect(mem.eql(i32, ([4]i32)(-%z), [4]i32{ -1, -2, -3, -2147483648 }));
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
            expect(mem.eql(i32, ([4]i32)(v + x), [4]i32{ 11, 22, 33, 44 }));
            expect(mem.eql(i32, ([4]i32)(v - x), [4]i32{ 9, 18, 27, 36 }));
            expect(mem.eql(i32, ([4]i32)(v * x), [4]i32{ 10, 40, 90, 160 }));
            expect(mem.eql(i32, ([4]i32)(-v), [4]i32{ -10, -20, -30, -40 }));
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
            expect(mem.eql(f32, ([4]f32)(v + x), [4]f32{ 11, 22, 33, 44 }));
            expect(mem.eql(f32, ([4]f32)(v - x), [4]f32{ 9, 18, 27, 36 }));
            expect(mem.eql(f32, ([4]f32)(v * x), [4]f32{ 10, 40, 90, 160 }));
            expect(mem.eql(f32, ([4]f32)(-x), [4]f32{ -1, -2, -3, -4 }));
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
            expect(mem.eql(u8, ([4]u8)(v ^ x), [4]u8{ 0b01011010, 0b10100101, 0b00000000, 0b11111111 }));
            expect(mem.eql(u8, ([4]u8)(v | x), [4]u8{ 0b11111010, 0b10101111, 0b10101010, 0b11111111 }));
            expect(mem.eql(u8, ([4]u8)(v & x), [4]u8{ 0b10100000, 0b00001010, 0b10101010, 0b00000000 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector saturating operators" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
            expect(mem.eql(i32, ([4]i32)(@satSub(@Vector(4, i32), v, x)), [4]i32{ 2147483646, -2147483648, 27, 36 }));
            var a: @Vector(4, u8) = [4]u8{ 1, 2, 3, 4 };
            var b: @Vector(4, u8) = [4]u8{ 253, 253, 253, 253 };
            expect(mem.eql(u8, ([4]u8)(@satAdd(@Vector(4, u8), a, b)), [4]u8{ 254, 255, 255, 255 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector widen" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, u8) = [4]u8{ 1, 2, 3, 4 };
            var v2: @Vector(4, u16) = (@Vector(4, u16))(v);
            var a: [4]u8 = v;
            var b: [4]u16 = v2;
            expect(a[0] == b[0]);
            expect(a[1] == b[1]);
            expect(a[2] == b[2]);
            expect(a[3] == b[3]);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector @clz/@ctz" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, u8) = [4]u8{ 0b00001111, 0b01111110, 0b00000000, 0b10000000 };
            var v2: @Vector(4, u8) = @clz(@Vector(4, u8), v);
            var a: [4]u8 = v2;
            expect(a[0] == 4);
            expect(a[1] == 1);
            expect(a[2] == 8);
            expect(a[3] == 0);
            v2 = @ctz(@Vector(4, u8), v);
            a = v2;
            expect(a[0] == 0);
            expect(a[1] == 1);
            expect(a[2] == 8);
            expect(a[3] == 7);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}
