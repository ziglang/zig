const assert = @import("std").debug.assert;
const str = @import("std").str;
const io = @import("std").io;

const ET = enum {
    SINT: i32,
    UINT: u32,

    pub fn print(a: &ET, buf: []u8) -> %usize {
        return switch (*a) {
            ET.SINT => |x| { io.bufPrintInt(i32, buf, x) },
            ET.UINT => |x| { io.bufPrintInt(u32, buf, x) },
        }
    }
};

fn enumWithMembers() {
    @setFnTest(this);

    const a = ET.SINT { -42 };
    const b = ET.UINT { 42 };
    var buf: [20]u8 = undefined;

    assert(%%a.print(buf) == 3);
    assert(str.eql(buf[0...3], "-42"));

    assert(%%b.print(buf) == 2);
    assert(str.eql(buf[0...2], "42"));
}
