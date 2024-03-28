const common = @import("common.zig");
const divsf3 = @import("./divsf3.zig");

comptime {
    @export(&__divhf3, .{ .name = "__divhf3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __divhf3(a: f16, b: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(divsf3.__divsf3(a, b));
}
