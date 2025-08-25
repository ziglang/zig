const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const mat4x5 = [4][5]f32{
    [_]f32{ 1.0, 0.0, 0.0, 0.0, 0.0 },
    [_]f32{ 0.0, 1.0, 0.0, 1.0, 0.0 },
    [_]f32{ 0.0, 0.0, 1.0, 0.0, 0.0 },
    [_]f32{ 0.0, 0.0, 0.0, 1.0, 9.9 },
};
test "multidimensional arrays" {
    // mat4x5 itself is a one-dimensional array of arrays.
    try expectEqual(mat4x5[1], [_]f32{ 0.0, 1.0, 0.0, 1.0, 0.0 });

    // Access the 2D array by indexing the outer array, and then the inner array.
    try expect(mat4x5[3][4] == 9.9);

    // Here we iterate with for loops.
    for (mat4x5, 0..) |row, row_index| {
        for (row, 0..) |cell, column_index| {
            if (row_index == column_index) {
                try expect(cell == 1.0);
            }
        }
    }

    // Initialize a multidimensional array to zeros.
    const all_zero: [4][5]f32 = .{.{0} ** 5} ** 4;
    try expect(all_zero[0][0] == 0);
}

// test
