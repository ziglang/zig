const builtin = @import("builtin");
const std = @import("../std.zig");
const io = std.io;
const meta = std.meta;
const trait = std.trait;
const DefaultPrng = std.rand.DefaultPrng;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const mem = std.mem;
const fs = std.fs;
const File = std.fs.File;

test "write a file, read it, then delete it" {
    const cwd = fs.cwd();

    var data: [1024]u8 = undefined;
    var prng = DefaultPrng.init(1234);
    prng.random.bytes(data[0..]);
    const tmp_file_name = "temp_test_file.txt";
    {
        var file = try cwd.createFile(tmp_file_name, .{});
        defer file.close();

        var file_out_stream = file.outStream();
        var buf_stream = io.BufferedOutStream(File.WriteError).init(&file_out_stream.stream);
        const st = &buf_stream.stream;
        try st.print("begin", .{});
        try st.write(data[0..]);
        try st.print("end", .{});
        try buf_stream.flush();
    }

    {
        // Make sure the exclusive flag is honored.
        if (cwd.createFile(tmp_file_name, .{ .exclusive = true })) |file| {
            unreachable;
        } else |err| {
            std.debug.assert(err == File.OpenError.PathAlreadyExists);
        }
    }

    {
        var file = try cwd.openFile(tmp_file_name, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const expected_file_size: u64 = "begin".len + data.len + "end".len;
        expectEqual(expected_file_size, file_size);

        var file_in_stream = file.inStream();
        var buf_stream = io.BufferedInStream(File.ReadError).init(&file_in_stream.stream);
        const st = &buf_stream.stream;
        const contents = try st.readAllAlloc(std.testing.allocator, 2 * 1024);
        defer std.testing.allocator.free(contents);

        expect(mem.eql(u8, contents[0.."begin".len], "begin"));
        expect(mem.eql(u8, contents["begin".len .. contents.len - "end".len], &data));
        expect(mem.eql(u8, contents[contents.len - "end".len ..], "end"));
    }
    try cwd.deleteFile(tmp_file_name);
}

test "BufferOutStream" {
    var buffer = try std.Buffer.initSize(std.testing.allocator, 0);
    defer buffer.deinit();
    var buf_stream = &std.io.BufferOutStream.init(&buffer).stream;

    const x: i32 = 42;
    const y: i32 = 1234;
    try buf_stream.print("x: {}\ny: {}\n", .{ x, y });

    expect(mem.eql(u8, buffer.toSlice(), "x: 42\ny: 1234\n"));
}

test "SliceInStream" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7 };
    var ss = io.SliceInStream.init(&bytes);

    var dest: [4]u8 = undefined;

    var read = try ss.stream.read(dest[0..4]);
    expect(read == 4);
    expect(mem.eql(u8, dest[0..4], bytes[0..4]));

    read = try ss.stream.read(dest[0..4]);
    expect(read == 3);
    expect(mem.eql(u8, dest[0..3], bytes[4..7]));

    read = try ss.stream.read(dest[0..4]);
    expect(read == 0);
}

test "PeekStream" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var ss = io.SliceInStream.init(&bytes);
    var ps = io.PeekStream(.{ .Static = 2 }, io.SliceInStream.Error).init(&ss.stream);

    var dest: [4]u8 = undefined;

    try ps.putBackByte(9);
    try ps.putBackByte(10);

    var read = try ps.stream.read(dest[0..4]);
    expect(read == 4);
    expect(dest[0] == 10);
    expect(dest[1] == 9);
    expect(mem.eql(u8, dest[2..4], bytes[0..2]));

    read = try ps.stream.read(dest[0..4]);
    expect(read == 4);
    expect(mem.eql(u8, dest[0..4], bytes[2..6]));

    read = try ps.stream.read(dest[0..4]);
    expect(read == 2);
    expect(mem.eql(u8, dest[0..2], bytes[6..8]));

    try ps.putBackByte(11);
    try ps.putBackByte(12);

    read = try ps.stream.read(dest[0..4]);
    expect(read == 2);
    expect(dest[0] == 12);
    expect(dest[1] == 11);
}

