const std = @import("index.zig");
const io = std.io;
const meta = std.meta;
const trait = std.trait;
const DefaultPrng = std.rand.DefaultPrng;
const assert = std.debug.assert;
const assertError = std.debug.assertError;
const mem = std.mem;
const os = std.os;
const builtin = @import("builtin");

test "write a file, read it, then delete it" {
    var raw_bytes: [200 * 1024]u8 = undefined;
    var allocator = &std.heap.FixedBufferAllocator.init(raw_bytes[0..]).allocator;

    var data: [1024]u8 = undefined;
    var prng = DefaultPrng.init(1234);
    prng.random.bytes(data[0..]);
    const tmp_file_name = "temp_test_file.txt";
    {
        var file = try os.File.openWrite(tmp_file_name);
        defer file.close();

        var file_out_stream = file.outStream();
        var buf_stream = io.BufferedOutStream(os.File.WriteError).init(&file_out_stream.stream);
        const st = &buf_stream.stream;
        try st.print("begin");
        try st.write(data[0..]);
        try st.print("end");
        try buf_stream.flush();
    }
    {
        var file = try os.File.openRead(tmp_file_name);
        defer file.close();

        const file_size = try file.getEndPos();
        const expected_file_size = "begin".len + data.len + "end".len;
        assert(file_size == expected_file_size);

        var file_in_stream = file.inStream();
        var buf_stream = io.BufferedInStream(os.File.ReadError).init(&file_in_stream.stream);
        const st = &buf_stream.stream;
        const contents = try st.readAllAlloc(allocator, 2 * 1024);
        defer allocator.free(contents);

        assert(mem.eql(u8, contents[0.."begin".len], "begin"));
        assert(mem.eql(u8, contents["begin".len .. contents.len - "end".len], data));
        assert(mem.eql(u8, contents[contents.len - "end".len ..], "end"));
    }
    try os.deleteFile(tmp_file_name);
}

test "BufferOutStream" {
    var bytes: [100]u8 = undefined;
    var allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;

    var buffer = try std.Buffer.initSize(allocator, 0);
    var buf_stream = &std.io.BufferOutStream.init(&buffer).stream;

    const x: i32 = 42;
    const y: i32 = 1234;
    try buf_stream.print("x: {}\ny: {}\n", x, y);

    assert(mem.eql(u8, buffer.toSlice(), "x: 42\ny: 1234\n"));
}

test "SliceInStream" {
    const bytes = []const u8{ 1, 2, 3, 4, 5, 6, 7 };
    var ss = io.SliceInStream.init(bytes);

    var dest: [4]u8 = undefined;

    var read = try ss.stream.read(dest[0..4]);
    assert(read == 4);
    assert(mem.eql(u8, dest[0..4], bytes[0..4]));

    read = try ss.stream.read(dest[0..4]);
    assert(read == 3);
    assert(mem.eql(u8, dest[0..3], bytes[4..7]));

    read = try ss.stream.read(dest[0..4]);
    assert(read == 0);
}

test "PeekStream" {
    const bytes = []const u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var ss = io.SliceInStream.init(bytes);
    var ps = io.PeekStream(2, io.SliceInStream.Error).init(&ss.stream);

    var dest: [4]u8 = undefined;

    ps.putBackByte(9);
    ps.putBackByte(10);

    var read = try ps.stream.read(dest[0..4]);
    assert(read == 4);
    assert(dest[0] == 10);
    assert(dest[1] == 9);
    assert(mem.eql(u8, dest[2..4], bytes[0..2]));

    read = try ps.stream.read(dest[0..4]);
    assert(read == 4);
    assert(mem.eql(u8, dest[0..4], bytes[2..6]));

    read = try ps.stream.read(dest[0..4]);
    assert(read == 2);
    assert(mem.eql(u8, dest[0..2], bytes[6..8]));

    ps.putBackByte(11);
    ps.putBackByte(12);

    read = try ps.stream.read(dest[0..4]);
    assert(read == 2);
    assert(dest[0] == 12);
    assert(dest[1] == 11);
}

test "SliceOutStream" {
    var buffer: [10]u8 = undefined;
    var ss = io.SliceOutStream.init(buffer[0..]);

    try ss.stream.write("Hello");
    assert(mem.eql(u8, ss.getWritten(), "Hello"));

    try ss.stream.write("world");
    assert(mem.eql(u8, ss.getWritten(), "Helloworld"));

    assertError(ss.stream.write("!"), error.OutOfSpace);
    assert(mem.eql(u8, ss.getWritten(), "Helloworld"));

    ss.reset();
    assert(ss.getWritten().len == 0);

    assertError(ss.stream.write("Hello world!"), error.OutOfSpace);
    assert(mem.eql(u8, ss.getWritten(), "Hello worl"));
}

