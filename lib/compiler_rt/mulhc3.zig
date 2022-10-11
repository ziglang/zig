const common = @import("./common.zig");
const mulc3 = @import("./mulc3.zig");

pub const panic = common.panic;

comptime {
    @export(__mulhc3, .{ .name = "__mulhc3", .linkage = common.linkage });
}

pub fn __mulhc3(a: f16, b: f16, c: f16, d: f16) callconv(.C) mulc3.Complex(f16) {
    return mulc3.mulc3(f16, a, b, c, d);
}
