const common = @import("./common.zig");
const mulc3 = @import("./mulc3.zig");

pub const panic = common.panic;

comptime {
    if (@import("builtin").zig_backend != .stage2_c) {
        @export(__mulsc3, .{ .name = "__mulsc3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __mulsc3(a: f32, b: f32, c: f32, d: f32) callconv(.C) mulc3.Complex(f32) {
    return mulc3.mulc3(f32, a, b, c, d);
}
