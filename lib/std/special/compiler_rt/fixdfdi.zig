const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixdfdi(a: f64) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f64, i64, a);
}

pub fn __aeabi_d2lz(arg: f64) callconv(.AAPCS) i64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixdfdi, .{arg});
}

test {
    _ = @import("fixdfdi_test.zig");
}
