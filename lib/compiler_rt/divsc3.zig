const common = @import("./common.zig");
const divc3 = @import("./divc3.zig");
const Complex = @import("./mulc3.zig").Complex;

comptime {
    if (@import("builtin").zig_backend != .stage2_c) {
        @export(&__divsc3, .{ .name = "__divsc3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __divsc3(a: f32, b: f32, c: f32, d: f32) callconv(.C) Complex(f32) {
    return divc3.divc3(f32, a, b, c, d);
}
