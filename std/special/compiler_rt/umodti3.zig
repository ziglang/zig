const udivmodti4 = @import("udivmodti4.zig");
const builtin = @import("builtin");
const compiler_rt = @import("index.zig");

pub extern fn __umodti3(a: u128, b: u128) u128 {
    @setRuntimeSafety(builtin.is_test);
    var r: u128 = undefined;
    _ = udivmodti4.__udivmodti4(a, b, &r);
    return r;
}

pub extern fn __umodti3_windows_x86_64(a: *const u128, b: *const u128) void {
    @setRuntimeSafety(builtin.is_test);
    compiler_rt.setXmm0(u128, __umodti3(a.*, b.*));
}
