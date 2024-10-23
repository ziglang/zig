const common = @import("./common.zig");
const addf3 = @import("./addf3.zig").addf3;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_fadd, .{ .name = "__aeabi_fadd", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__addsf3, .{ .name = "__addsf3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn __addsf3(a: f32, b: f32) callconv(.C) f32 {
    return addf3(f32, a, b);
}

fn __aeabi_fadd(a: f32, b: f32) callconv(.AAPCS) f32 {
    return addf3(f32, a, b);
}
