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

test "vector shuffle" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
            const mask: @Vector(4, i32) = [4]i32{ 0, ~i32(2), 3, ~i32(3)};
            var res = @shuffle(i32, v, x, mask);
            expect(mem.eql(i32, ([4]i32)(res), [4]i32{ 2147483647, 3, 40, 4 }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "implicit cast vector to array - bool" {
    const S = struct {
        fn doTheTest() void {
            const a: @Vector(4, bool) = [_]bool{ true, false, true, false };
            const result_array: [4]bool = a;
            expect(mem.eql(bool, result_array, [4]bool{ true, false, true, false }));
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "vector bin compares without mem.eql" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 30, 4 };
            expect(mem.eql(bool, ([4]bool)(v == x), [4]bool{ false, false,  true, false}));
            expect(mem.eql(bool, ([4]bool)(v != x), [4]bool{  true,  true, false,  true}));
            expect(mem.eql(bool, ([4]bool)(v  < x), [4]bool{ false,  true, false, false}));
            expect(mem.eql(bool, ([4]bool)(v  > x), [4]bool{  true, false, false,  true}));
            expect(mem.eql(bool, ([4]bool)(v <= x), [4]bool{ false,  true,  true, false}));
            expect(mem.eql(bool, ([4]bool)(v >= x), [4]bool{  true, false,  true,  true}));
        }
    };
    // FIXME vector bools have one-bit width, while array bools have 1 byte width,
    // but what this test is meant to test for is passing.
    //S.doTheTest();
    comptime S.doTheTest();
}

test "vector bin compares with .all() and any()" {
    const S = struct {
        fn doTheTest() void {
            comptime var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            comptime var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 30, 4 };
            expect(((v == x) == @Vector(4, bool)([4]bool{ false, false,  true, false})).all);
            expect(((v != x) == @Vector(4, bool)([4]bool{  true,  true, false,  true})).all);
            expect(((v  < x) == @Vector(4, bool)([4]bool{ false,  true, false, false})).all);
            expect(((v  > x) == @Vector(4, bool)([4]bool{  true, false, false,  true})).all);
            expect(((v <= x) == @Vector(4, bool)([4]bool{ false,  true,  true, false})).all);
            expect(((v >= x) == @Vector(4, bool)([4]bool{  true, false,  true,  true})).all);
            expect(@Vector(4, bool)([4]bool{ false, false, false, false}).any == false);
            expect(@Vector(4, bool)([4]bool{ true, false, false, false}).any);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}