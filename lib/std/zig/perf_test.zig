// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const Tokenizer = std.zig.Tokenizer;
const Parser = std.zig.Parser;
const io = std.io;

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
    const bytes_per_sec = @intToFloat(f64, source.len * iterations) / elapsed_s;
    const mb_per_sec = bytes_per_sec / (1024 * 1024);

    var stdout_file = std.io.getStdOut();
    const stdout = stdout_file.outStream();
    try stdout.print("{:.3} MiB/s, {} KiB used \n", .{ mb_per_sec, memory_used / 1024 });
}

fn testOnce() usize {
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
    var allocator = &fixed_buf_alloc.allocator;
    _ = std.zig.parse(allocator, source) catch @panic("parse failure");
    return fixed_buf_alloc.end_index;
}
