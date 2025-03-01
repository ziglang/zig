const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const bigIntFromFloat = @import("./int_from_float.zig").bigIntFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixunshfei, .{ .name = "__fixunshfei", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixunshfei(r: [*]u32, bits: usize, a: f16) callconv(.c) void {
    return bigIntFromFloat(.unsigned, r[0 .. divCeil(usize, bits, 32) catch unreachable], a);
}
