const common = @import("./common.zig");
const divc3 = @import("./divc3.zig");
const Complex = @import("./mulc3.zig").Complex;

comptime {
    @export(__divhc3, .{ .name = "__divhc3", .linkage = common.linkage });
}

pub fn __divhc3(a: f16, b: f16, c: f16, d: f16) callconv(.C) Complex(f16) {
    return divc3.divc3(f16, a, b, c, d);
}
