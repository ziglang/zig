const std = @import("std");
const builtin = @import("builtin");
const Type = std.builtin.Type;

test "Tuple" {
    const fields_list = fields(@TypeOf(.{}));
    if (fields_list.len != 0)
        @compileError("Argument count mismatch");
}

pub fn fields(comptime T: type) switch (@typeInfo(T)) {
    .Struct => []const Type.StructField,
    else => unreachable,
} {
    return switch (@typeInfo(T)) {
        .Struct => |info| info.fields,
        else => unreachable,
    };
}
