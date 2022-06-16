const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    @export(__fixunsxfdi, .{ .name = "__fixunsxfdi", .linkage = common.linkage });
}

fn __fixunsxfdi(a: f80) callconv(.C) u64 {
    return floatToInt(u64, a);
}
