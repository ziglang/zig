const udivmodti4 = @import("udivmodti4.zig");
const builtin = @import("builtin");

pub extern fn __udivti3(a: u128, b: u128) u128 {
    @setRuntimeSafety(builtin.is_test);
    return udivmodti4.__udivmodti4(a, b, null);
}

const v128 = @Vector(2, u64);
pub extern fn __udivti3_windows_x86_64(a: v128, b: v128) v128 {
    @setRuntimeSafety(builtin.is_test);
    return udivmodti4.__udivmodti4_windows_x86_64(a, b, null);
}
