const std = @import("std");
const testing = std.testing;

pub fn readULEB128(comptime T: type, in_stream: var) !T {
    const ShiftT = std.meta.Int(false, std.math.log2(T.bit_count));

    var result: T = 0;
    var shift: usize = 0;

    while (true) {
        const byte = try in_stream.readByte();

        if (shift > T.bit_count)
            return error.Overflow;

        var operand: T = undefined;
        if (@shlWithOverflow(T, byte & 0x7f, @intCast(ShiftT, shift), &operand))
            return error.Overflow;

        result |= operand;

        if ((byte & 0x80) == 0)
            return result;

        shift += 7;
    }
}

pub fn readULEB128Mem(comptime T: type, ptr: *[*]const u8) !T {
    const ShiftT = std.meta.Int(false, std.math.log2(T.bit_count));

    var result: T = 0;
    var shift: usize = 0;
    var i: usize = 0;

    while (true) : (i += 1) {
        const byte = ptr.*[i];

        if (shift > T.bit_count)
            return error.Overflow;

        var operand: T = undefined;
        if (@shlWithOverflow(T, byte & 0x7f, @intCast(ShiftT, shift), &operand))
            return error.Overflow;

        result |= operand;

        if ((byte & 0x80) == 0) {
            ptr.* += i + 1;
            return result;
        }

        shift += 7;
    }
}

pub fn readILEB128(comptime T: type, in_stream: var) !T {
    const UT = std.meta.Int(false, T.bit_count);
    const ShiftT = std.meta.Int(false, std.math.log2(T.bit_count));

    var result: UT = 0;
    var shift: usize = 0;

    while (true) {
        const byte: u8 = try in_stream.readByte();

        if (shift > T.bit_count)
            return error.Overflow;

        var operand: UT = undefined;
        if (@shlWithOverflow(UT, @as(UT, byte & 0x7f), @intCast(ShiftT, shift), &operand)) {
            if (byte != 0x7f)
                return error.Overflow;
        }

        result |= operand;

        shift += 7;

        if ((byte & 0x80) == 0) {
            if (shift < T.bit_count and (byte & 0x40) != 0) {
                result |= @bitCast(UT, @intCast(T, -1)) << @intCast(ShiftT, shift);
            }
            return @bitCast(T, result);
        }
    }
}

pub fn readILEB128Mem(comptime T: type, ptr: *[*]const u8) !T {
    const UT = std.meta.Int(false, T.bit_count);
    const ShiftT = std.meta.Int(false, std.math.log2(T.bit_count));

    var result: UT = 0;
    var shift: usize = 0;
    var i: usize = 0;

    while (true) : (i += 1) {
        const byte = ptr.*[i];

        if (shift > T.bit_count)
            return error.Overflow;

        var operand: UT = undefined;
        if (@shlWithOverflow(UT, @as(UT, byte & 0x7f), @intCast(ShiftT, shift), &operand)) {
            if (byte != 0x7f)
                return error.Overflow;
        }

        result |= operand;

        shift += 7;

        if ((byte & 0x80) == 0) {
            if (shift < T.bit_count and (byte & 0x40) != 0) {
                result |= @bitCast(UT, @intCast(T, -1)) << @intCast(ShiftT, shift);
            }
            ptr.* += i + 1;
            return @bitCast(T, result);
        }
    }
}

fn test_read_stream_ileb128(comptime T: type, encoded: []const u8) !T {
    var in_stream = std.io.fixedBufferStream(encoded);
    return try readILEB128(T, in_stream.inStream());
}

fn test_read_stream_uleb128(comptime T: type, encoded: []const u8) !T {
    var in_stream = std.io.fixedBufferStream(encoded);
    return try readULEB128(T, in_stream.inStream());
}

fn test_read_ileb128(comptime T: type, encoded: []const u8) !T {
    var in_stream = std.io.fixedBufferStream(encoded);
    const v1 = readILEB128(T, in_stream.inStream());
    var in_ptr = encoded.ptr;
    const v2 = readILEB128Mem(T, &in_ptr);
    testing.expectEqual(v1, v2);
    return v1;
}

fn test_read_uleb128(comptime T: type, encoded: []const u8) !T {
    var in_stream = std.io.fixedBufferStream(encoded);
    const v1 = readULEB128(T, in_stream.inStream());
    var in_ptr = encoded.ptr;
    const v2 = readULEB128Mem(T, &in_ptr);
    testing.expectEqual(v1, v2);
    return v1;
}

fn test_read_ileb128_seq(comptime T: type, comptime N: usize, encoded: []const u8) void {
    var in_stream = std.io.fixedBufferStream(encoded);
    var in_ptr = encoded.ptr;
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const v1 = readILEB128(T, in_stream.inStream());
        const v2 = readILEB128Mem(T, &in_ptr);
        testing.expectEqual(v1, v2);
    }
}

fn test_read_uleb128_seq(comptime T: type, comptime N: usize, encoded: []const u8) void {
    var in_stream = std.io.fixedBufferStream(encoded);
    var in_ptr = encoded.ptr;
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const v1 = readULEB128(T, in_stream.inStream());
        const v2 = readULEB128Mem(T, &in_ptr);
        testing.expectEqual(v1, v2);
    }
}

