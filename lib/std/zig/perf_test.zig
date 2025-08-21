const std = @import("std");
const mem = std.mem;
const Tokenizer = std.zig.Tokenizer;
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
    const elapsed_s = @as(f64, @floatFromInt(end - start)) / std.time.ns_per_s;
    const bytes_per_sec_float = @as(f64, @floatFromInt(source.len * iterations)) / elapsed_s;
    const bytes_per_sec = @as(u64, @intFromFloat(@floor(bytes_per_sec_float)));

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("parsing speed: {Bi:.2}/s, {Bi:.2} used \n", .{ bytes_per_sec, memory_used });
    try stdout.flush();
}

fn testOnce() usize {
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(&fixed_buffer_mem);
    const allocator = fixed_buf_alloc.allocator();
    _ = std.zig.Ast.parse(allocator, source, .zig) catch @panic("parse failure");
    return fixed_buf_alloc.end_index;
}
