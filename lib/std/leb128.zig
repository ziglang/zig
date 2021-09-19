const std = @import("std");
const testing = std.testing;

/// Read a single unsigned LEB128 value from the given reader as type T,
/// or error.Overflow if the value cannot fit.
pub fn readULEB128(comptime T: type, reader: anytype) !T {
    const U = if (@typeInfo(T).Int.bits < 8) u8 else T;
    const ShiftT = std.math.Log2Int(U);

    const max_group = (@typeInfo(U).Int.bits + 6) / 7;

    var value = @as(U, 0);
    var group = @as(ShiftT, 0);

    while (group < max_group) : (group += 1) {
        const byte = try reader.readByte();
        var temp = @as(U, byte & 0x7f);

        if (@shlWithOverflow(U, temp, group * 7, &temp)) return error.Overflow;

        value |= temp;
        if (byte & 0x80 == 0) break;
    } else {
        return error.Overflow;
    }

    // only applies in the case that we extended to u8
    if (U != T) {
        if (value > std.math.maxInt(T)) return error.Overflow;
    }

    return @truncate(T, value);
}

/// Write a single unsigned integer as unsigned LEB128 to the given writer.
pub fn writeULEB128(writer: anytype, uint_value: anytype) !void {
    const T = @TypeOf(uint_value);
    const U = if (@typeInfo(T).Int.bits < 8) u8 else T;
    var value = @intCast(U, uint_value);

    while (true) {
        const byte = @truncate(u8, value & 0x7f);
        value >>= 7;
        if (value == 0) {
            try writer.writeByte(byte);
            break;
        } else {
            try writer.writeByte(byte | 0x80);
        }
    }
}

/// Read a single signed LEB128 value from the given reader as type T,
/// or error.Overflow if the value cannot fit.
pub fn readILEB128(comptime T: type, reader: anytype) !T {
    const S = if (@typeInfo(T).Int.bits < 8) i8 else T;
    const U = std.meta.Int(.unsigned, @typeInfo(S).Int.bits);
    const ShiftU = std.math.Log2Int(U);

    const max_group = (@typeInfo(U).Int.bits + 6) / 7;

    var value = @as(U, 0);
    var group = @as(ShiftU, 0);

    while (group < max_group) : (group += 1) {
        const byte = try reader.readByte();
        var temp = @as(U, byte & 0x7f);

        const shift = group * 7;
        if (@shlWithOverflow(U, temp, shift, &temp)) {
            // Overflow is ok so long as the sign bit is set and this is the last byte
            if (byte & 0x80 != 0) return error.Overflow;
            if (@bitCast(S, temp) >= 0) return error.Overflow;

            // and all the overflowed bits are 1
            const remaining_shift = @intCast(u3, @typeInfo(U).Int.bits - @as(u16, shift));
            const remaining_bits = @bitCast(i8, byte | 0x80) >> remaining_shift;
            if (remaining_bits != -1) return error.Overflow;
        } else {
            // If we don't overflow and this is the last byte and the number being decoded
            // is negative, check that the remaining bits are 1
            if ((byte & 0x80 == 0) and (@bitCast(S, temp) < 0)) {
                const remaining_shift = @intCast(u3, @typeInfo(U).Int.bits - @as(u16, shift));
                const remaining_bits = @bitCast(i8, byte | 0x80) >> remaining_shift;
                if (remaining_bits != -1) return error.Overflow;
            }
        }

        value |= temp;
        if (byte & 0x80 == 0) {
            const needs_sign_ext = group + 1 < max_group;
            if (byte & 0x40 != 0 and needs_sign_ext) {
                const ones = @as(S, -1);
                value |= @bitCast(U, ones) << (shift + 7);
            }
            break;
        }
    } else {
        return error.Overflow;
    }

    const result = @bitCast(S, value);
    // Only applies if we extended to i8
    if (S != T) {
        if (result > std.math.maxInt(T) or result < std.math.minInt(T)) return error.Overflow;
    }

    return @truncate(T, result);
}

