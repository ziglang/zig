const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const S = struct {
    fn method() builtin.TypeInfo {
        return @typeInfo(S);
    }
};

test "functions with return type required to be comptime are generic" {
    const ti = S.method();
    try expect(@as(builtin.TypeId, ti) == builtin.TypeId.Struct);
}
