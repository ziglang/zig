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
