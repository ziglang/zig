const builtin = @import("builtin");

var buf: []u8 = undefined;

test "reslice of undefined global var slice" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var mem: [100]u8 = [_]u8{0} ** 100;
    buf = &mem;
    const x = buf[0..1];
    try @import("std").testing.expect(x.len == 1 and x[0] == 0);
}
