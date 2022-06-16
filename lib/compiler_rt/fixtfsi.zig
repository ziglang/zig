const common = @import("./common.zig");
const floatToInt = @import("./float_to_int.zig").floatToInt;

pub const panic = common.panic;

comptime {
    if (common.want_ppc_abi) {
        @export(__fixkfsi, .{ .name = "__fixkfsi", .linkage = common.linkage });
    } else {
        @export(__fixtfsi, .{ .name = "__fixtfsi", .linkage = common.linkage });
    }
}

fn __fixtfsi(a: f128) callconv(.C) i32 {
    return floatToInt(i32, a);
}

fn __fixkfsi(a: f128) callconv(.C) i32 {
    return floatToInt(i32, a);
}