test "SliceOutStream" {
    var buffer: [10]u8 = undefined;
    var ss = io.SliceOutStream.init(buffer[0..]);

    try ss.stream.write("Hello");
    expect(mem.eql(u8, ss.getWritten(), "Hello"));

    try ss.stream.write("world");
    expect(mem.eql(u8, ss.getWritten(), "Helloworld"));

    expectError(error.OutOfMemory, ss.stream.write("!"));
    expect(mem.eql(u8, ss.getWritten(), "Helloworld"));

    ss.reset();
    expect(ss.getWritten().len == 0);

    expectError(error.OutOfMemory, ss.stream.write("Hello world!"));
    expect(mem.eql(u8, ss.getWritten(), "Hello worl"));
}

test "BitInStream" {
    const mem_be = [_]u8{ 0b11001101, 0b00001011 };
    const mem_le = [_]u8{ 0b00011101, 0b10010101 };

    var mem_in_be = io.SliceInStream.init(mem_be[0..]);
    const InError = io.SliceInStream.Error;
    var bit_stream_be = io.BitInStream(builtin.Endian.Big, InError).init(&mem_in_be.stream);

    var out_bits: usize = undefined;

    expect(1 == try bit_stream_be.readBits(u2, 1, &out_bits));
    expect(out_bits == 1);
    expect(2 == try bit_stream_be.readBits(u5, 2, &out_bits));
    expect(out_bits == 2);
    expect(3 == try bit_stream_be.readBits(u128, 3, &out_bits));
    expect(out_bits == 3);
    expect(4 == try bit_stream_be.readBits(u8, 4, &out_bits));
    expect(out_bits == 4);
    expect(5 == try bit_stream_be.readBits(u9, 5, &out_bits));
    expect(out_bits == 5);
    expect(1 == try bit_stream_be.readBits(u1, 1, &out_bits));
    expect(out_bits == 1);

    mem_in_be.pos = 0;
    bit_stream_be.bit_count = 0;
    expect(0b110011010000101 == try bit_stream_be.readBits(u15, 15, &out_bits));
    expect(out_bits == 15);

    mem_in_be.pos = 0;
    bit_stream_be.bit_count = 0;
    expect(0b1100110100001011 == try bit_stream_be.readBits(u16, 16, &out_bits));
    expect(out_bits == 16);

    _ = try bit_stream_be.readBits(u0, 0, &out_bits);

    expect(0 == try bit_stream_be.readBits(u1, 1, &out_bits));
    expect(out_bits == 0);
    expectError(error.EndOfStream, bit_stream_be.readBitsNoEof(u1, 1));

    var mem_in_le = io.SliceInStream.init(mem_le[0..]);
    var bit_stream_le = io.BitInStream(builtin.Endian.Little, InError).init(&mem_in_le.stream);

    expect(1 == try bit_stream_le.readBits(u2, 1, &out_bits));
    expect(out_bits == 1);
    expect(2 == try bit_stream_le.readBits(u5, 2, &out_bits));
    expect(out_bits == 2);
    expect(3 == try bit_stream_le.readBits(u128, 3, &out_bits));
    expect(out_bits == 3);
    expect(4 == try bit_stream_le.readBits(u8, 4, &out_bits));
    expect(out_bits == 4);
    expect(5 == try bit_stream_le.readBits(u9, 5, &out_bits));
    expect(out_bits == 5);
    expect(1 == try bit_stream_le.readBits(u1, 1, &out_bits));
    expect(out_bits == 1);

    mem_in_le.pos = 0;
    bit_stream_le.bit_count = 0;
    expect(0b001010100011101 == try bit_stream_le.readBits(u15, 15, &out_bits));
    expect(out_bits == 15);

    mem_in_le.pos = 0;
    bit_stream_le.bit_count = 0;
    expect(0b1001010100011101 == try bit_stream_le.readBits(u16, 16, &out_bits));
    expect(out_bits == 16);

    _ = try bit_stream_le.readBits(u0, 0, &out_bits);

    expect(0 == try bit_stream_le.readBits(u1, 1, &out_bits));
    expect(out_bits == 0);
    expectError(error.EndOfStream, bit_stream_le.readBitsNoEof(u1, 1));
}

