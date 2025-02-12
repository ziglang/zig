const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const bigIntFromFloat = @import("./int_from_float.zig").bigIntFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixtfei, .{ .name = "__fixtfei", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixtfei(r: [*]u32, bits: usize, a: f128) callconv(.c) void {
    return bigIntFromFloat(.signed, r[0 .. divCeil(usize, bits, 32) catch unreachable], a);
}
