const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const bigIntFromFloat = @import("./int_from_float.zig").bigIntFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixhfei, .{ .name = "__fixhfei", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixhfei(r: [*]u32, bits: usize, a: f16) callconv(.c) void {
    return bigIntFromFloat(.signed, r[0 .. divCeil(usize, bits, 32) catch unreachable], a);
}
