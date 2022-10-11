const common = @import("./common.zig");
const mulc3 = @import("./mulc3.zig");

pub const panic = common.panic;

comptime {
    @export(__muldc3, .{ .name = "__muldc3", .linkage = common.linkage });
}

pub fn __muldc3(a: f64, b: f64, c: f64, d: f64) callconv(.C) mulc3.Complex(f64) {
    return mulc3.mulc3(f64, a, b, c, d);
}
