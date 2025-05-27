const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__subvdi3, .{ .name = "__subvdi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subvdi3(a: i64, b: i64) callconv(.c) i64 {
    // first allow overflow to panic with a reference to compiler-rt
    const sum: i64 = a -% b;
    if (b >= 0) {
        if (sum > a)
            @panic("compiler-rt: integer overflow");
    } else {
        if (sum <= a)
            @panic("compiler-rt: integer overflow");
    }
    return sum;
}
