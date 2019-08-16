const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

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

test "implicit cast vector to array" {
    const S = struct {
        fn doTheTest() void {
            var a: @Vector(4, i32) = [_]i32{ 1, 2, 3, 4 };
            var result_array: [4]i32 = a;
            result_array = a;
            expect(mem.eql(i32, result_array, [4]i32{ 1, 2, 3, 4 }));
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
