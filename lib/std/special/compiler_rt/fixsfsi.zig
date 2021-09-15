const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixsfsi(a: f32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i32, a);
}

pub fn __aeabi_f2iz(a: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixsfsi, .{a});
}

test {
    _ = @import("fixsfsi_test.zig");
}
