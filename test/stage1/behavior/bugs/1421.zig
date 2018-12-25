const std = @import("std");
const builtin = @import("builtin");
const assertOrPanic = std.debug.assertOrPanic;

const S = struct {
    fn method() builtin.TypeInfo {
        return @typeInfo(S);
    }
};

test "functions with return type required to be comptime are generic" {
    const ti = S.method();
    assertOrPanic(builtin.TypeId(ti) == builtin.TypeId.Struct);
}
