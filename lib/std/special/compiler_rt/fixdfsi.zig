const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixdfsi(a: f64) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f64, i32, a);
}

pub fn __aeabi_d2iz(a: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixdfsi, .{a});
}

test {
    _ = @import("fixdfsi_test.zig");
}
