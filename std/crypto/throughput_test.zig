// Modify the HashFunction variable to the one wanted to test.
//
// ```
// zig build-exe --release-fast throughput_test.zig
// ./throughput_test
// ```

const std = @import("std");
const time = std.os.time;
const Timer = time.Timer;
const HashFunction = @import("md5.zig").Md5;

const MiB = 1024 * 1024;
const BytesToHash = 1024 * MiB;

pub fn main() !void {
    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = std.io.FileOutStream.init(*stdout_file);
    const stdout = *stdout_out_stream.stream;

    var block: [HashFunction.block_size]u8 = undefined;
    std.mem.set(u8, block[0..], 0);

    var h = HashFunction.init();
    var offset: usize = 0;

    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < BytesToHash) : (offset += block.len) {
        h.update(block[0..]);
    }
    const end = timer.read();

    const elapsed_s = f64(end - start) / time.ns_per_s;
    const throughput = u64(BytesToHash / elapsed_s);

    try stdout.print("{}: {} MiB/s\n", @typeName(HashFunction), throughput / (1 * MiB));
}
