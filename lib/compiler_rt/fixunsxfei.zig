const divCeil = @import("std").math.divCeil;
const common = @import("./common.zig");
const bigIntFromFloat = @import("./int_from_float.zig").bigIntFromFloat;

pub const panic = common.panic;

comptime {
    @export(&__fixunsxfei, .{ .name = "__fixunsxfei", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fixunsxfei(r: [*]u32, bits: usize, a: f80) callconv(.c) void {
    return bigIntFromFloat(.unsigned, r[0 .. divCeil(usize, bits, 32) catch unreachable], a);
}
