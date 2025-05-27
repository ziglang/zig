const mulv = @import("mulo.zig");
const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__mulvsi3, .{ .name = "__mulvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __mulvsi3(a: i32, b: i32) callconv(.c) i32 {
    var overflow: c_int = 0;
    const sum = mulv.__mulosi4(a, b, &overflow);
    if (overflow == 1) @panic("compiler-rt: integer overflow");
    return sum;
}
