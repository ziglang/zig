const std = @import("index.zig");
const io = std.io;
const allocator = std.debug.global_allocator;
const Rand = std.rand.Rand;
const assert = std.debug.assert;
const mem = std.mem;
const os = std.os;
const builtin = @import("builtin");

test "write a file, read it, then delete it" {
    var data: [1024]u8 = undefined;
    var rng = Rand.init(1234);
    rng.fillBytes(data[0..]);
    const tmp_file_name = "temp_test_file.txt";
    {
        var file = try io.File.openWrite(tmp_file_name, allocator);
        defer file.close();

        var file_out_stream = io.FileOutStream.init(&file);
        var buf_stream = io.BufferedOutStream(io.FileOutStream.Error).init(&file_out_stream.stream);
        const st = &buf_stream.stream;
        try st.print("begin");
        try st.write(data[0..]);
        try st.print("end");
        try buf_stream.flush();
    }
    {
        var file = try io.File.openRead(tmp_file_name, allocator);
        defer file.close();

        const file_size = try file.getEndPos();
        const expected_file_size = "begin".len + data.len + "end".len;
        assert(file_size == expected_file_size);

        var file_in_stream = io.FileInStream.init(&file);
        var buf_stream = io.BufferedInStream(io.FileInStream.Error).init(&file_in_stream.stream);
        const st = &buf_stream.stream;
        const contents = try st.readAllAlloc(allocator, 2 * 1024);
        defer allocator.free(contents);

        assert(mem.eql(u8, contents[0.."begin".len], "begin"));
        assert(mem.eql(u8, contents["begin".len..contents.len - "end".len], data));
        assert(mem.eql(u8, contents[contents.len - "end".len ..], "end"));
    }
    try os.deleteFile(allocator, tmp_file_name);
}
