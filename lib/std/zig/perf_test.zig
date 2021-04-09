// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const Tokenizer = std.zig.Tokenizer;
const Parser = std.zig.Parser;
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
    const elapsed_s = @intToFloat(f64, end - start) / std.time.ns_per_s;
    const bytes_per_sec_float = @intToFloat(f64, source.len * iterations) / elapsed_s;
    const bytes_per_sec = @floatToInt(u64, @floor(bytes_per_sec_float));

    var stdout_file = std.io.getStdOut();
    const stdout = stdout_file.writer();
    try stdout.print("parsing speed: {:.2}/s, {:.2} used \n", .{
        fmtIntSizeBin(bytes_per_sec),
        fmtIntSizeBin(memory_used),
    });
}

fn testOnce() usize {
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
    var allocator = &fixed_buf_alloc.allocator;
    _ = std.zig.parse(allocator, source) catch @panic("parse failure");
    return fixed_buf_alloc.end_index;
}
