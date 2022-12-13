const std = @import("std");
const builtin = std.builtin;
const expect = std.testing.expect;

const info = .{
    .args = [_]builtin.Type.Error{
        .{ .name = "bar" },
    },
};
const Foo = @Type(.{
    .ErrorSet = &info.args,
});
test "ErrorSet comptime_field_ptr" {
    try expect(Foo == error{bar});
}

const fn_info = .{
    .args = [_]builtin.Type.Fn.Param{
        .{ .is_generic = false, .is_noalias = false, .type = u8 },
    },
};
const Bar = @Type(.{
    .Fn = .{
        .calling_convention = .Unspecified,
        .alignment = 0,
        .is_generic = false,
        .is_var_args = false,
        .return_type = void,
        .args = &fn_info.args,
    },
});
test "fn comptime_field_ptr" {
    try expect(@typeInfo(Bar) == .Fn);
}
