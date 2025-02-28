const common = @import("./common.zig");
const divc3 = @import("./divc3.zig");
const Complex = @import("./mulc3.zig").Complex;

comptime {
    if (@import("builtin").zig_backend != .stage2_c) {
        @export(&__divhc3, .{ .name = "__divhc3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __divhc3(a: f16, b: f16, c: f16, d: f16) callconv(.C) Complex(f16) {
    return divc3.divc3(f16, a, b, c, d);
}
