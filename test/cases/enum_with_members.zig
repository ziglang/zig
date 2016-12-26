const ET = enum {
    SINT: i32,
    UINT: u32,

    pub fn print(a: &ET, buf: []u8) -> %usize {
        return switch (*a) {
            ET.SINT => |x| { bufPrintInt(i32, buf, x) },
            ET.UINT => |x| { bufPrintInt(u32, buf, x) },
        }
    }
};

fn enumWithMembers() {
    @setFnTest(this);

    const a = ET.SINT { -42 };
    const b = ET.UINT { 42 };
    var buf: [20]u8 = undefined;

    assert(%%a.print(buf) == 3);
    assert(memeql(buf[0...3], "-42"));

    assert(%%b.print(buf) == 2);
    assert(memeql(buf[0...2], "42"));
}

// TODO all the below should be imported from std

const max_u64_base10_digits = 20;
pub fn bufPrintInt(inline T: type, out_buf: []u8, x: T) -> usize {
    if (T.is_signed) bufPrintSigned(T, out_buf, x) else bufPrintUnsigned(T, out_buf, x)
}

fn bufPrintSigned(inline T: type, out_buf: []u8, x: T) -> usize {
    const uint = @intType(false, T.bit_count);
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + bufPrintUnsigned(uint, out_buf[1...], uint(-(x + 1)) + 1);
    } else {
        return bufPrintUnsigned(uint, out_buf, uint(x));
    }
}

fn bufPrintUnsigned(inline T: type, out_buf: []u8, x: T) -> usize {
    var buf: [max_u64_base10_digits]u8 = undefined;
    var a = x;
    var index: usize = buf.len;

    while (true) {
        const digit = a % 10;
        index -= 1;
        buf[index] = '0' + u8(digit);
        a /= 10;
        if (a == 0)
            break;
    }

    const len = buf.len - index;

    @memcpy(&out_buf[0], &buf[index], len);

    return len;
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

// TODO import from std.str
pub fn memeql(a: []const u8, b: []const u8) -> bool {
    sliceEql(u8, a, b)
}

// TODO import from std.str
pub fn sliceEql(inline T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}
