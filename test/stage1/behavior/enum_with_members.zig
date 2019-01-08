const assertOrPanic = @import("std").debug.assertOrPanic;
const mem = @import("std").mem;
const fmt = @import("std").fmt;

const ET = union(enum) {
    SINT: i32,
    UINT: u32,

    pub fn print(a: *const ET, buf: []u8) anyerror!usize {
        return switch (a.*) {
            ET.SINT => |x| fmt.formatIntBuf(buf, x, 10, false, 0),
            ET.UINT => |x| fmt.formatIntBuf(buf, x, 10, false, 0),
        };
    }
};

test "enum with members" {
    const a = ET{ .SINT = -42 };
    const b = ET{ .UINT = 42 };
    var buf: [20]u8 = undefined;

    assertOrPanic((a.print(buf[0..]) catch unreachable) == 3);
    assertOrPanic(mem.eql(u8, buf[0..3], "-42"));

    assertOrPanic((b.print(buf[0..]) catch unreachable) == 2);
    assertOrPanic(mem.eql(u8, buf[0..2], "42"));
}
