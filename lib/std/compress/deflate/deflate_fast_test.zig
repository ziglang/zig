const std = @import("std");
const expect = std.testing.expect;
const io = std.io;
const mem = std.mem;
const testing = std.testing;

const ArrayList = std.ArrayList;

const deflate = @import("compressor.zig");
const inflate = @import("decompressor.zig");
const deflate_const = @import("deflate_const.zig");

test "best speed" {
    // Tests that round-tripping through deflate and then inflate recovers the original input.
    // The Write sizes are near the thresholds in the compressor.encSpeed method (0, 16, 128), as well
    // as near `deflate_const.max_store_block_size` (65535).

    var abcabc = try testing.allocator.alloc(u8, 131_072);
    defer testing.allocator.free(abcabc);

    for (abcabc, 0..) |_, i| {
        abcabc[i] = @as(u8, @intCast(i % 128));
    }

    var tc_01 = [_]u32{ 65536, 0 };
    var tc_02 = [_]u32{ 65536, 1 };
    var tc_03 = [_]u32{ 65536, 1, 256 };
    var tc_04 = [_]u32{ 65536, 1, 65536 };
    var tc_05 = [_]u32{ 65536, 14 };
    var tc_06 = [_]u32{ 65536, 15 };
    var tc_07 = [_]u32{ 65536, 16 };
    var tc_08 = [_]u32{ 65536, 16, 256 };
    var tc_09 = [_]u32{ 65536, 16, 65536 };
    var tc_10 = [_]u32{ 65536, 127 };
    var tc_11 = [_]u32{ 65536, 127 };
    var tc_12 = [_]u32{ 65536, 128 };
    var tc_13 = [_]u32{ 65536, 128, 256 };
    var tc_14 = [_]u32{ 65536, 128, 65536 };
    var tc_15 = [_]u32{ 65536, 129 };
    var tc_16 = [_]u32{ 65536, 65536, 256 };
    var tc_17 = [_]u32{ 65536, 65536, 65536 };
    const test_cases = [_][]u32{
        &tc_01, &tc_02, &tc_03, &tc_04, &tc_05, &tc_06, &tc_07, &tc_08, &tc_09, &tc_10,
        &tc_11, &tc_12, &tc_13, &tc_14, &tc_15, &tc_16, &tc_17,
    };

    for (test_cases) |tc| {
        const firsts = [_]u32{ 1, 65534, 65535, 65536, 65537, 131072 };

        for (firsts) |first_n| {
            tc[0] = first_n;

            const to_flush = [_]bool{ false, true };
            for (to_flush) |flush| {
                var compressed = ArrayList(u8).init(testing.allocator);
                defer compressed.deinit();

                var want = ArrayList(u8).init(testing.allocator);
                defer want.deinit();

                var comp = try deflate.compressor(
                    testing.allocator,
                    compressed.writer(),
                    .{ .level = .best_speed },
                );
                defer comp.deinit();

                for (tc) |n| {
                    try want.appendSlice(abcabc[0..n]);
                    try comp.writer().writeAll(abcabc[0..n]);
                    if (flush) {
                        try comp.flush();
                    }
                }

                try comp.close();

                const decompressed = try testing.allocator.alloc(u8, want.items.len);
                defer testing.allocator.free(decompressed);

                var fib = io.fixedBufferStream(compressed.items);
                var decomp = try inflate.decompressor(testing.allocator, fib.reader(), null);
                defer decomp.deinit();

                const read = try decomp.reader().readAll(decompressed);
                try decomp.close();

                try testing.expectEqual(want.items.len, read);
                try testing.expectEqualSlices(u8, want.items, decompressed);
            }
        }
    }
}

test "best speed max match offset" {
    const abc = "abcdefgh";
    const xyz = "stuvwxyz";
    const input_margin = 16 - 1;

    const match_before = [_]bool{ false, true };
    for (match_before) |do_match_before| {
        const extras = [_]u32{
            0,
            input_margin - 1,
            input_margin,
            input_margin + 1,
            2 * input_margin,
        };
        for (extras) |extra| {
            var offset_adj: i32 = -5;
            while (offset_adj <= 5) : (offset_adj += 1) {
                const offset = deflate_const.max_match_offset + offset_adj;

                // Make src to be a []u8 of the form
                //	fmt("{s}{s}{s}{s}{s}", .{abc, zeros0, xyzMaybe, abc, zeros1})
                // where:
                //	zeros0 is approximately max_match_offset zeros.
                //	xyzMaybe is either xyz or the empty string.
                //	zeros1 is between 0 and 30 zeros.
                // The difference between the two abc's will be offset, which
                // is max_match_offset plus or minus a small adjustment.
                const src_len: usize = @as(usize, @intCast(offset + @as(i32, abc.len) + @as(i32, @intCast(extra))));
                var src = try testing.allocator.alloc(u8, src_len);
                defer testing.allocator.free(src);

                @memcpy(src[0..abc.len], abc);
                if (!do_match_before) {
                    const src_offset: usize = @as(usize, @intCast(offset - @as(i32, xyz.len)));
                    @memcpy(src[src_offset..][0..xyz.len], xyz);
                }
                const src_offset: usize = @as(usize, @intCast(offset));
                @memcpy(src[src_offset..][0..abc.len], abc);

                var compressed = ArrayList(u8).init(testing.allocator);
                defer compressed.deinit();

                var comp = try deflate.compressor(
                    testing.allocator,
                    compressed.writer(),
                    .{ .level = .best_speed },
                );
                defer comp.deinit();
                try comp.writer().writeAll(src);
                _ = try comp.close();

                const decompressed = try testing.allocator.alloc(u8, src.len);
                defer testing.allocator.free(decompressed);

                var fib = io.fixedBufferStream(compressed.items);
                var decomp = try inflate.decompressor(testing.allocator, fib.reader(), null);
                defer decomp.deinit();
                const read = try decomp.reader().readAll(decompressed);
                try decomp.close();

                try testing.expectEqual(src.len, read);
                try testing.expectEqualSlices(u8, src, decompressed);
            }
        }
    }
}
