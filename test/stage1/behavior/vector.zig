const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

test "implicit array to vector and vector to array" {
    const S = struct {
        fn doTheTest() void {
            var v: @Vector(4, i32) = [4]i32{10, 20, 30, 40};
            const x: @Vector(4, i32) = [4]i32{1, 2, 3, 4};
            v +%= x;
            const result: [4]i32 = v;
            assertOrPanic(result[0] == 11);
            assertOrPanic(result[1] == 22);
            assertOrPanic(result[2] == 33);
            assertOrPanic(result[3] == 44);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

