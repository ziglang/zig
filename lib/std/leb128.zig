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

/// This is an "advanced" function. It allows one to use a fixed amount of memory to store an
/// SLEB128. This defeats the entire purpose of using this data encoding; it will no longer use
/// fewer bytes to store smaller numbers. The advantage of using a fixed width is that it makes
/// fields have a predictable size and so depending on the use case this tradeoff can be worthwhile.
/// An example use case of this is in emitting DWARF info where one wants to make a SLEB128 field
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
        try testing.expect((try test_read_ileb128(i64, &buf)) == 0);
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, 1);
        try testing.expect((try test_read_ileb128(i64, &buf)) == 1);
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, -1);
        try testing.expect((try test_read_ileb128(i64, &buf)) == -1);
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, 1000);
        try testing.expect((try test_read_ileb128(i64, &buf)) == 1000);
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, -1000);
        try testing.expect((try test_read_ileb128(i64, &buf)) == -1000);
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, -10000000);
        try testing.expect((try test_read_ileb128(i64, &buf)) == -10000000);
    }
    {
        var buf: [4]u8 = undefined;
        writeSignedFixed(4, &buf, 10000000);
        try testing.expect((try test_read_ileb128(i64, &buf)) == 10000000);
    }
}

fn test_read_stream_ileb128(comptime T: type, encoded: []const u8) !T {
    var br: std.io.Reader = .fixed(encoded);
    return br.takeIleb128(T);
}

fn test_read_stream_uleb128(comptime T: type, encoded: []const u8) !T {
    var br: std.io.Reader = .fixed(encoded);
    return br.takeUleb128(T);
}

fn test_read_ileb128(comptime T: type, encoded: []const u8) !T {
    var br: std.io.Reader = .fixed(encoded);
    return br.readIleb128(T);
}

fn test_read_uleb128(comptime T: type, encoded: []const u8) !T {
    var br: std.io.Reader = .fixed(encoded);
    return br.readUleb128(T);
}

fn test_read_ileb128_seq(comptime T: type, comptime N: usize, encoded: []const u8) !void {
    var br: std.io.Reader = .fixed(encoded);
    var i: usize = 0;
    while (i < N) : (i += 1) {
        _ = try br.readIleb128(T);
    }
}

fn test_read_uleb128_seq(comptime T: type, comptime N: usize, encoded: []const u8) !void {
    var br: std.io.Reader = .fixed(encoded);
    var i: usize = 0;
    while (i < N) : (i += 1) {
        _ = try br.readUleb128(T);
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
    try testing.expect((try test_read_ileb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f")) == @as(i64, @bitCast(@as(u64, @intCast(0x8000000000000000)))));
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
    const signedness = @typeInfo(T).int.signedness;
    const t_signed = signedness == .signed;

    const writeStream = if (t_signed) std.io.BufferedWriter.writeIleb128 else std.io.BufferedWriter.writeUleb128;
    const readStream = if (t_signed) std.io.Reader.readIleb128 else std.io.Reader.readUleb128;

    // decode to a larger bit size too, to ensure sign extension
    // is working as expected
    const larger_type_bits = ((@typeInfo(T).int.bits + 8) / 8) * 8;
    const B = std.meta.Int(signedness, larger_type_bits);

    const bytes_needed = bn: {
        if (@typeInfo(T).int.bits <= 7) break :bn @as(u16, 1);

        const unused_bits = if (value < 0) @clz(~value) else @clz(value);
        const used_bits: u16 = (@typeInfo(T).int.bits - unused_bits) + @intFromBool(t_signed);
        if (used_bits <= 7) break :bn @as(u16, 1);
        break :bn ((used_bits + 6) / 7);
    };

    const max_groups = if (@typeInfo(T).int.bits == 0) 1 else (@typeInfo(T).int.bits + 6) / 7;

    var buf: [max_groups]u8 = undefined;
    var bw: std.io.BufferedWriter = undefined;
    bw.initFixed(&buf);

    // stream write
    try testing.expect((try writeStream(&bw, value)) == bytes_needed);
    try testing.expect(bw.buffer.items.len == bytes_needed);

    // stream read
    var br: std.io.Reader = .fixed(&buf);
    const sr = try readStream(&br, T);
    try testing.expect(br.seek == bytes_needed);
    try testing.expect(sr == value);

    // bigger type stream read
    bw.buffer.items.len = 0;
    const bsr = try readStream(&bw, B);
    try testing.expect(bw.buffer.items.len == bytes_needed);
    try testing.expect(bsr == value);
}

test "serialize unsigned LEB128" {
    if (builtin.cpu.arch == .x86 and builtin.abi == .musl and builtin.link_mode == .dynamic) return error.SkipZigTest;

    const max_bits = 18;

    comptime var t = 0;
    inline while (t <= max_bits) : (t += 1) {
        const T = std.meta.Int(.unsigned, t);
        const min = std.math.minInt(T);
        const max = std.math.maxInt(T);
        var i = @as(std.meta.Int(.unsigned, @typeInfo(T).int.bits + 1), min);

        while (i <= max) : (i += 1) try test_write_leb128(@as(T, @intCast(i)));
    }
}

test "serialize signed LEB128" {
    if (builtin.cpu.arch == .x86 and builtin.abi == .musl and builtin.link_mode == .dynamic) return error.SkipZigTest;

    // explicitly test i0 because starting `t` at 0
    // will break the while loop
    try test_write_leb128(@as(i0, 0));

    const max_bits = 18;

    comptime var t = 1;
    inline while (t <= max_bits) : (t += 1) {
        const T = std.meta.Int(.signed, t);
        const min = std.math.minInt(T);
        const max = std.math.maxInt(T);
        var i = @as(std.meta.Int(.signed, @typeInfo(T).int.bits + 1), min);

        while (i <= max) : (i += 1) try test_write_leb128(@as(T, @intCast(i)));
    }
}
