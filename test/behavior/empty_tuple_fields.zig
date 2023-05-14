const std = @import("std");
const builtin = @import("builtin");

test "empty file level struct" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const T = @import("empty_file_level_struct.zig");
    const info = @typeInfo(T);
    try std.testing.expectEqual(@as(usize, 1), info.Struct.fields.len);
    try std.testing.expectEqualStrings("0", info.Struct.fields[0].name);
    try std.testing.expect(@typeInfo(info.Struct.fields[0].type) == .Struct);
}

test "empty file level union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const T = @import("empty_file_level_union.zig");
    const info = @typeInfo(T);
    try std.testing.expectEqual(@as(usize, 1), info.Struct.fields.len);
    try std.testing.expectEqualStrings("0", info.Struct.fields[0].name);
    try std.testing.expect(@typeInfo(info.Struct.fields[0].type) == .Union);
}
