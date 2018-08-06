const udivmodti4 = @import("udivmodti4.zig");
const builtin = @import("builtin");

pub extern fn __udivti3(a: u128, b: u128) u128 {
    @setRuntimeSafety(builtin.is_test);
    return udivmodti4.__udivmodti4(a, b, null);
}

pub extern fn __udivti3_windows_x86_64(a: *const u128, b: *const u128) void {
    @setRuntimeSafety(builtin.is_test);
    udivmodti4.__udivmodti4_windows_x86_64(a, b, null);
}
