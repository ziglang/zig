const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

const Frame = packed struct {
    num: u20,
};

const Entry = packed struct {
    other: u12,
    frame: Frame,
};

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const frame = Frame{ .num = 0x7FDE };
    var entry = Entry{ .other = 0, .frame = .{ .num = 0xFFFFF } };
    entry.frame = frame;
    try expect(entry.frame.num == 0x7FDE);
}