/// Write a single signed integer as signed LEB128 to the given writer.
pub fn writeILEB128(writer: anytype, int_value: anytype) !void {
    const T = @TypeOf(int_value);
    const S = if (@typeInfo(T).Int.bits < 8) i8 else T;
    const U = std.meta.Int(.unsigned, @typeInfo(S).Int.bits);

    var value = @intCast(S, int_value);

    while (true) {
        const uvalue = @bitCast(U, value);
        const byte = @truncate(u8, uvalue);
        value >>= 6;
        if (value == -1 or value == 0) {
            try writer.writeByte(byte & 0x7F);
            break;
        } else {
            value >>= 1;
            try writer.writeByte(byte | 0x80);
        }
    }
}

/// This is an "advanced" function. It allows one to use a fixed amount of memory to store a
/// ULEB128. This defeats the entire purpose of using this data encoding; it will no longer use
/// fewer bytes to store smaller numbers. The advantage of using a fixed width is that it makes
/// fields have a predictable size and so depending on the use case this tradeoff can be worthwhile.
/// An example use case of this is in emitting DWARF info where one wants to make a ULEB128 field
/// "relocatable", meaning that it becomes possible to later go back and patch the number to be a
/// different value without shifting all the following code.
pub fn writeUnsignedFixed(comptime l: usize, ptr: *[l]u8, int: std.meta.Int(.unsigned, l * 7)) void {
    const T = @TypeOf(int);
    const U = if (@typeInfo(T).Int.bits < 8) u8 else T;
    var value = @intCast(U, int);

    comptime var i = 0;
    inline while (i < (l - 1)) : (i += 1) {
        const byte = @truncate(u8, value) | 0b1000_0000;
        value >>= 7;
        ptr[i] = byte;
    }
    ptr[i] = @truncate(u8, value);
}

test "writeUnsignedFixed" {
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 0);
        try testing.expect((try test_read_uleb128(u64, &buf)) == 0);
    }
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 1);
        try testing.expect((try test_read_uleb128(u64, &buf)) == 1);
    }
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 1000);
        try testing.expect((try test_read_uleb128(u64, &buf)) == 1000);
    }
    {
        var buf: [4]u8 = undefined;
        writeUnsignedFixed(4, &buf, 10000000);
        try testing.expect((try test_read_uleb128(u64, &buf)) == 10000000);
    }
}

// tests
fn test_read_stream_ileb128(comptime T: type, encoded: []const u8) !T {
    var reader = std.io.fixedBufferStream(encoded);
    return try readILEB128(T, reader.reader());
}

fn test_read_stream_uleb128(comptime T: type, encoded: []const u8) !T {
    var reader = std.io.fixedBufferStream(encoded);
    return try readULEB128(T, reader.reader());
}

fn test_read_ileb128(comptime T: type, encoded: []const u8) !T {
    var reader = std.io.fixedBufferStream(encoded);
    const v1 = try readILEB128(T, reader.reader());
    return v1;
}

fn test_read_uleb128(comptime T: type, encoded: []const u8) !T {
    var reader = std.io.fixedBufferStream(encoded);
    const v1 = try readULEB128(T, reader.reader());
    return v1;
}

fn test_read_ileb128_seq(comptime T: type, comptime N: usize, encoded: []const u8) !void {
    var reader = std.io.fixedBufferStream(encoded);
    var i: usize = 0;
    while (i < N) : (i += 1) {
        _ = try readILEB128(T, reader.reader());
    }
}

fn test_read_uleb128_seq(comptime T: type, comptime N: usize, encoded: []const u8) !void {
    var reader = std.io.fixedBufferStream(encoded);
    var i: usize = 0;
    while (i < N) : (i += 1) {
        _ = try readULEB128(T, reader.reader());
    }
}

