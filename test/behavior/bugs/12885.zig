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
