const common = @import("./common.zig");
const divc3 = @import("./divc3.zig");
const Complex = @import("./mulc3.zig").Complex;

comptime {
    if (@import("builtin").zig_backend != .stage2_c) {
        @export(&__divdc3, .{ .name = "__divdc3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __divdc3(a: f64, b: f64, c: f64, d: f64) callconv(.C) Complex(f64) {
    return divc3.divc3(f64, a, b, c, d);
}
