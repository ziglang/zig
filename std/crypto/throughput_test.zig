// Modify the HashFunction variable to the one wanted to test.
//
// NOTE: The throughput measurement may be slightly lower than other measurements since we run
// through our block alignment functions as well. Be aware when comparing against other tests.
//
// ```
// zig build-exe --release-fast --library c throughput_test.zig
// ./throughput_test
// ```

const std = @import("std");
const c = @cImport({
    @cInclude("time.h");
});
const HashFunction = @import("md5.zig").Md5;

const MB = 1024 * 1024;
const BytesToHash  = 1024 * MB;

pub fn main() !void {
    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = std.io.FileOutStream.init(&stdout_file);
    const stdout = &stdout_out_stream.stream;

    var block: [HashFunction.block_size]u8 = undefined;
    std.mem.set(u8, block[0..], 0);

    var h = HashFunction.init();
    var offset: usize = 0;

    const start = c.clock();
    while (offset < BytesToHash) : (offset += block.len) {
        h.update(block[0..]);
    }
    const end = c.clock();

    const elapsed_s = f64(end - start) / f64(c.CLOCKS_PER_SEC);
    const throughput = u64(BytesToHash / elapsed_s);

    try stdout.print("{}: ", @typeName(HashFunction));
    try stdout.print("{} MB/s\n", throughput / (1 * MB));
}
