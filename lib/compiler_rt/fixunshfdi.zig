const common = @import("./common.zig");
const intFromFloat = @import("./int_from_float.zig").intFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixunshfdi, .{ .name = "__fixunshfdi", .linkage = common.linkage, .visibility = common.visibility });
}

fn __fixunshfdi(a: f16) callconv(.C) u64 {
    return intFromFloat(u64, a);
}
