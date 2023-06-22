const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const fmt = std.fmt;

const ET = union(enum) {
    SINT: i32,
    UINT: u32,

    pub fn print(a: *const ET, buf: []u8) anyerror!usize {
        return switch (a.*) {
            ET.SINT => |x| fmt.formatIntBuf(buf, x, 10, .lower, fmt.FormatOptions{}),
            ET.UINT => |x| fmt.formatIntBuf(buf, x, 10, .lower, fmt.FormatOptions{}),
        };
    }
};

test "enum with members" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const a = ET{ .SINT = -42 };
    const b = ET{ .UINT = 42 };
    var buf: [20]u8 = undefined;

    try expect((a.print(buf[0..]) catch unreachable) == 3);
    try expect(mem.eql(u8, buf[0..3], "-42"));

    try expect((b.print(buf[0..]) catch unreachable) == 2);
    try expect(mem.eql(u8, buf[0..2], "42"));
}
