const common = @import("./common.zig");
const divc3 = @import("./divc3.zig");
const Complex = @import("./mulc3.zig").Complex;

comptime {
    @export(__divtc3, .{ .name = "__divtc3", .linkage = common.linkage });
}

pub fn __divtc3(a: f128, b: f128, c: f128, d: f128) callconv(.C) Complex(f128) {
    return divc3.divc3(f128, a, b, c, d);
}
