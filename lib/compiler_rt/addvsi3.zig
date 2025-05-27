const addv = @import("addo.zig");
const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__addvsi3, .{ .name = "__addvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __addvsi3(a: i32, b: i32) callconv(.c) i32 {
    var overflow: c_int = 0;
    const sum = addv.__addosi4(a, b, &overflow);
    if (overflow == 1) @panic("compiler-rt: integer overflow");
    return sum;
}