test "BitOutStream" {
    var mem_be = [_]u8{0} ** 2;
    var mem_le = [_]u8{0} ** 2;

    var mem_out_be = io.SliceOutStream.init(mem_be[0..]);
    const OutError = io.SliceOutStream.Error;
    var bit_stream_be = io.BitOutStream(builtin.Endian.Big, OutError).init(&mem_out_be.stream);

    try bit_stream_be.writeBits(@as(u2, 1), 1);
    try bit_stream_be.writeBits(@as(u5, 2), 2);
    try bit_stream_be.writeBits(@as(u128, 3), 3);
    try bit_stream_be.writeBits(@as(u8, 4), 4);
    try bit_stream_be.writeBits(@as(u9, 5), 5);
    try bit_stream_be.writeBits(@as(u1, 1), 1);

    expect(mem_be[0] == 0b11001101 and mem_be[1] == 0b00001011);

    mem_out_be.pos = 0;

    try bit_stream_be.writeBits(@as(u15, 0b110011010000101), 15);
    try bit_stream_be.flushBits();
    expect(mem_be[0] == 0b11001101 and mem_be[1] == 0b00001010);

    mem_out_be.pos = 0;
    try bit_stream_be.writeBits(@as(u32, 0b110011010000101), 16);
    expect(mem_be[0] == 0b01100110 and mem_be[1] == 0b10000101);

    try bit_stream_be.writeBits(@as(u0, 0), 0);

    var mem_out_le = io.SliceOutStream.init(mem_le[0..]);
    var bit_stream_le = io.BitOutStream(builtin.Endian.Little, OutError).init(&mem_out_le.stream);

    try bit_stream_le.writeBits(@as(u2, 1), 1);
    try bit_stream_le.writeBits(@as(u5, 2), 2);
    try bit_stream_le.writeBits(@as(u128, 3), 3);
    try bit_stream_le.writeBits(@as(u8, 4), 4);
    try bit_stream_le.writeBits(@as(u9, 5), 5);
    try bit_stream_le.writeBits(@as(u1, 1), 1);

    expect(mem_le[0] == 0b00011101 and mem_le[1] == 0b10010101);

    mem_out_le.pos = 0;
    try bit_stream_le.writeBits(@as(u15, 0b110011010000101), 15);
    try bit_stream_le.flushBits();
    expect(mem_le[0] == 0b10000101 and mem_le[1] == 0b01100110);

    mem_out_le.pos = 0;
    try bit_stream_le.writeBits(@as(u32, 0b1100110100001011), 16);
    expect(mem_le[0] == 0b00001011 and mem_le[1] == 0b11001101);

    try bit_stream_le.writeBits(@as(u0, 0), 0);
}

test "BitStreams with File Stream" {
    const tmp_file_name = "temp_test_file.txt";
    {
        var file = try fs.cwd().createFile(tmp_file_name, .{});
        defer file.close();

        var file_out = file.outStream();
        var file_out_stream = &file_out.stream;
        const OutError = File.WriteError;
        var bit_stream = io.BitOutStream(builtin.endian, OutError).init(file_out_stream);

        try bit_stream.writeBits(@as(u2, 1), 1);
        try bit_stream.writeBits(@as(u5, 2), 2);
        try bit_stream.writeBits(@as(u128, 3), 3);
        try bit_stream.writeBits(@as(u8, 4), 4);
        try bit_stream.writeBits(@as(u9, 5), 5);
        try bit_stream.writeBits(@as(u1, 1), 1);
        try bit_stream.flushBits();
    }
    {
        var file = try fs.cwd().openFile(tmp_file_name, .{});
        defer file.close();

        var file_in = file.inStream();
        var file_in_stream = &file_in.stream;
        const InError = File.ReadError;
        var bit_stream = io.BitInStream(builtin.endian, InError).init(file_in_stream);

        var out_bits: usize = undefined;

        expect(1 == try bit_stream.readBits(u2, 1, &out_bits));
        expect(out_bits == 1);
        expect(2 == try bit_stream.readBits(u5, 2, &out_bits));
        expect(out_bits == 2);
        expect(3 == try bit_stream.readBits(u128, 3, &out_bits));
        expect(out_bits == 3);
        expect(4 == try bit_stream.readBits(u8, 4, &out_bits));
        expect(out_bits == 4);
        expect(5 == try bit_stream.readBits(u9, 5, &out_bits));
        expect(out_bits == 5);
        expect(1 == try bit_stream.readBits(u1, 1, &out_bits));
        expect(out_bits == 1);

        expectError(error.EndOfStream, bit_stream.readBitsNoEof(u1, 1));
    }
    try fs.cwd().deleteFile(tmp_file_name);
}

