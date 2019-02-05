const builtin = @import("builtin");
const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

test "reinterpret bytes as integer with nonzero offset" {
    testReinterpretBytesAsInteger();
    comptime testReinterpretBytesAsInteger();
}

fn testReinterpretBytesAsInteger() void {
    const bytes = "\x12\x34\x56\x78\xab";
    const expected = switch (builtin.endian) {
        builtin.Endian.Little => 0xab785634,
        builtin.Endian.Big => 0x345678ab,
    };
    assertOrPanic(@ptrCast(*align(1) const u32, bytes[1..5].ptr).* == expected);
}

test "reinterpret bytes of an array into an extern struct" {
    testReinterpretBytesAsExternStruct();
    comptime testReinterpretBytesAsExternStruct();
}

fn testReinterpretBytesAsExternStruct() void {
    var bytes align(2) = []u8{ 1, 2, 3, 4, 5, 6 };

    const S = extern struct {
        a: u8,
        b: u16,
        c: u8,
    };

    var ptr = @ptrCast(*const S, &bytes);
    var val = ptr.c;
    assertOrPanic(val == 5);
}

test "reinterpret struct field at comptime" {
    const numLittle = comptime Bytes.init(0x12345678);
    assertOrPanic(std.mem.eql(u8, []u8{ 0x78, 0x56, 0x34, 0x12 }, numLittle.bytes));
}

const Bytes = struct {
    bytes: [4]u8,

    pub fn init(v: u32) Bytes {
        var res: Bytes = undefined;
        @ptrCast(*align(1) u32, &res.bytes).* = v;

        return res;
    }
};
