const std = @import("std");
const common = @import("./common.zig");

comptime {
    @export(bcmp, .{ .name = "bcmp", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn bcmp(vl: [*]allowzero const u8, vr: [*]allowzero const u8, n: usize) callconv(.C) c_int {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1) {
        if (vl[index] != vr[index]) {
            return 1;
        }
    }

    return 0;
}

test "bcmp" {
    const base_arr = &[_]u8{ 1, 1, 1 };
    const arr1 = &[_]u8{ 1, 1, 1 };
    const arr2 = &[_]u8{ 1, 0, 1 };
    const arr3 = &[_]u8{ 1, 2, 1 };

    try std.testing.expect(bcmp(base_arr[0..], arr1[0..], base_arr.len) == 0);
    try std.testing.expect(bcmp(base_arr[0..], arr2[0..], base_arr.len) != 0);
    try std.testing.expect(bcmp(base_arr[0..], arr3[0..], base_arr.len) != 0);
}
