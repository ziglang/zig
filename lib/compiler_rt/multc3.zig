const common = @import("./common.zig");
const mulc3 = @import("./mulc3.zig");

pub const panic = common.panic;

comptime {
    if (@import("builtin").zig_backend != .stage2_c) {
        @export(__multc3, .{ .name = "__multc3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __multc3(a: f128, b: f128, c: f128, d: f128) callconv(.C) mulc3.Complex(f128) {
    return mulc3.mulc3(f128, a, b, c, d);
}
