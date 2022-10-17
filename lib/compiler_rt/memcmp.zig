const std = @import("std");
const common = @import("./common.zig");

comptime {
    @export(memcmp, .{ .name = "memcmp", .linkage = common.linkage });
}

pub fn memcmp(vl: ?[*]const u8, vr: ?[*]const u8, n: usize) callconv(.C) c_int {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1) {
        const compare_val = @bitCast(i8, vl.?[index] -% vr.?[index]);
        if (compare_val != 0) {
            return compare_val;
        }
    }

    return 0;
}

test "memcmp" {
    const base_arr = &[_]u8{ 1, 1, 1 };
    const arr1 = &[_]u8{ 1, 1, 1 };
    const arr2 = &[_]u8{ 1, 0, 1 };
    const arr3 = &[_]u8{ 1, 2, 1 };

    try std.testing.expect(memcmp(base_arr[0..], arr1[0..], base_arr.len) == 0);
    try std.testing.expect(memcmp(base_arr[0..], arr2[0..], base_arr.len) > 0);
    try std.testing.expect(memcmp(base_arr[0..], arr3[0..], base_arr.len) < 0);
}