test "deserialize signed LEB128" {
    // Truncated
    testing.expectError(error.EndOfStream, test_read_stream_ileb128(i64, "\x80"));

    // Overflow
    testing.expectError(error.Overflow, test_read_ileb128(i8, "\x80\x80\x40"));
    testing.expectError(error.Overflow, test_read_ileb128(i16, "\x80\x80\x80\x40"));
    testing.expectError(error.Overflow, test_read_ileb128(i32, "\x80\x80\x80\x80\x40"));
    testing.expectError(error.Overflow, test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x40"));
    testing.expectError(error.Overflow, test_read_ileb128(i8, "\xff\x7e"));

    // Decode SLEB128
    testing.expect((try test_read_ileb128(i64, "\x00")) == 0);
    testing.expect((try test_read_ileb128(i64, "\x01")) == 1);
    testing.expect((try test_read_ileb128(i64, "\x3f")) == 63);
    testing.expect((try test_read_ileb128(i64, "\x40")) == -64);
    testing.expect((try test_read_ileb128(i64, "\x41")) == -63);
    testing.expect((try test_read_ileb128(i64, "\x7f")) == -1);
    testing.expect((try test_read_ileb128(i64, "\x80\x01")) == 128);
    testing.expect((try test_read_ileb128(i64, "\x81\x01")) == 129);
    testing.expect((try test_read_ileb128(i64, "\xff\x7e")) == -129);
    testing.expect((try test_read_ileb128(i64, "\x80\x7f")) == -128);
    testing.expect((try test_read_ileb128(i64, "\x81\x7f")) == -127);
    testing.expect((try test_read_ileb128(i64, "\xc0\x00")) == 64);
    testing.expect((try test_read_ileb128(i64, "\xc7\x9f\x7f")) == -12345);
    testing.expect((try test_read_ileb128(i8, "\xff\x7f")) == -1);
    testing.expect((try test_read_ileb128(i16, "\xff\xff\x7f")) == -1);
    testing.expect((try test_read_ileb128(i32, "\xff\xff\xff\xff\x7f")) == -1);
    testing.expect((try test_read_ileb128(i32, "\x80\x80\x80\x80\x08")) == -0x80000000);
    testing.expect((try test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x01")) == @bitCast(i64, @intCast(u64, 0x8000000000000000)));
    testing.expect((try test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x40")) == -0x4000000000000000);
    testing.expect((try test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f")) == -0x8000000000000000);

    // Decode unnormalized SLEB128 with extra padding bytes.
    testing.expect((try test_read_ileb128(i64, "\x80\x00")) == 0);
    testing.expect((try test_read_ileb128(i64, "\x80\x80\x00")) == 0);
    testing.expect((try test_read_ileb128(i64, "\xff\x00")) == 0x7f);
    testing.expect((try test_read_ileb128(i64, "\xff\x80\x00")) == 0x7f);
    testing.expect((try test_read_ileb128(i64, "\x80\x81\x00")) == 0x80);
    testing.expect((try test_read_ileb128(i64, "\x80\x81\x80\x00")) == 0x80);

    // Decode sequence of SLEB128 values
    test_read_ileb128_seq(i64, 4, "\x81\x01\x3f\x80\x7f\x80\x80\x80\x00");
}

test "deserialize unsigned LEB128" {
    // Truncated
    testing.expectError(error.EndOfStream, test_read_stream_uleb128(u64, "\x80"));

    // Overflow
    testing.expectError(error.Overflow, test_read_uleb128(u8, "\x80\x02"));
    testing.expectError(error.Overflow, test_read_uleb128(u8, "\x80\x80\x40"));
    testing.expectError(error.Overflow, test_read_uleb128(u16, "\x80\x80\x84"));
    testing.expectError(error.Overflow, test_read_uleb128(u16, "\x80\x80\x80\x40"));
    testing.expectError(error.Overflow, test_read_uleb128(u32, "\x80\x80\x80\x80\x90"));
    testing.expectError(error.Overflow, test_read_uleb128(u32, "\x80\x80\x80\x80\x40"));
    testing.expectError(error.Overflow, test_read_uleb128(u64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x40"));

    // Decode ULEB128
    testing.expect((try test_read_uleb128(u64, "\x00")) == 0);
    testing.expect((try test_read_uleb128(u64, "\x01")) == 1);
    testing.expect((try test_read_uleb128(u64, "\x3f")) == 63);
    testing.expect((try test_read_uleb128(u64, "\x40")) == 64);
    testing.expect((try test_read_uleb128(u64, "\x7f")) == 0x7f);
    testing.expect((try test_read_uleb128(u64, "\x80\x01")) == 0x80);
    testing.expect((try test_read_uleb128(u64, "\x81\x01")) == 0x81);
    testing.expect((try test_read_uleb128(u64, "\x90\x01")) == 0x90);
    testing.expect((try test_read_uleb128(u64, "\xff\x01")) == 0xff);
    testing.expect((try test_read_uleb128(u64, "\x80\x02")) == 0x100);
    testing.expect((try test_read_uleb128(u64, "\x81\x02")) == 0x101);
    testing.expect((try test_read_uleb128(u64, "\x80\xc1\x80\x80\x10")) == 4294975616);
    testing.expect((try test_read_uleb128(u64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x01")) == 0x8000000000000000);

    // Decode ULEB128 with extra padding bytes
    testing.expect((try test_read_uleb128(u64, "\x80\x00")) == 0);
    testing.expect((try test_read_uleb128(u64, "\x80\x80\x00")) == 0);
    testing.expect((try test_read_uleb128(u64, "\xff\x00")) == 0x7f);
    testing.expect((try test_read_uleb128(u64, "\xff\x80\x00")) == 0x7f);
    testing.expect((try test_read_uleb128(u64, "\x80\x81\x00")) == 0x80);
    testing.expect((try test_read_uleb128(u64, "\x80\x81\x80\x00")) == 0x80);

    // Decode sequence of ULEB128 values
    test_read_uleb128_seq(u64, 4, "\x81\x01\x3f\x80\x7f\x80\x80\x80\x00");
}