test "BitInStream" {
    const mem_be = []u8{ 0b11001101, 0b00001011 };
    const mem_le = []u8{ 0b00011101, 0b10010101 };

    var mem_in_be = io.SliceInStream.init(mem_be[0..]);
    const InError = io.SliceInStream.Error;
    var bit_stream_be = io.BitInStream(builtin.Endian.Big, InError).init(&mem_in_be.stream);

    var out_bits: usize = undefined;

    assert(1 == try bit_stream_be.readBits(u2, 1, &out_bits));
    assert(out_bits == 1);
    assert(2 == try bit_stream_be.readBits(u5, 2, &out_bits));
    assert(out_bits == 2);
    assert(3 == try bit_stream_be.readBits(u128, 3, &out_bits));
    assert(out_bits == 3);
    assert(4 == try bit_stream_be.readBits(u8, 4, &out_bits));
    assert(out_bits == 4);
    assert(5 == try bit_stream_be.readBits(u9, 5, &out_bits));
    assert(out_bits == 5);
    assert(1 == try bit_stream_be.readBits(u1, 1, &out_bits));
    assert(out_bits == 1);

    mem_in_be.pos = 0;
    bit_stream_be.bit_count = 0;
    assert(0b110011010000101 == try bit_stream_be.readBits(u15, 15, &out_bits));
    assert(out_bits == 15);

    mem_in_be.pos = 0;
    bit_stream_be.bit_count = 0;
    assert(0b1100110100001011 == try bit_stream_be.readBits(u16, 16, &out_bits));
    assert(out_bits == 16);

    _ = try bit_stream_be.readBits(u0, 0, &out_bits);

    var mem_in_le = io.SliceInStream.init(mem_le[0..]);
    var bit_stream_le = io.BitInStream(builtin.Endian.Little, InError).init(&mem_in_le.stream);

    assert(1 == try bit_stream_le.readBits(u2, 1, &out_bits));
    assert(out_bits == 1);
    assert(2 == try bit_stream_le.readBits(u5, 2, &out_bits));
    assert(out_bits == 2);
    assert(3 == try bit_stream_le.readBits(u128, 3, &out_bits));
    assert(out_bits == 3);
    assert(4 == try bit_stream_le.readBits(u8, 4, &out_bits));
    assert(out_bits == 4);
    assert(5 == try bit_stream_le.readBits(u9, 5, &out_bits));
    assert(out_bits == 5);
    assert(1 == try bit_stream_le.readBits(u1, 1, &out_bits));
    assert(out_bits == 1);

    mem_in_le.pos = 0;
    bit_stream_le.bit_count = 0;
    assert(0b001010100011101 == try bit_stream_le.readBits(u15, 15, &out_bits));
    assert(out_bits == 15);

    mem_in_le.pos = 0;
    bit_stream_le.bit_count = 0;
    assert(0b1001010100011101 == try bit_stream_le.readBits(u16, 16, &out_bits));
    assert(out_bits == 16);

    _ = try bit_stream_le.readBits(u0, 0, &out_bits);
}

test "BitOutStream" {
    var mem_be = []u8{0} ** 2;
    var mem_le = []u8{0} ** 2;

    var mem_out_be = io.SliceOutStream.init(mem_be[0..]);
    const OutError = io.SliceOutStream.Error;
    var bit_stream_be = io.BitOutStream(builtin.Endian.Big, OutError).init(&mem_out_be.stream);

    try bit_stream_be.writeBits(u2(1), 1);
    try bit_stream_be.writeBits(u5(2), 2);
    try bit_stream_be.writeBits(u128(3), 3);
    try bit_stream_be.writeBits(u8(4), 4);
    try bit_stream_be.writeBits(u9(5), 5);
    try bit_stream_be.writeBits(u1(1), 1);

    assert(mem_be[0] == 0b11001101 and mem_be[1] == 0b00001011);

    mem_out_be.pos = 0;

    try bit_stream_be.writeBits(u15(0b110011010000101), 15);
    try bit_stream_be.flushBits();
    assert(mem_be[0] == 0b11001101 and mem_be[1] == 0b00001010);

    mem_out_be.pos = 0;
    try bit_stream_be.writeBits(u32(0b110011010000101), 16);
    assert(mem_be[0] == 0b01100110 and mem_be[1] == 0b10000101);

    try bit_stream_be.writeBits(u0(0), 0);

    var mem_out_le = io.SliceOutStream.init(mem_le[0..]);
    var bit_stream_le = io.BitOutStream(builtin.Endian.Little, OutError).init(&mem_out_le.stream);

    try bit_stream_le.writeBits(u2(1), 1);
    try bit_stream_le.writeBits(u5(2), 2);
    try bit_stream_le.writeBits(u128(3), 3);
    try bit_stream_le.writeBits(u8(4), 4);
    try bit_stream_le.writeBits(u9(5), 5);
    try bit_stream_le.writeBits(u1(1), 1);

    assert(mem_le[0] == 0b00011101 and mem_le[1] == 0b10010101);

    mem_out_le.pos = 0;
    try bit_stream_le.writeBits(u15(0b110011010000101), 15);
    try bit_stream_le.flushBits();
    assert(mem_le[0] == 0b10000101 and mem_le[1] == 0b01100110);

    mem_out_le.pos = 0;
    try bit_stream_le.writeBits(u32(0b1100110100001011), 16);
    assert(mem_le[0] == 0b00001011 and mem_le[1] == 0b11001101);

    try bit_stream_le.writeBits(u0(0), 0);
}

