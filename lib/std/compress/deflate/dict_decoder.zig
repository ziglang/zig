const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

const Allocator = std.mem.Allocator;

// Implements the LZ77 sliding dictionary as used in decompression.
// LZ77 decompresses data through sequences of two forms of commands:
//
//  * Literal insertions: Runs of one or more symbols are inserted into the data
//  stream as is. This is accomplished through the writeByte method for a
//  single symbol, or combinations of writeSlice/writeMark for multiple symbols.
//  Any valid stream must start with a literal insertion if no preset dictionary
//  is used.
//
//  * Backward copies: Runs of one or more symbols are copied from previously
//  emitted data. Backward copies come as the tuple (dist, length) where dist
//  determines how far back in the stream to copy from and length determines how
//  many bytes to copy. Note that it is valid for the length to be greater than
//  the distance. Since LZ77 uses forward copies, that situation is used to
//  perform a form of run-length encoding on repeated runs of symbols.
//  The writeCopy and tryWriteCopy are used to implement this command.
//
// For performance reasons, this implementation performs little to no sanity
// checks about the arguments. As such, the invariants documented for each
// method call must be respected.
pub const DictDecoder = struct {
    const Self = @This();

    allocator: Allocator = undefined,

    hist: []u8 = undefined, // Sliding window history

    // Invariant: 0 <= rd_pos <= wr_pos <= hist.len
    wr_pos: u32 = 0, // Current output position in buffer
    rd_pos: u32 = 0, // Have emitted hist[0..rd_pos] already
    full: bool = false, // Has a full window length been written yet?

    // init initializes DictDecoder to have a sliding window dictionary of the given
    // size. If a preset dict is provided, it will initialize the dictionary with
    // the contents of dict.
    pub fn init(self: *Self, allocator: Allocator, size: u32, dict: ?[]const u8) !void {
        self.allocator = allocator;

        self.hist = try allocator.alloc(u8, size);

        self.wr_pos = 0;

        if (dict != null) {
            const src = dict.?[dict.?.len -| self.hist.len..];
            @memcpy(self.hist[0..src.len], src);
            self.wr_pos = @as(u32, @intCast(dict.?.len));
        }

        if (self.wr_pos == self.hist.len) {
            self.wr_pos = 0;
            self.full = true;
        }
        self.rd_pos = self.wr_pos;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.hist);
    }

    // Reports the total amount of historical data in the dictionary.
    pub fn histSize(self: *Self) u32 {
        if (self.full) {
            return @as(u32, @intCast(self.hist.len));
        }
        return self.wr_pos;
    }

    // Reports the number of bytes that can be flushed by readFlush.
    pub fn availRead(self: *Self) u32 {
        return self.wr_pos - self.rd_pos;
    }

    // Reports the available amount of output buffer space.
    pub fn availWrite(self: *Self) u32 {
        return @as(u32, @intCast(self.hist.len - self.wr_pos));
    }

    // Returns a slice of the available buffer to write data to.
    //
    // This invariant will be kept: s.len <= availWrite()
    pub fn writeSlice(self: *Self) []u8 {
        return self.hist[self.wr_pos..];
    }

    // Advances the writer pointer by `count`.
    //
    // This invariant must be kept: 0 <= count <= availWrite()
    pub fn writeMark(self: *Self, count: u32) void {
        assert(0 <= count and count <= self.availWrite());
        self.wr_pos += count;
    }

    // Writes a single byte to the dictionary.
    //
    // This invariant must be kept: 0 < availWrite()
    pub fn writeByte(self: *Self, byte: u8) void {
        self.hist[self.wr_pos] = byte;
        self.wr_pos += 1;
    }

    /// TODO: eliminate this function because the callsites should care about whether
    /// or not their arguments alias and then they should directly call `@memcpy` or
    /// `mem.copyForwards`.
    fn copy(dst: []u8, src: []const u8) u32 {
        if (src.len > dst.len) {
            mem.copyForwards(u8, dst, src[0..dst.len]);
            return @as(u32, @intCast(dst.len));
        }
        mem.copyForwards(u8, dst[0..src.len], src);
        return @as(u32, @intCast(src.len));
    }

    // Copies a string at a given (dist, length) to the output.
    // This returns the number of bytes copied and may be less than the requested
    // length if the available space in the output buffer is too small.
    //
    // This invariant must be kept: 0 < dist <= histSize()
    pub fn writeCopy(self: *Self, dist: u32, length: u32) u32 {
        assert(0 < dist and dist <= self.histSize());
        var dst_base = self.wr_pos;
        var dst_pos = dst_base;
        var src_pos: i32 = @as(i32, @intCast(dst_pos)) - @as(i32, @intCast(dist));
        var end_pos = dst_pos + length;
        if (end_pos > self.hist.len) {
            end_pos = @as(u32, @intCast(self.hist.len));
        }

        // Copy non-overlapping section after destination position.
        //
        // This section is non-overlapping in that the copy length for this section
        // is always less than or equal to the backwards distance. This can occur
        // if a distance refers to data that wraps-around in the buffer.
        // Thus, a backwards copy is performed here; that is, the exact bytes in
        // the source prior to the copy is placed in the destination.
        if (src_pos < 0) {
            src_pos += @as(i32, @intCast(self.hist.len));
            dst_pos += copy(self.hist[dst_pos..end_pos], self.hist[@as(usize, @intCast(src_pos))..]);
            src_pos = 0;
        }

        // Copy possibly overlapping section before destination position.
        //
        // This section can overlap if the copy length for this section is larger
        // than the backwards distance. This is allowed by LZ77 so that repeated
        // strings can be succinctly represented using (dist, length) pairs.
        // Thus, a forwards copy is performed here; that is, the bytes copied is
        // possibly dependent on the resulting bytes in the destination as the copy
        // progresses along. This is functionally equivalent to the following:
        //
        //    var i = 0;
        //    while(i < end_pos - dst_pos) : (i+=1) {
        //        self.hist[dst_pos+i] = self.hist[src_pos+i];
        //    }
        //    dst_pos = end_pos;
        //
        while (dst_pos < end_pos) {
            dst_pos += copy(self.hist[dst_pos..end_pos], self.hist[@as(usize, @intCast(src_pos))..dst_pos]);
        }

        self.wr_pos = dst_pos;
        return dst_pos - dst_base;
    }

    // Tries to copy a string at a given (distance, length) to the
    // output. This specialized version is optimized for short distances.
    //
    // This method is designed to be inlined for performance reasons.
    //
    // This invariant must be kept: 0 < dist <= histSize()
    pub fn tryWriteCopy(self: *Self, dist: u32, length: u32) u32 {
        var dst_pos = self.wr_pos;
        var end_pos = dst_pos + length;
        if (dst_pos < dist or end_pos > self.hist.len) {
            return 0;
        }
        var dst_base = dst_pos;
        var src_pos = dst_pos - dist;

        // Copy possibly overlapping section before destination position.
        while (dst_pos < end_pos) {
            dst_pos += copy(self.hist[dst_pos..end_pos], self.hist[src_pos..dst_pos]);
        }

        self.wr_pos = dst_pos;
        return dst_pos - dst_base;
    }

    // Returns a slice of the historical buffer that is ready to be
    // emitted to the user. The data returned by readFlush must be fully consumed
    // before calling any other DictDecoder methods.
    pub fn readFlush(self: *Self) []u8 {
        var to_read = self.hist[self.rd_pos..self.wr_pos];
        self.rd_pos = self.wr_pos;
        if (self.wr_pos == self.hist.len) {
            self.wr_pos = 0;
            self.rd_pos = 0;
            self.full = true;
        }
        return to_read;
    }
};

