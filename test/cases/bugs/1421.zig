const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const S = struct.{
    fn method() builtin.TypeInfo {
        return @typeInfo(S);
    }
};

test "functions with return type required to be comptime are generic" {
    const ti = S.method();
    assert(builtin.TypeId(ti) == builtin.TypeId.Struct);
}
