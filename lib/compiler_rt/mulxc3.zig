const common = @import("./common.zig");
const mulc3 = @import("./mulc3.zig");

pub const panic = common.panic;

comptime {
    if (@import("builtin").zig_backend != .stage2_c) {
        @export(__mulxc3, .{ .name = "__mulxc3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __mulxc3(a: f80, b: f80, c: f80, d: f80) callconv(.C) mulc3.Complex(f80) {
    return mulc3.mulc3(f80, a, b, c, d);
}