test "deserialize signed LEB128" {
    // Truncated
    try testing.expectError(error.EndOfStream, test_read_stream_ileb128(i64, "\x80"));

    // Overflow
    try testing.expectError(error.Overflow, test_read_ileb128(i8, "\x80\x80\x40"));
    try testing.expectError(error.Overflow, test_read_ileb128(i16, "\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, test_read_ileb128(i32, "\x80\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, test_read_ileb128(i8, "\xff\x7e"));
    try testing.expectError(error.Overflow, test_read_ileb128(i32, "\x80\x80\x80\x80\x08"));
    try testing.expectError(error.Overflow, test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x01"));

    // Decode SLEB128
    try testing.expect((try test_read_ileb128(i64, "\x00")) == 0);
    try testing.expect((try test_read_ileb128(i64, "\x01")) == 1);
    try testing.expect((try test_read_ileb128(i64, "\x3f")) == 63);
    try testing.expect((try test_read_ileb128(i64, "\x40")) == -64);
    try testing.expect((try test_read_ileb128(i64, "\x41")) == -63);
    try testing.expect((try test_read_ileb128(i64, "\x7f")) == -1);
    try testing.expect((try test_read_ileb128(i64, "\x80\x01")) == 128);
    try testing.expect((try test_read_ileb128(i64, "\x81\x01")) == 129);
    try testing.expect((try test_read_ileb128(i64, "\xff\x7e")) == -129);
    try testing.expect((try test_read_ileb128(i64, "\x80\x7f")) == -128);
    try testing.expect((try test_read_ileb128(i64, "\x81\x7f")) == -127);
    try testing.expect((try test_read_ileb128(i64, "\xc0\x00")) == 64);
    try testing.expect((try test_read_ileb128(i64, "\xc7\x9f\x7f")) == -12345);
    try testing.expect((try test_read_ileb128(i8, "\xff\x7f")) == -1);
    try testing.expect((try test_read_ileb128(i16, "\xff\xff\x7f")) == -1);
    try testing.expect((try test_read_ileb128(i32, "\xff\xff\xff\xff\x7f")) == -1);
    try testing.expect((try test_read_ileb128(i32, "\x80\x80\x80\x80\x78")) == -0x80000000);
    try testing.expect((try test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f")) == @bitCast(i64, @intCast(u64, 0x8000000000000000)));
    try testing.expect((try test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x40")) == -0x4000000000000000);
    try testing.expect((try test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f")) == -0x8000000000000000);

    // Decode unnormalized SLEB128 with extra padding bytes.
    try testing.expect((try test_read_ileb128(i64, "\x80\x00")) == 0);
    try testing.expect((try test_read_ileb128(i64, "\x80\x80\x00")) == 0);
    try testing.expect((try test_read_ileb128(i64, "\xff\x00")) == 0x7f);
    try testing.expect((try test_read_ileb128(i64, "\xff\x80\x00")) == 0x7f);
    try testing.expect((try test_read_ileb128(i64, "\x80\x81\x00")) == 0x80);
    try testing.expect((try test_read_ileb128(i64, "\x80\x81\x80\x00")) == 0x80);

    // Decode sequence of SLEB128 values
    try test_read_ileb128_seq(i64, 4, "\x81\x01\x3f\x80\x7f\x80\x80\x80\x00");
}

test "deserialize unsigned LEB128" {
    // Truncated
    try testing.expectError(error.EndOfStream, test_read_stream_uleb128(u64, "\x80"));

    // Overflow
    try testing.expectError(error.Overflow, test_read_uleb128(u8, "\x80\x02"));
    try testing.expectError(error.Overflow, test_read_uleb128(u8, "\x80\x80\x40"));
    try testing.expectError(error.Overflow, test_read_uleb128(u16, "\x80\x80\x84"));
    try testing.expectError(error.Overflow, test_read_uleb128(u16, "\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, test_read_uleb128(u32, "\x80\x80\x80\x80\x90"));
    try testing.expectError(error.Overflow, test_read_uleb128(u32, "\x80\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, test_read_uleb128(u64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x40"));

    // Decode ULEB128
    try testing.expect((try test_read_uleb128(u64, "\x00")) == 0);
    try testing.expect((try test_read_uleb128(u64, "\x01")) == 1);
    try testing.expect((try test_read_uleb128(u64, "\x3f")) == 63);
    try testing.expect((try test_read_uleb128(u64, "\x40")) == 64);
    try testing.expect((try test_read_uleb128(u64, "\x7f")) == 0x7f);
    try testing.expect((try test_read_uleb128(u64, "\x80\x01")) == 0x80);
    try testing.expect((try test_read_uleb128(u64, "\x81\x01")) == 0x81);
    try testing.expect((try test_read_uleb128(u64, "\x90\x01")) == 0x90);
    try testing.expect((try test_read_uleb128(u64, "\xff\x01")) == 0xff);
    try testing.expect((try test_read_uleb128(u64, "\x80\x02")) == 0x100);
    try testing.expect((try test_read_uleb128(u64, "\x81\x02")) == 0x101);
    try testing.expect((try test_read_uleb128(u64, "\x80\xc1\x80\x80\x10")) == 4294975616);
    try testing.expect((try test_read_uleb128(u64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x01")) == 0x8000000000000000);

    // Decode ULEB128 with extra padding bytes
    try testing.expect((try test_read_uleb128(u64, "\x80\x00")) == 0);
    try testing.expect((try test_read_uleb128(u64, "\x80\x80\x00")) == 0);
    try testing.expect((try test_read_uleb128(u64, "\xff\x00")) == 0x7f);
    try testing.expect((try test_read_uleb128(u64, "\xff\x80\x00")) == 0x7f);
    try testing.expect((try test_read_uleb128(u64, "\x80\x81\x00")) == 0x80);
    try testing.expect((try test_read_uleb128(u64, "\x80\x81\x80\x00")) == 0x80);

    // Decode sequence of ULEB128 values
    try test_read_uleb128_seq(u64, 4, "\x81\x01\x3f\x80\x7f\x80\x80\x80\x00");
}

fn test_write_leb128(value: anytype) !void {
    const T = @TypeOf(value);
    const signedness = @typeInfo(T).Int.signedness;
    const t_signed = signedness == .signed;

    const writeStream = if (t_signed) writeILEB128 else writeULEB128;
    const readStream = if (t_signed) readILEB128 else readULEB128;

    // decode to a larger bit size too, to ensure sign extension
    // is working as expected
    const larger_type_bits = ((@typeInfo(T).Int.bits + 8) / 8) * 8;
    const B = std.meta.Int(signedness, larger_type_bits);

    const bytes_needed = bn: {
        if (@typeInfo(T).Int.bits <= 7) break :bn @as(u16, 1);

        const unused_bits = if (value < 0) @clz(T, ~value) else @clz(T, value);
        const used_bits: u16 = (@typeInfo(T).Int.bits - unused_bits) + @boolToInt(t_signed);
        if (used_bits <= 7) break :bn @as(u16, 1);
        break :bn ((used_bits + 6) / 7);
    };

    const max_groups = if (@typeInfo(T).Int.bits == 0) 1 else (@typeInfo(T).Int.bits + 6) / 7;

    var buf: [max_groups]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    // stream write
    try writeStream(fbs.writer(), value);
    const w1_pos = fbs.pos;
    try testing.expect(w1_pos == bytes_needed);

    // stream read
    fbs.pos = 0;
    const sr = try readStream(T, fbs.reader());
    try testing.expect(fbs.pos == w1_pos);
    try testing.expect(sr == value);

    // bigger type stream read
    fbs.pos = 0;
    const bsr = try readStream(B, fbs.reader());
    try testing.expect(fbs.pos == w1_pos);
    try testing.expect(bsr == value);
}

test "serialize unsigned LEB128" {
    const max_bits = 18;

    comptime var t = 0;
    inline while (t <= max_bits) : (t += 1) {
        const T = std.meta.Int(.unsigned, t);
        const min = std.math.minInt(T);
        const max = std.math.maxInt(T);
        var i = @as(std.meta.Int(.unsigned, @typeInfo(T).Int.bits + 1), min);

        while (i <= max) : (i += 1) try test_write_leb128(@intCast(T, i));
    }
}

test "serialize signed LEB128" {
    // explicitly test i0 because starting `t` at 0
    // will break the while loop
    try test_write_leb128(@as(i0, 0));

    const max_bits = 18;

    comptime var t = 1;
    inline while (t <= max_bits) : (t += 1) {
        const T = std.meta.Int(.signed, t);
        const min = std.math.minInt(T);
        const max = std.math.maxInt(T);
        var i = @as(std.meta.Int(.signed, @typeInfo(T).Int.bits + 1), min);

        while (i <= max) : (i += 1) try test_write_leb128(@intCast(T, i));
    }
}
