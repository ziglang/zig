const std = @import("std");
const builtin = @import("builtin");

const Fields = packed struct {
    timestamp: u50,
    random_bits: u13,
};
const ID = packed union {
    value: u63,
    fields: Fields,
};
fn value() i64 {
    return 1341;
}
test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const timestamp: i64 = value();
    const id = ID{ .fields = Fields{
        .timestamp = @intCast(u50, timestamp),
        .random_bits = 420,
    } };
    try std.testing.expect((ID{ .value = id.value }).fields.timestamp == timestamp);
}