// tests

test "dictionary decoder" {
    const ArrayList = std.ArrayList;
    const testing = std.testing;

    const abc = "ABC\n";
    const fox = "The quick brown fox jumped over the lazy dog!\n";
    const poem: []const u8 =
        \\The Road Not Taken
        \\Robert Frost
        \\
        \\Two roads diverged in a yellow wood,
        \\And sorry I could not travel both
        \\And be one traveler, long I stood
        \\And looked down one as far as I could
        \\To where it bent in the undergrowth;
        \\
        \\Then took the other, as just as fair,
        \\And having perhaps the better claim,
        \\Because it was grassy and wanted wear;
        \\Though as for that the passing there
        \\Had worn them really about the same,
        \\
        \\And both that morning equally lay
        \\In leaves no step had trodden black.
        \\Oh, I kept the first for another day!
        \\Yet knowing how way leads on to way,
        \\I doubted if I should ever come back.
        \\
        \\I shall be telling this with a sigh
        \\Somewhere ages and ages hence:
        \\Two roads diverged in a wood, and I-
        \\I took the one less traveled by,
        \\And that has made all the difference.
        \\
    ;

    const uppercase: []const u8 =
        \\THE ROAD NOT TAKEN
        \\ROBERT FROST
        \\
        \\TWO ROADS DIVERGED IN A YELLOW WOOD,
        \\AND SORRY I COULD NOT TRAVEL BOTH
        \\AND BE ONE TRAVELER, LONG I STOOD
        \\AND LOOKED DOWN ONE AS FAR AS I COULD
        \\TO WHERE IT BENT IN THE UNDERGROWTH;
        \\
        \\THEN TOOK THE OTHER, AS JUST AS FAIR,
        \\AND HAVING PERHAPS THE BETTER CLAIM,
        \\BECAUSE IT WAS GRASSY AND WANTED WEAR;
        \\THOUGH AS FOR THAT THE PASSING THERE
        \\HAD WORN THEM REALLY ABOUT THE SAME,
        \\
        \\AND BOTH THAT MORNING EQUALLY LAY
        \\IN LEAVES NO STEP HAD TRODDEN BLACK.
        \\OH, I KEPT THE FIRST FOR ANOTHER DAY!
        \\YET KNOWING HOW WAY LEADS ON TO WAY,
        \\I DOUBTED IF I SHOULD EVER COME BACK.
        \\
        \\I SHALL BE TELLING THIS WITH A SIGH
        \\SOMEWHERE AGES AND AGES HENCE:
        \\TWO ROADS DIVERGED IN A WOOD, AND I-
        \\I TOOK THE ONE LESS TRAVELED BY,
        \\AND THAT HAS MADE ALL THE DIFFERENCE.
        \\
    ;

    const PoemRefs = struct {
        dist: u32, // Backward distance (0 if this is an insertion)
        length: u32, // Length of copy or insertion
    };

    var poem_refs = [_]PoemRefs{
        .{ .dist = 0, .length = 38 },  .{ .dist = 33, .length = 3 },   .{ .dist = 0, .length = 48 },
        .{ .dist = 79, .length = 3 },  .{ .dist = 0, .length = 11 },   .{ .dist = 34, .length = 5 },
        .{ .dist = 0, .length = 6 },   .{ .dist = 23, .length = 7 },   .{ .dist = 0, .length = 8 },
        .{ .dist = 50, .length = 3 },  .{ .dist = 0, .length = 2 },    .{ .dist = 69, .length = 3 },
        .{ .dist = 34, .length = 5 },  .{ .dist = 0, .length = 4 },    .{ .dist = 97, .length = 3 },
        .{ .dist = 0, .length = 4 },   .{ .dist = 43, .length = 5 },   .{ .dist = 0, .length = 6 },
        .{ .dist = 7, .length = 4 },   .{ .dist = 88, .length = 7 },   .{ .dist = 0, .length = 12 },
        .{ .dist = 80, .length = 3 },  .{ .dist = 0, .length = 2 },    .{ .dist = 141, .length = 4 },
        .{ .dist = 0, .length = 1 },   .{ .dist = 196, .length = 3 },  .{ .dist = 0, .length = 3 },
        .{ .dist = 157, .length = 3 }, .{ .dist = 0, .length = 6 },    .{ .dist = 181, .length = 3 },
        .{ .dist = 0, .length = 2 },   .{ .dist = 23, .length = 3 },   .{ .dist = 77, .length = 3 },
        .{ .dist = 28, .length = 5 },  .{ .dist = 128, .length = 3 },  .{ .dist = 110, .length = 4 },
        .{ .dist = 70, .length = 3 },  .{ .dist = 0, .length = 4 },    .{ .dist = 85, .length = 6 },
        .{ .dist = 0, .length = 2 },   .{ .dist = 182, .length = 6 },  .{ .dist = 0, .length = 4 },
        .{ .dist = 133, .length = 3 }, .{ .dist = 0, .length = 7 },    .{ .dist = 47, .length = 5 },
        .{ .dist = 0, .length = 20 },  .{ .dist = 112, .length = 5 },  .{ .dist = 0, .length = 1 },
        .{ .dist = 58, .length = 3 },  .{ .dist = 0, .length = 8 },    .{ .dist = 59, .length = 3 },
        .{ .dist = 0, .length = 4 },   .{ .dist = 173, .length = 3 },  .{ .dist = 0, .length = 5 },
        .{ .dist = 114, .length = 3 }, .{ .dist = 0, .length = 4 },    .{ .dist = 92, .length = 5 },
        .{ .dist = 0, .length = 2 },   .{ .dist = 71, .length = 3 },   .{ .dist = 0, .length = 2 },
        .{ .dist = 76, .length = 5 },  .{ .dist = 0, .length = 1 },    .{ .dist = 46, .length = 3 },
        .{ .dist = 96, .length = 4 },  .{ .dist = 130, .length = 4 },  .{ .dist = 0, .length = 3 },
        .{ .dist = 360, .length = 3 }, .{ .dist = 0, .length = 3 },    .{ .dist = 178, .length = 5 },
        .{ .dist = 0, .length = 7 },   .{ .dist = 75, .length = 3 },   .{ .dist = 0, .length = 3 },
        .{ .dist = 45, .length = 6 },  .{ .dist = 0, .length = 6 },    .{ .dist = 299, .length = 6 },
        .{ .dist = 180, .length = 3 }, .{ .dist = 70, .length = 6 },   .{ .dist = 0, .length = 1 },
        .{ .dist = 48, .length = 3 },  .{ .dist = 66, .length = 4 },   .{ .dist = 0, .length = 3 },
        .{ .dist = 47, .length = 5 },  .{ .dist = 0, .length = 9 },    .{ .dist = 325, .length = 3 },
        .{ .dist = 0, .length = 1 },   .{ .dist = 359, .length = 3 },  .{ .dist = 318, .length = 3 },
        .{ .dist = 0, .length = 2 },   .{ .dist = 199, .length = 3 },  .{ .dist = 0, .length = 1 },
        .{ .dist = 344, .length = 3 }, .{ .dist = 0, .length = 3 },    .{ .dist = 248, .length = 3 },
        .{ .dist = 0, .length = 10 },  .{ .dist = 310, .length = 3 },  .{ .dist = 0, .length = 3 },
        .{ .dist = 93, .length = 6 },  .{ .dist = 0, .length = 3 },    .{ .dist = 252, .length = 3 },
        .{ .dist = 157, .length = 4 }, .{ .dist = 0, .length = 2 },    .{ .dist = 273, .length = 5 },
        .{ .dist = 0, .length = 14 },  .{ .dist = 99, .length = 4 },   .{ .dist = 0, .length = 1 },
        .{ .dist = 464, .length = 4 }, .{ .dist = 0, .length = 2 },    .{ .dist = 92, .length = 4 },
        .{ .dist = 495, .length = 3 }, .{ .dist = 0, .length = 1 },    .{ .dist = 322, .length = 4 },
        .{ .dist = 16, .length = 4 },  .{ .dist = 0, .length = 3 },    .{ .dist = 402, .length = 3 },
        .{ .dist = 0, .length = 2 },   .{ .dist = 237, .length = 4 },  .{ .dist = 0, .length = 2 },
        .{ .dist = 432, .length = 4 }, .{ .dist = 0, .length = 1 },    .{ .dist = 483, .length = 5 },
        .{ .dist = 0, .length = 2 },   .{ .dist = 294, .length = 4 },  .{ .dist = 0, .length = 2 },
        .{ .dist = 306, .length = 3 }, .{ .dist = 113, .length = 5 },  .{ .dist = 0, .length = 1 },
        .{ .dist = 26, .length = 4 },  .{ .dist = 164, .length = 3 },  .{ .dist = 488, .length = 4 },
        .{ .dist = 0, .length = 1 },   .{ .dist = 542, .length = 3 },  .{ .dist = 248, .length = 6 },
        .{ .dist = 0, .length = 5 },   .{ .dist = 205, .length = 3 },  .{ .dist = 0, .length = 8 },
        .{ .dist = 48, .length = 3 },  .{ .dist = 449, .length = 6 },  .{ .dist = 0, .length = 2 },
        .{ .dist = 192, .length = 3 }, .{ .dist = 328, .length = 4 },  .{ .dist = 9, .length = 5 },
        .{ .dist = 433, .length = 3 }, .{ .dist = 0, .length = 3 },    .{ .dist = 622, .length = 25 },
        .{ .dist = 615, .length = 5 }, .{ .dist = 46, .length = 5 },   .{ .dist = 0, .length = 2 },
        .{ .dist = 104, .length = 3 }, .{ .dist = 475, .length = 10 }, .{ .dist = 549, .length = 3 },
        .{ .dist = 0, .length = 4 },   .{ .dist = 597, .length = 8 },  .{ .dist = 314, .length = 3 },
        .{ .dist = 0, .length = 1 },   .{ .dist = 473, .length = 6 },  .{ .dist = 317, .length = 5 },
        .{ .dist = 0, .length = 1 },   .{ .dist = 400, .length = 3 },  .{ .dist = 0, .length = 3 },
        .{ .dist = 109, .length = 3 }, .{ .dist = 151, .length = 3 },  .{ .dist = 48, .length = 4 },
        .{ .dist = 0, .length = 4 },   .{ .dist = 125, .length = 3 },  .{ .dist = 108, .length = 3 },
        .{ .dist = 0, .length = 2 },
    };

    var got_list = ArrayList(u8).init(testing.allocator);
    defer got_list.deinit();
    var got = got_list.writer();

    var want_list = ArrayList(u8).init(testing.allocator);
    defer want_list.deinit();
    var want = want_list.writer();

    var dd = DictDecoder{};
    try dd.init(testing.allocator, 1 << 11, null);
    defer dd.deinit();

    const util = struct {
        fn writeCopy(dst_dd: *DictDecoder, dst: anytype, dist: u32, length: u32) !void {
            var len = length;
            while (len > 0) {
                var n = dst_dd.tryWriteCopy(dist, len);
                if (n == 0) {
                    n = dst_dd.writeCopy(dist, len);
                }

                len -= n;
                if (dst_dd.availWrite() == 0) {
                    _ = try dst.write(dst_dd.readFlush());
                }
            }
        }
        fn writeString(dst_dd: *DictDecoder, dst: anytype, str: []const u8) !void {
            var string = str;
            while (string.len > 0) {
                var cnt = DictDecoder.copy(dst_dd.writeSlice(), string);
                dst_dd.writeMark(cnt);
                string = string[cnt..];
                if (dst_dd.availWrite() == 0) {
                    _ = try dst.write(dst_dd.readFlush());
                }
            }
        }
    };

    try util.writeString(&dd, got, ".");
    _ = try want.write(".");

    var str = poem;
    for (poem_refs, 0..) |ref, i| {
        _ = i;
        if (ref.dist == 0) {
            try util.writeString(&dd, got, str[0..ref.length]);
        } else {
            try util.writeCopy(&dd, got, ref.dist, ref.length);
        }
        str = str[ref.length..];
    }
    _ = try want.write(poem);

    try util.writeCopy(&dd, got, dd.histSize(), 33);
    _ = try want.write(want_list.items[0..33]);

    try util.writeString(&dd, got, abc);
    try util.writeCopy(&dd, got, abc.len, 59 * abc.len);
    _ = try want.write(abc ** 60);

    try util.writeString(&dd, got, fox);
    try util.writeCopy(&dd, got, fox.len, 9 * fox.len);
    _ = try want.write(fox ** 10);

    try util.writeString(&dd, got, ".");
    try util.writeCopy(&dd, got, 1, 9);
    _ = try want.write("." ** 10);

    try util.writeString(&dd, got, uppercase);
    try util.writeCopy(&dd, got, uppercase.len, 7 * uppercase.len);
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        _ = try want.write(uppercase);
    }

    try util.writeCopy(&dd, got, dd.histSize(), 10);
    _ = try want.write(want_list.items[want_list.items.len - dd.histSize() ..][0..10]);

    _ = try got.write(dd.readFlush());
    try testing.expectEqualSlices(u8, want_list.items, got_list.items);
}
