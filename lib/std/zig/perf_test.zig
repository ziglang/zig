const std = @import("std");
const mem = std.mem;
const Tokenizer = std.zig.Tokenizer;
const io = std.io;
const fmtIntSizeBin = std.fmt.fmtIntSizeBin;

const source = @embedFile("../os.zig");
var fixed_buffer_mem: [10 * 1024 * 1024]u8 = undefined;

pub fn main() !void {
    var i: usize = 0;
    var timer = try std.time.Timer.start();
    const start = timer.lap();
    const iterations = 100;
    var memory_used: usize = 0;
    while (i < iterations) : (i += 1) {
        memory_used += testOnce();
    }
    const end = timer.read();
    memory_used /= iterations;
    const elapsed_s = @floatFromInt(f64, end - start) / std.time.ns_per_s;
    const bytes_per_sec_float = @floatFromInt(f64, source.len * iterations) / elapsed_s;
    const bytes_per_sec = @intFromFloat(u64, @floor(bytes_per_sec_float));

    var stdout_file = std.io.getStdOut();
    const stdout = stdout_file.writer();
    try stdout.print("parsing speed: {:.2}/s, {:.2} used \n", .{
        fmtIntSizeBin(bytes_per_sec),
        fmtIntSizeBin(memory_used),
    });
}

fn testOnce() usize {
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
    var allocator = fixed_buf_alloc.allocator();
    _ = std.zig.Ast.parse(allocator, source, .zig) catch @panic("parse failure");
    return fixed_buf_alloc.end_index;
}
