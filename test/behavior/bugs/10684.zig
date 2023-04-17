const std = @import("std");
const builtin = @import("builtin");
const expectEqualStrings = std.testing.expectEqualStrings;

test "slicing slices" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const foo = "1234";
    const bar = foo[0..4];
    try expectEqualStrings("1234", bar);
    try expectEqualStrings("2", bar[1..2]);
    try expectEqualStrings("3", bar[2..3]);
    try expectEqualStrings("4", bar[3..4]);
    try expectEqualStrings("34", bar[2..4]);
}
