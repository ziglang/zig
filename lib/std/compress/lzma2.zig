const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

pub const decode = @import("lzma2/decode.zig");

pub fn decompress(allocator: Allocator, reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
    var decoder = try decode.Decoder.init(allocator);
    defer decoder.deinit(allocator);
    return decoder.decompress(allocator, reader, writer);
}

test {
    const expected = "Hello\nWorld!\n";
    const compressed = &[_]u8{
        0x01, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x0A, 0x02,
        0x00, 0x06, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21, 0x0A, 0x00,
    };
    var stream: std.io.BufferedReader = undefined;
    stream.initFixed(&compressed);
    var decomp: std.io.AllocatingWriter = undefined;
    const decomp_bw = decomp.init(std.testing.allocator);
    defer decomp.deinit();
    try decompress(std.testing.allocator, &stream, decomp_bw);
    try std.testing.expectEqualSlices(u8, expected, decomp.getWritten());
}
