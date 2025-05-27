const subv = @import("subo.zig");
const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__subvsi3, .{ .name = "__subvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subvsi3(a: i32, b: i32) callconv(.c) i32 {
    var overflow: c_int = 0;
    const sum = subv.__subosi4(a, b, &overflow);
    if (overflow == 1) @panic("compiler-rt: integer overflow");
    return sum;
}
