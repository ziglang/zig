const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;

/// This is an "advanced" function. It allows one to use a fixed amount of memory to store a
/// ULEB128. This defeats the entire purpose of using this data encoding; it will no longer use
/// fewer bytes to store smaller numbers. The advantage of using a fixed width is that it makes
/// fields have a predictable size and so depending on the use case this tradeoff can be worthwhile.
/// An example use case of this is in emitting DWARF info where one wants to make a ULEB128 field
/// "relocatable", meaning that it becomes possible to later go back and patch the number to be a
/// different value without shifting all the following code.
pub fn writeUnsignedFixed(comptime l: usize, ptr: *[l]u8, int: std.meta.Int(.unsigned, l * 7)) void {
    writeUnsignedExtended(ptr, int);
}

/// Same as `writeUnsignedFixed` but with a runtime-known length.
/// Asserts `slice.len > 0`.
pub fn writeUnsignedExtended(slice: []u8, arg: anytype) void {
    const Arg = @TypeOf(arg);
    const Int = switch (Arg) {
        comptime_int => std.math.IntFittingRange(arg, arg),
        else => Arg,
    };
    const Value = if (@typeInfo(Int).int.bits < 8) u8 else Int;
    var value: Value = arg;

    for (slice[0 .. slice.len - 1]) |*byte| {
        byte.* = @truncate(0x80 | value);
        value >>= 7;
    }
    slice[slice.len - 1] = @as(u7, @intCast(value));
}

test writeUnsignedFixed {
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 0);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(0, try reader.takeLeb128(u64));
    }
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 1);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(1, try reader.takeLeb128(u64));
    }
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 1000);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(1000, try reader.takeLeb128(u64));
    }
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 10000000);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(10000000, try reader.takeLeb128(u64));
    }
}

/// This is an "advanced" function. It allows one to use a fixed amount of memory to store an
/// ILEB128. This defeats the entire purpose of using this data encoding; it will no longer use
/// fewer bytes to store smaller numbers. The advantage of using a fixed width is that it makes
/// fields have a predictable size and so depending on the use case this tradeoff can be worthwhile.
/// An example use case of this is in emitting DWARF info where one wants to make a ILEB128 field
/// "relocatable", meaning that it becomes possible to later go back and patch the number to be a
/// different value without shifting all the following code.
pub fn writeSignedFixed(comptime l: usize, ptr: *[l]u8, int: std.meta.Int(.signed, l * 7)) void {
    const T = @TypeOf(int);
    const U = if (@typeInfo(T).int.bits < 8) u8 else T;
    var value: U = @intCast(int);

    comptime var i = 0;
    inline while (i < (l - 1)) : (i += 1) {
        const byte: u8 = @bitCast(@as(i8, @truncate(value)) | -0b1000_0000);
        value >>= 7;
        ptr[i] = byte;
    }
    ptr[i] = @as(u7, @bitCast(@as(i7, @truncate(value))));
}

test writeSignedFixed {
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, 0);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(0, try reader.takeLeb128(i64));
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, 1);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(1, try reader.takeLeb128(i64));
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, -1);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(-1, try reader.takeLeb128(i64));
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, 1000);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(1000, try reader.takeLeb128(i64));
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, -1000);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(-1000, try reader.takeLeb128(i64));
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, -10000000);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(-10000000, try reader.takeLeb128(i64));
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, 10000000);
        var reader: std.Io.Reader = .fixed(&buf);
        try testing.expectEqual(10000000, try reader.takeLeb128(i64));
    }
}
