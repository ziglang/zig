const udivmod = @import("udivmod.zig").udivmod;
const builtin = @import("builtin");
const compiler_rt = @import("index.zig");

pub extern fn __divti3(a: i128, b: i128) i128 {
    @setRuntimeSafety(builtin.is_test);

    const s_a = a >> (i128.bit_count - 1);
    const s_b = b >> (i128.bit_count - 1);

    const an = (a ^ s_a) -% s_a;
    const bn = (b ^ s_b) -% s_b;

    const r = udivmod(u128, @bitCast(u128, an), @bitCast(u128, bn), null);
    const s = s_a ^ s_b;
    return (@bitCast(i128, r) ^ s) -% s;
}

pub extern fn __divti3_windows_x86_64(a: *const i128, b: *const i128) void {
    @setRuntimeSafety(builtin.is_test);
    compiler_rt.setXmm0(i128, __divti3(a.*, b.*));
}

test "import divti3" {
    _ = @import("divti3_test.zig");
}
