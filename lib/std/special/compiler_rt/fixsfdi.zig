const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixsfdi(a: f32) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i64, a);
}

pub fn __aeabi_f2lz(arg: f32) callconv(.AAPCS) i64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixsfdi, .{arg});
}

test {
    _ = @import("fixsfdi_test.zig");
}