fn testIntSerializerDeserializer(comptime endian: builtin.Endian, comptime packing: io.Packing) !void {
    @setEvalBranchQuota(1500);
    //@NOTE: if this test is taking too long, reduce the maximum tested bitsize
    const max_test_bitsize = 128;

    const total_bytes = comptime blk: {
        var bytes = 0;
        comptime var i = 0;
        while (i <= max_test_bitsize) : (i += 1) bytes += (i / 8) + @boolToInt(i % 8 > 0);
        break :blk bytes * 2;
    };

    var data_mem: [total_bytes]u8 = undefined;
    var out = io.SliceOutStream.init(data_mem[0..]);
    const OutError = io.SliceOutStream.Error;
    var out_stream = &out.stream;
    var serializer = io.Serializer(endian, packing, OutError).init(out_stream);

    var in = io.SliceInStream.init(data_mem[0..]);
    const InError = io.SliceInStream.Error;
    var in_stream = &in.stream;
    var deserializer = io.Deserializer(endian, packing, InError).init(in_stream);

    comptime var i = 0;
    inline while (i <= max_test_bitsize) : (i += 1) {
        const U = std.meta.IntType(false, i);
        const S = std.meta.IntType(true, i);
        try serializer.serializeInt(@as(U, i));
        if (i != 0) try serializer.serializeInt(@as(S, -1)) else try serializer.serialize(@as(S, 0));
    }
    try serializer.flush();

    i = 0;
    inline while (i <= max_test_bitsize) : (i += 1) {
        const U = std.meta.IntType(false, i);
        const S = std.meta.IntType(true, i);
        const x = try deserializer.deserializeInt(U);
        const y = try deserializer.deserializeInt(S);
        expect(x == @as(U, i));
        if (i != 0) expect(y == @as(S, -1)) else expect(y == 0);
    }

    const u8_bit_count = comptime meta.bitCount(u8);
    //0 + 1 + 2 + ... n = (n * (n + 1)) / 2
    //and we have each for unsigned and signed, so * 2
    const total_bits = (max_test_bitsize * (max_test_bitsize + 1));
    const extra_packed_byte = @boolToInt(total_bits % u8_bit_count > 0);
    const total_packed_bytes = (total_bits / u8_bit_count) + extra_packed_byte;

    expect(in.pos == if (packing == .Bit) total_packed_bytes else total_bytes);

    //Verify that empty error set works with serializer.
    //deserializer is covered by SliceInStream
    const NullError = io.NullOutStream.Error;
    var null_out = io.NullOutStream.init();
    var null_out_stream = &null_out.stream;
    var null_serializer = io.Serializer(endian, packing, NullError).init(null_out_stream);
    try null_serializer.serialize(data_mem[0..]);
    try null_serializer.flush();
}

test "Serializer/Deserializer Int" {
    try testIntSerializerDeserializer(.Big, .Byte);
    try testIntSerializerDeserializer(.Little, .Byte);
    // TODO these tests are disabled due to tripping an LLVM assertion
    // https://github.com/ziglang/zig/issues/2019
    //try testIntSerializerDeserializer(builtin.Endian.Big, true);
    //try testIntSerializerDeserializer(builtin.Endian.Little, true);
}

