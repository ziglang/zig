const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_fsub, .{ .name = "__aeabi_fsub", .linkage = common.linkage });
    } else {
        @export(__subsf3, .{ .name = "__subsf3", .linkage = common.linkage });
    }
}

fn __subsf3(a: f32, b: f32) callconv(.C) f32 {
    const neg_b = @bitCast(f32, @bitCast(u32, b) ^ (@as(u32, 1) << 31));
    return a + neg_b;
}

fn __aeabi_fsub(a: f32, b: f32) callconv(.AAPCS) f32 {
    const neg_b = @bitCast(f32, @bitCast(u32, b) ^ (@as(u32, 1) << 31));
    return a + neg_b;
}
