const std = @import("std");
const builtin = @import("builtin");

test "strlit to vector" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const strlit = "0123456789abcdef0123456789ABCDEF";
    const vec_from_strlit: @Vector(32, u8) = strlit.*;
    const arr_from_vec = @as([32]u8, vec_from_strlit);
    for (strlit, 0..) |c, i|
        try std.testing.expect(c == arr_from_vec[i]);
    try std.testing.expectEqualSlices(u8, strlit, &arr_from_vec);
}
