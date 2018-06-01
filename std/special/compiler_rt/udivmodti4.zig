const udivmod = @import("udivmod.zig").udivmod;
const builtin = @import("builtin");
const compiler_rt = @import("index.zig");

pub extern fn __udivmodti4(a: u128, b: u128, maybe_rem: ?*u128) u128 {
    @setRuntimeSafety(builtin.is_test);
    return udivmod(u128, a, b, maybe_rem);
}

pub extern fn __udivmodti4_windows_x86_64(a: *const u128, b: *const u128, maybe_rem: ?*u128) void {
    @setRuntimeSafety(builtin.is_test);
    compiler_rt.setXmm0(u128, udivmod(u128, a.*, b.*, maybe_rem));
}

test "import udivmodti4" {
    _ = @import("udivmodti4_test.zig");
}
