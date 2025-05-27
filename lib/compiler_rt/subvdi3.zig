const subv = @import("subo.zig");
const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__subvdi3, .{ .name = "__subvdi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subvdi3(a: i64, b: i64) callconv(.c) i64 {
    var overflow: c_int = 0;
    const sum = subv.__subodi4(a, b, &overflow);
    if (overflow == 1) @panic("compiler-rt: integer overflow");
    return sum;
}
