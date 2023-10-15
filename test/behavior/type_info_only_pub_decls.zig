const builtin = @import("builtin");
const std = @import("std");
const other = struct {
    const std = @import("std");

    pub const Enum = enum {
        a,
        b,
        c,
    };

    pub const Struct = struct {
        foo: i32,
    };
};

test {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const ti = @typeInfo(other);
    const decls = ti.Struct.decls;

    try std.testing.expectEqual(2, decls.len);
    try std.testing.expectEqualStrings("Enum", decls[0].name);
    try std.testing.expectEqualStrings("Struct", decls[1].name);
}
