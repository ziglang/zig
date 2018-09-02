const std = @import("index.zig");
const io = std.io;
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

        var file_out_stream = io.FileOutStream.init(file);
        var buf_stream = io.BufferedOutStream(io.FileOutStream.Error).init(&file_out_stream.stream);
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

        var file_in_stream = io.FileInStream.init(file);
        var buf_stream = io.BufferedInStream(io.FileInStream.Error).init(&file_in_stream.stream);
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
