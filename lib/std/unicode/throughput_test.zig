// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();

    const args = try std.process.argsAlloc(std.heap.page_allocator);

    // Warm up runs
    var buffer0: [32767]u16 align(4096) = undefined;
    _ = try std.unicode.utf8ToUtf16Le(&buffer0, args[1]);
    _ = try std.unicode.utf8ToUtf16Le_better(&buffer0, args[1]);

    @fence(.SeqCst);
    var timer = try std.time.Timer.start();
    @fence(.SeqCst);

    var buffer1: [32767]u16 align(4096) = undefined;
    _ = try std.unicode.utf8ToUtf16Le(&buffer1, args[1]);

    @fence(.SeqCst);
    const elapsed_ns_orig = timer.lap();
    @fence(.SeqCst);

    var buffer2: [32767]u16 align(4096) = undefined;
    _ = try std.unicode.utf8ToUtf16Le_better(&buffer2, args[1]);

    @fence(.SeqCst);
    const elapsed_ns_better = timer.lap();
    @fence(.SeqCst);

    std.debug.warn("original utf8ToUtf16Le: elapsed: {} ns ({} ms)\n", .{
        elapsed_ns_orig, elapsed_ns_orig / 1000000,
    });
    std.debug.warn("new utf8ToUtf16Le: elapsed: {} ns ({} ms)\n", .{
        elapsed_ns_better, elapsed_ns_better / 1000000,
    });
    asm volatile ("nop"
        :
        : [a] "r" (&buffer1),
          [b] "r" (&buffer2)
        : "memory"
    );
}
