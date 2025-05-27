const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__subvsi3, .{ .name = "__subvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subvsi3(a: i32, b: i32) callconv(.c) i32 {
    // first allow overflow to panic with a reference to compiler-rt
    const sum: i32 = a -% b;
    if (b >= 0) {
        if (sum > a)
            @panic("compiler-rt: integer overflow");
    } else {
        if (sum <= a)
            @panic("compiler-rt: integer overflow");
    }
    return sum;
}