fn testIntSerializerDeserializer(comptime endian: builtin.Endian, comptime is_packed: bool) !void {
    const max_test_bitsize = 17;
    
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
    var serializer = io.Serializer(endian, is_packed, OutError).init(out_stream);

    var in = io.SliceInStream.init(data_mem[0..]);
    const InError = io.SliceInStream.Error;
    var in_stream = &in.stream;
    var deserializer = io.Deserializer(endian, is_packed, InError).init(in_stream);

    comptime var i = 0;
    inline while (i <= max_test_bitsize) : (i += 1) {
        const U = @IntType(false, i);
        const S = @IntType(true, i);
        try serializer.serializeInt(U(i));
        if (i != 0) try serializer.serializeInt(S(-1));
    }
    try serializer.flush();

    i = 0;
    inline while (i <= max_test_bitsize) : (i += 1) {
        const U = @IntType(false, i);
        const S = @IntType(true, i);
        const x = try deserializer.deserializeInt(U);
        const y = if (i != 0) try deserializer.deserializeInt(S);
        assert(x == U(i));
        if (i != 0) assert(y == S(-1));
    }

    const u8_bit_count = comptime meta.bitCount(u8);
    //0 + 1 + 2 + ... n = (n * (n + 1)) / 2
    //and we have each for unsigned and signed, so * 2
    const total_bits = (max_test_bitsize * (max_test_bitsize + 1));
    const extra_packed_byte = @boolToInt(total_bits % u8_bit_count > 0);
    const total_packed_bytes = (total_bits / u8_bit_count) + extra_packed_byte;

    

    assert(in.pos == if (is_packed) total_packed_bytes else total_bytes);
}

test "Serializer/Deserializer Int" {
    try testIntSerializerDeserializer(builtin.Endian.Big, false);
    try testIntSerializerDeserializer(builtin.Endian.Little, false);
    try testIntSerializerDeserializer(builtin.Endian.Big, true);
    try testIntSerializerDeserializer(builtin.Endian.Little, true);
}

fn testSerializerDeserializer(comptime endian: builtin.Endian, comptime is_packed: bool) !void {
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

        pub fn serialize(self: *const @This(), serializer: var) !void {
            try serializer.serialize(self.f_f16);
        }
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
    var serializer = io.Serializer(endian, is_packed, OutError).init(out_stream);

    var in = io.SliceInStream.init(data_mem[0..]);
    const InError = io.SliceInStream.Error;
    var in_stream = &in.stream;
    var deserializer = io.Deserializer(endian, is_packed, InError).init(in_stream);

    try serializer.serialize(my_inst);

    const my_copy = try deserializer.deserialize(MyStruct);

    assert(meta.eql(my_copy, my_inst));
}

test "Serializer/Deserializer generic" {
    try testSerializerDeserializer(builtin.Endian.Big, false);
    try testSerializerDeserializer(builtin.Endian.Little, false);
    try testSerializerDeserializer(builtin.Endian.Big, true);
    try testSerializerDeserializer(builtin.Endian.Little, true);
}

fn testBadData(comptime endian: builtin.Endian, comptime is_packed: bool) !void {
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
    var serializer = io.Serializer(endian, is_packed, OutError).init(out_stream);

    var in = io.SliceInStream.init(data_mem[0..]);
    const InError = io.SliceInStream.Error;
    var in_stream = &in.stream;
    var deserializer = io.Deserializer(endian, is_packed, InError).init(in_stream);

    try serializer.serialize(u14(3));
    assertError(deserializer.deserialize(A), error.InvalidEnumTag);
    out.pos = 0;
    try serializer.serialize(u14(3));
    try serializer.serialize(u14(88));
    assertError(deserializer.deserialize(C), error.InvalidEnumTag);
}

test "Deserializer bad data" {
    try testBadData(builtin.Endian.Big, false);
    try testBadData(builtin.Endian.Little, false);
    try testBadData(builtin.Endian.Big, true);
    try testBadData(builtin.Endian.Little, true);
}