fn testIntSerializerDeserializerInfNaN(
    comptime endian: builtin.Endian,
    comptime packing: io.Packing,
) !void {
    const mem_size = (16 * 2 + 32 * 2 + 64 * 2 + 128 * 2) / comptime meta.bitCount(u8);
    var data_mem: [mem_size]u8 = undefined;

    var out = io.SliceOutStream.init(data_mem[0..]);
    const OutError = io.SliceOutStream.Error;
    var out_stream = &out.stream;
    var serializer = io.Serializer(endian, packing, OutError).init(out_stream);

    var in = io.SliceInStream.init(data_mem[0..]);
    const InError = io.SliceInStream.Error;
    var in_stream = &in.stream;
    var deserializer = io.Deserializer(endian, packing, InError).init(in_stream);

    //@TODO: isInf/isNan not currently implemented for f128.
    try serializer.serialize(std.math.nan(f16));
    try serializer.serialize(std.math.inf(f16));
    try serializer.serialize(std.math.nan(f32));
    try serializer.serialize(std.math.inf(f32));
    try serializer.serialize(std.math.nan(f64));
    try serializer.serialize(std.math.inf(f64));
    //try serializer.serialize(std.math.nan(f128));
    //try serializer.serialize(std.math.inf(f128));
    const nan_check_f16 = try deserializer.deserialize(f16);
    const inf_check_f16 = try deserializer.deserialize(f16);
    const nan_check_f32 = try deserializer.deserialize(f32);
    deserializer.alignToByte();
    const inf_check_f32 = try deserializer.deserialize(f32);
    const nan_check_f64 = try deserializer.deserialize(f64);
    const inf_check_f64 = try deserializer.deserialize(f64);
    //const nan_check_f128 = try deserializer.deserialize(f128);
    //const inf_check_f128 = try deserializer.deserialize(f128);
    expect(std.math.isNan(nan_check_f16));
    expect(std.math.isInf(inf_check_f16));
    expect(std.math.isNan(nan_check_f32));
    expect(std.math.isInf(inf_check_f32));
    expect(std.math.isNan(nan_check_f64));
    expect(std.math.isInf(inf_check_f64));
    //expect(std.math.isNan(nan_check_f128));
    //expect(std.math.isInf(inf_check_f128));
}

test "Serializer/Deserializer Int: Inf/NaN" {
    try testIntSerializerDeserializerInfNaN(.Big, .Byte);
    try testIntSerializerDeserializerInfNaN(.Little, .Byte);
    try testIntSerializerDeserializerInfNaN(.Big, .Bit);
    try testIntSerializerDeserializerInfNaN(.Little, .Bit);
}

fn testAlternateSerializer(self: var, serializer: var) !void {
    try serializer.serialize(self.f_f16);
}

