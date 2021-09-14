const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunssfsi(a: f32) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f32, u32, a);
}

pub fn __aeabi_f2uiz(a: f32) callconv(.AAPCS) u32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixunssfsi, .{a});
}

test {
    _ = @import("fixunssfsi_test.zig");
}
