const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(__aeabi_fsub, .{ .name = "__aeabi_fsub", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__subsf3, .{ .name = "__subsf3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn __subsf3(a: f32, b: f32) callconv(.C) f32 {
    return sub(a, b);
}

fn __aeabi_fsub(a: f32, b: f32) callconv(.AAPCS) f32 {
    return sub(a, b);
}

inline fn sub(a: f32, b: f32) f32 {
    const neg_b = @as(f32, @bitCast(@as(u32, @bitCast(b)) ^ (@as(u32, 1) << 31)));
    return addf3(f32, a, neg_b);
}