fn testSerializerDeserializer(comptime endian: builtin.Endian, comptime packing: io.Packing) !void {
    const ColorType = enum(u4) {
        RGB8 = 1,
        RA16 = 2,
        R32 = 3,
    };

    const TagAlign = union(enum(u32)) {
        A: u8,
        B: u8,
        C: u8,
    };

    const Color = union(ColorType) {
        RGB8: struct {
            r: u8,
            g: u8,
            b: u8,
            a: u8,
        },
        RA16: struct {
            r: u16,
            a: u16,
        },
        R32: u32,
    };

    const PackedStruct = packed struct {
        f_i3: i3,
        f_u2: u2,
    };

    //to test custom serialization
    const Custom = struct {
        f_f16: f16,
        f_unused_u32: u32,

        pub fn deserialize(self: *@This(), deserializer: var) !void {
            try deserializer.deserializeInto(&self.f_f16);
            self.f_unused_u32 = 47;
        }

        pub const serialize = testAlternateSerializer;
    };

    const MyStruct = struct {
        f_i3: i3,
        f_u8: u8,
        f_tag_align: TagAlign,
        f_u24: u24,
        f_i19: i19,
        f_void: void,
        f_f32: f32,
        f_f128: f128,
        f_packed_0: PackedStruct,
        f_i7arr: [10]i7,
        f_of64n: ?f64,
        f_of64v: ?f64,
        f_color_type: ColorType,
        f_packed_1: PackedStruct,
        f_custom: Custom,
        f_color: Color,
    };

    const my_inst = MyStruct{
        .f_i3 = -1,
        .f_u8 = 8,
        .f_tag_align = TagAlign{ .B = 148 },
        .f_u24 = 24,
        .f_i19 = 19,
        .f_void = {},
        .f_f32 = 32.32,
        .f_f128 = 128.128,
        .f_packed_0 = PackedStruct{ .f_i3 = -1, .f_u2 = 2 },
        .f_i7arr = [10]i7{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        .f_of64n = null,
        .f_of64v = 64.64,
        .f_color_type = ColorType.R32,
        .f_packed_1 = PackedStruct{ .f_i3 = 1, .f_u2 = 1 },
        .f_custom = Custom{ .f_f16 = 38.63, .f_unused_u32 = 47 },
        .f_color = Color{ .R32 = 123822 },
    };

    var data_mem: [@sizeOf(MyStruct)]u8 = undefined;
    var out = io.SliceOutStream.init(data_mem[0..]);
    const OutError = io.SliceOutStream.Error;
    var out_stream = &out.stream;
    var serializer = io.Serializer(endian, packing, OutError).init(out_stream);

    var in = io.SliceInStream.init(data_mem[0..]);
    const InError = io.SliceInStream.Error;
    var in_stream = &in.stream;
    var deserializer = io.Deserializer(endian, packing, InError).init(in_stream);

    try serializer.serialize(my_inst);

    const my_copy = try deserializer.deserialize(MyStruct);
    expect(meta.eql(my_copy, my_inst));
}

test "Serializer/Deserializer generic" {
    if (std.Target.current.os.tag == .windows) {
        // TODO https://github.com/ziglang/zig/issues/508
        return error.SkipZigTest;
    }
    try testSerializerDeserializer(builtin.Endian.Big, .Byte);
    try testSerializerDeserializer(builtin.Endian.Little, .Byte);
    try testSerializerDeserializer(builtin.Endian.Big, .Bit);
    try testSerializerDeserializer(builtin.Endian.Little, .Bit);
}

fn testBadData(comptime endian: builtin.Endian, comptime packing: io.Packing) !void {
    const E = enum(u14) {
        One = 1,
        Two = 2,
    };

    const A = struct {
        e: E,
    };

    const C = union(E) {
        One: u14,
        Two: f16,
    };

    var data_mem: [4]u8 = undefined;
    var out = io.SliceOutStream.init(data_mem[0..]);
    const OutError = io.SliceOutStream.Error;
    var out_stream = &out.stream;
    var serializer = io.Serializer(endian, packing, OutError).init(out_stream);

    var in = io.SliceInStream.init(data_mem[0..]);
    const InError = io.SliceInStream.Error;
    var in_stream = &in.stream;
    var deserializer = io.Deserializer(endian, packing, InError).init(in_stream);

    try serializer.serialize(@as(u14, 3));
    expectError(error.InvalidEnumTag, deserializer.deserialize(A));
    out.pos = 0;
    try serializer.serialize(@as(u14, 3));
    try serializer.serialize(@as(u14, 88));
    expectError(error.InvalidEnumTag, deserializer.deserialize(C));
}

test "Deserializer bad data" {
    try testBadData(.Big, .Byte);
    try testBadData(.Little, .Byte);
    try testBadData(.Big, .Bit);
    try testBadData(.Little, .Bit);
}

test "c out stream" {
    if (!builtin.link_libc) return error.SkipZigTest;

    const filename = "tmp_io_test_file.txt";
    const out_file = std.c.fopen(filename, "w") orelse return error.UnableToOpenTestFile;
    defer {
        _ = std.c.fclose(out_file);
        fs.cwd().deleteFileC(filename) catch {};
    }

    const out_stream = &io.COutStream.init(out_file).stream;
    try out_stream.print("hi: {}\n", .{@as(i32, 123)});
}

test "File seek ops" {
    const tmp_file_name = "temp_test_file.txt";
    var file = try fs.cwd().createFile(tmp_file_name, .{});
    defer {
        file.close();
        fs.cwd().deleteFile(tmp_file_name) catch {};
    }

    try file.writeAll(&([_]u8{0x55} ** 8192));

    // Seek to the end
    try file.seekFromEnd(0);
    std.testing.expect((try file.getPos()) == try file.getEndPos());
    // Negative delta
    try file.seekBy(-4096);
    std.testing.expect((try file.getPos()) == 4096);
    // Positive delta
    try file.seekBy(10);
    std.testing.expect((try file.getPos()) == 4106);
    // Absolute position
    try file.seekTo(1234);
    std.testing.expect((try file.getPos()) == 1234);
}

test "updateTimes" {
    const tmp_file_name = "just_a_temporary_file.txt";
    var file = try fs.cwd().createFile(tmp_file_name, .{ .read = true });
    defer {
        file.close();
        std.fs.cwd().deleteFile(tmp_file_name) catch {};
    }
    var stat_old = try file.stat();
    // Set atime and mtime to 5s before
    try file.updateTimes(
        stat_old.atime - 5 * std.time.ns_per_s,
        stat_old.mtime - 5 * std.time.ns_per_s,
    );
    var stat_new = try file.stat();
    std.testing.expect(stat_new.atime < stat_old.atime);
    std.testing.expect(stat_new.mtime < stat_old.mtime);
}
