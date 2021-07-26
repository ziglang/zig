const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const Vector = std.meta.Vector;

test "@select" {
    const S = struct {
        fn doTheTest() !void {
            var a: Vector(4, bool) = [4]bool{ true, false, true, false };
            var b: Vector(4, i32) = [4]i32{ -1, 4, 999, -31 };
            var c: Vector(4, i32) = [4]i32{ -5, 1, 0, 1234 };
            var abc = @select(i32, a, b, c);
            try expect(mem.eql(i32, &@as([4]i32, abc), &[4]i32{ -1, 1, 999, 1234 }));

            var x: Vector(4, bool) = [4]bool{ false, false, false, true };
            var y: Vector(4, f32) = [4]f32{ 0.001, 33.4, 836, -3381.233 };
            var z: Vector(4, f32) = [4]f32{ 0.0, 312.1, -145.9, 9993.55 };
            var xyz = @select(f32, x, y, z);
            try expect(mem.eql(f32, &@as([4]f32, xyz), &[4]f32{ 0.0, 312.1, -145.9, -3381.233 }));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
