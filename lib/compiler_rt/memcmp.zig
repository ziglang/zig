const std = @import("std");
const common = @import("./common.zig");

comptime {
    @export(&memcmp, .{ .name = "memcmp", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn memcmp(vl: [*]const u8, vr: [*]const u8, n: usize) callconv(.C) c_int {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const compared = @as(c_int, vl[i]) -% @as(c_int, vr[i]);
        if (compared != 0) return compared;
    }
    return 0;
}

test "memcmp" {
    const arr0 = &[_]u8{ 1, 1, 1 };
    const arr1 = &[_]u8{ 1, 1, 1 };
    const arr2 = &[_]u8{ 1, 0, 1 };
    const arr3 = &[_]u8{ 1, 2, 1 };
    const arr4 = &[_]u8{ 1, 0xff, 1 };

    try std.testing.expect(memcmp(arr0, arr1, 3) == 0);
    try std.testing.expect(memcmp(arr0, arr2, 3) > 0);
    try std.testing.expect(memcmp(arr0, arr3, 3) < 0);

    try std.testing.expect(memcmp(arr0, arr4, 3) < 0);
    try std.testing.expect(memcmp(arr4, arr0, 3) > 0);
}
