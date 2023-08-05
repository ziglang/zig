const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "sentinel-terminated 0-length slices" {
    if (builtin.zig_backend == .zsf_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_spirv64) return error.SkipZigTest;

    var u32s: [4]u32 = [_]u32{ 0, 1, 2, 3 };

    var index: u8 = 2;
    var slice = u32s[index..index :2];
    var array_ptr = u32s[2..2 :2];
    const comptime_known_array_value = u32s[2..2 :2].*;
    var runtime_array_value = u32s[2..2 :2].*;

    try expect(slice[0] == 2);
    try expect(array_ptr[0] == 2);
    try expect(comptime_known_array_value[0] == 2);
    try expect(runtime_array_value[0] == 2);
}
