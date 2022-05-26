const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

const S = struct {
    fn method() std.builtin.Type {
        return @typeInfo(S);
    }
};

test "functions with return type required to be comptime are generic" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    const ti = S.method();
    try expect(@as(std.builtin.TypeId, ti) == std.builtin.TypeId.Struct);
}
