const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const bigIntFromFloat = @import("./int_from_float.zig").bigIntFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixunsdfei, .{ .name = "__fixunsdfei", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixunsdfei(r: [*]u32, bits: usize, a: f64) callconv(.c) void {
    return bigIntFromFloat(.unsigned, r[0 .. divCeil(usize, bits, 32) catch unreachable], a);
}
