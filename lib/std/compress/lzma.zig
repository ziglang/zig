const std = @import("../std.zig");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;

pub const RangeDecoder = struct {
    range: u32,
    code: u32,

    pub fn init(reader: *Reader) !RangeDecoder {
        var counter: u64 = 0;
        return initCounting(reader, &counter);
    }

    pub fn initCounting(reader: *Reader, n_read: *u64) !RangeDecoder {
        const reserved = try reader.takeByte();
        n_read.* += 1;
        if (reserved != 0) return error.InvalidRangeCode;
        const code = try reader.takeInt(u32, .big);
        n_read.* += 4;
        return .{
            .range = 0xFFFF_FFFF,
            .code = code,
        };
    }

    pub fn isFinished(self: RangeDecoder) bool {
        return self.code == 0;
    }

    fn normalize(self: *RangeDecoder, reader: *Reader, n_read: *u64) !void {
        if (self.range < 0x0100_0000) {
            self.range <<= 8;
            self.code = (self.code << 8) ^ @as(u32, try reader.takeByte());
            n_read.* += 1;
        }
    }

    fn getBit(self: *RangeDecoder, reader: *Reader, n_read: *u64) !bool {
        self.range >>= 1;

        const bit = self.code >= self.range;
        if (bit) self.code -= self.range;

        try self.normalize(reader, n_read);
        return bit;
    }

    pub fn get(self: *RangeDecoder, reader: *Reader, count: usize, n_read: *u64) !u32 {
        var result: u32 = 0;
        for (0..count) |_| {
            result = (result << 1) ^ @intFromBool(try self.getBit(reader, n_read));
        }
        return result;
    }

    pub fn decodeBit(self: *RangeDecoder, reader: *Reader, prob: *u16, n_read: *u64) !bool {
        const bound = (self.range >> 11) * prob.*;

        if (self.code < bound) {
            prob.* += (0x800 - prob.*) >> 5;
            self.range = bound;

            try self.normalize(reader, n_read);
            return false;
        } else {
            prob.* -= prob.* >> 5;
            self.code -= bound;
            self.range -= bound;

            try self.normalize(reader, n_read);
            return true;
        }
    }

    fn parseBitTree(
        self: *RangeDecoder,
        reader: *Reader,
        num_bits: u5,
        probs: []u16,
        n_read: *u64,
    ) !u32 {
        var tmp: u32 = 1;
        var i: @TypeOf(num_bits) = 0;
        while (i < num_bits) : (i += 1) {
            const bit = try self.decodeBit(reader, &probs[tmp], n_read);
            tmp = (tmp << 1) ^ @intFromBool(bit);
        }
        return tmp - (@as(u32, 1) << num_bits);
    }

    pub fn parseReverseBitTree(
        self: *RangeDecoder,
        reader: *Reader,
        num_bits: u5,
        probs: []u16,
        offset: usize,
        n_read: *u64,
    ) !u32 {
        var result: u32 = 0;
        var tmp: usize = 1;
        var i: @TypeOf(num_bits) = 0;
        while (i < num_bits) : (i += 1) {
            const bit = @intFromBool(try self.decodeBit(reader, &probs[offset + tmp], n_read));
            tmp = (tmp << 1) ^ bit;
            result ^= @as(u32, bit) << i;
        }
        return result;
    }
};

pub const Decode = struct {
    properties: Properties,
    literal_probs: Vec2d,
    pos_slot_decoder: [4]BitTree(6),
    align_decoder: BitTree(4),
    pos_decoders: [115]u16,
    is_match: [192]u16,
    is_rep: [12]u16,
    is_rep_g0: [12]u16,
    is_rep_g1: [12]u16,
    is_rep_g2: [12]u16,
    is_rep_0long: [192]u16,
    state: usize,
    rep: [4]usize,
    len_decoder: LenDecoder,
    rep_len_decoder: LenDecoder,

    pub fn init(gpa: Allocator, properties: Properties) !Decode {
        return .{
            .properties = properties,
            .literal_probs = try Vec2d.init(gpa, 0x400, @as(usize, 1) << (properties.lc + properties.lp), 0x300),
            .pos_slot_decoder = @splat(.{}),
            .align_decoder = .{},
            .pos_decoders = @splat(0x400),
            .is_match = @splat(0x400),
            .is_rep = @splat(0x400),
            .is_rep_g0 = @splat(0x400),
            .is_rep_g1 = @splat(0x400),
            .is_rep_g2 = @splat(0x400),
            .is_rep_0long = @splat(0x400),
            .state = 0,
            .rep = @splat(0),
            .len_decoder = .{},
            .rep_len_decoder = .{},
        };
    }

    pub fn deinit(self: *Decode, gpa: Allocator) void {
        self.literal_probs.deinit(gpa);
        self.* = undefined;
    }

    pub fn resetState(self: *Decode, gpa: Allocator, new_props: Properties) !void {
        new_props.validate();
        if (self.properties.lc + self.properties.lp == new_props.lc + new_props.lp) {
            self.literal_probs.fill(0x400);
        } else {
            self.literal_probs.deinit(gpa);
            self.literal_probs = try Vec2d.init(gpa, 0x400, @as(usize, 1) << (new_props.lc + new_props.lp), 0x300);
        }

        self.properties = new_props;
        for (&self.pos_slot_decoder) |*t| t.reset();
        self.align_decoder.reset();
        self.pos_decoders = @splat(0x400);
        self.is_match = @splat(0x400);
        self.is_rep = @splat(0x400);
        self.is_rep_g0 = @splat(0x400);
        self.is_rep_g1 = @splat(0x400);
        self.is_rep_g2 = @splat(0x400);
        self.is_rep_0long = @splat(0x400);
        self.state = 0;
        self.rep = @splat(0);
        self.len_decoder.reset();
        self.rep_len_decoder.reset();
    }

    pub fn process(
        self: *Decode,
        reader: *Reader,
        allocating: *Writer.Allocating,
        /// `CircularBuffer` or `std.compress.lzma2.AccumBuffer`.
        buffer: anytype,
        decoder: *RangeDecoder,
        n_read: *u64,
    ) !ProcessingStatus {
        const gpa = allocating.allocator;
        const writer = &allocating.writer;
        const pos_state = buffer.len & ((@as(usize, 1) << self.properties.pb) - 1);

        if (!try decoder.decodeBit(reader, &self.is_match[(self.state << 4) + pos_state], n_read)) {
            const byte: u8 = try self.decodeLiteral(reader, buffer, decoder, n_read);

            try buffer.appendLiteral(gpa, byte, writer);

            self.state = if (self.state < 4)
                0
            else if (self.state < 10)
                self.state - 3
            else
                self.state - 6;
            return .more;
        }

        var len: usize = undefined;
        if (try decoder.decodeBit(reader, &self.is_rep[self.state], n_read)) {
            if (!try decoder.decodeBit(reader, &self.is_rep_g0[self.state], n_read)) {
                if (!try decoder.decodeBit(reader, &self.is_rep_0long[(self.state << 4) + pos_state], n_read)) {
                    self.state = if (self.state < 7) 9 else 11;
                    const dist = self.rep[0] + 1;
                    try buffer.appendLz(gpa, 1, dist, writer);
                    return .more;
                }
            } else {
                const idx: usize = if (!try decoder.decodeBit(reader, &self.is_rep_g1[self.state], n_read))
                    1
                else if (!try decoder.decodeBit(reader, &self.is_rep_g2[self.state], n_read))
                    2
                else
                    3;
                const dist = self.rep[idx];
                var i = idx;
                while (i > 0) : (i -= 1) {
                    self.rep[i] = self.rep[i - 1];
                }
                self.rep[0] = dist;
            }

            len = try self.rep_len_decoder.decode(reader, decoder, pos_state, n_read);

            self.state = if (self.state < 7) 8 else 11;
        } else {
            self.rep[3] = self.rep[2];
            self.rep[2] = self.rep[1];
            self.rep[1] = self.rep[0];

            len = try self.len_decoder.decode(reader, decoder, pos_state, n_read);

            self.state = if (self.state < 7) 7 else 10;

            const rep_0 = try self.decodeDistance(reader, decoder, len, n_read);

            self.rep[0] = rep_0;
            if (self.rep[0] == 0xFFFF_FFFF) {
                if (decoder.isFinished()) {
                    return .finished;
                }
                return error.CorruptInput;
            }
        }

        len += 2;

        const dist = self.rep[0] + 1;
        try buffer.appendLz(gpa, len, dist, writer);

        return .more;
    }

    fn decodeLiteral(
        self: *Decode,
        reader: *Reader,
        /// `CircularBuffer` or `std.compress.lzma2.AccumBuffer`.
        buffer: anytype,
        decoder: *RangeDecoder,
        n_read: *u64,
    ) !u8 {
        const def_prev_byte = 0;
        const prev_byte = @as(usize, buffer.lastOr(def_prev_byte));

        var result: usize = 1;
        const lit_state = ((buffer.len & ((@as(usize, 1) << self.properties.lp) - 1)) << self.properties.lc) +
            (prev_byte >> (8 - self.properties.lc));
        const probs = try self.literal_probs.get(lit_state);

        if (self.state >= 7) {
            var match_byte = @as(usize, try buffer.lastN(self.rep[0] + 1));

            while (result < 0x100) {
                const match_bit = (match_byte >> 7) & 1;
                match_byte <<= 1;
                const bit = @intFromBool(try decoder.decodeBit(
                    reader,
                    &probs[((@as(usize, 1) + match_bit) << 8) + result],
                    n_read,
                ));
                result = (result << 1) ^ bit;
                if (match_bit != bit) {
                    break;
                }
            }
        }

        while (result < 0x100) {
            result = (result << 1) ^ @intFromBool(try decoder.decodeBit(reader, &probs[result], n_read));
        }

        return @truncate(result - 0x100);
    }

    fn decodeDistance(
        self: *Decode,
        reader: *Reader,
        decoder: *RangeDecoder,
        length: usize,
        n_read: *u64,
    ) !usize {
        const len_state = if (length > 3) 3 else length;

        const pos_slot: usize = try self.pos_slot_decoder[len_state].parse(reader, decoder, n_read);
        if (pos_slot < 4) return pos_slot;

        const num_direct_bits = @as(u5, @intCast((pos_slot >> 1) - 1));
        var result = (2 ^ (pos_slot & 1)) << num_direct_bits;

        if (pos_slot < 14) {
            result += try decoder.parseReverseBitTree(
                reader,
                num_direct_bits,
                &self.pos_decoders,
                result - pos_slot,
                n_read,
            );
        } else {
            result += @as(usize, try decoder.get(reader, num_direct_bits - 4, n_read)) << 4;
            result += try self.align_decoder.parseReverse(reader, decoder, n_read);
        }

        return result;
    }

    /// A circular buffer for LZ sequences
    pub const CircularBuffer = struct {
        /// Circular buffer
        buf: ArrayList(u8),
        /// Length of the buffer
        dict_size: usize,
        /// Buffer memory limit
        mem_limit: usize,
        /// Current position
        cursor: usize,
        /// Total number of bytes sent through the buffer
        len: usize,

        pub fn init(dict_size: usize, mem_limit: usize) CircularBuffer {
            return .{
                .buf = .{},
                .dict_size = dict_size,
                .mem_limit = mem_limit,
                .cursor = 0,
                .len = 0,
            };
        }

        pub fn get(self: CircularBuffer, index: usize) u8 {
            return if (0 <= index and index < self.buf.items.len) self.buf.items[index] else 0;
        }

        pub fn set(self: *CircularBuffer, gpa: Allocator, index: usize, value: u8) !void {
            if (index >= self.mem_limit) {
                return error.CorruptInput;
            }
            try self.buf.ensureTotalCapacity(gpa, index + 1);
            while (self.buf.items.len < index) {
                self.buf.appendAssumeCapacity(0);
            }
            self.buf.appendAssumeCapacity(value);
        }

        /// Retrieve the last byte or return a default
        pub fn lastOr(self: CircularBuffer, lit: u8) u8 {
            return if (self.len == 0)
                lit
            else
                self.get((self.dict_size + self.cursor - 1) % self.dict_size);
        }

        /// Retrieve the n-th last byte
        pub fn lastN(self: CircularBuffer, dist: usize) !u8 {
            if (dist > self.dict_size or dist > self.len) {
                return error.CorruptInput;
            }

            const offset = (self.dict_size + self.cursor - dist) % self.dict_size;
            return self.get(offset);
        }

        /// Append a literal
        pub fn appendLiteral(
            self: *CircularBuffer,
            gpa: Allocator,
            lit: u8,
            writer: *Writer,
        ) !void {
            try self.set(gpa, self.cursor, lit);
            self.cursor += 1;
            self.len += 1;

            // Flush the circular buffer to the output
            if (self.cursor == self.dict_size) {
                try writer.writeAll(self.buf.items);
                self.cursor = 0;
            }
        }

        /// Fetch an LZ sequence (length, distance) from inside the buffer
        pub fn appendLz(
            self: *CircularBuffer,
            gpa: Allocator,
            len: usize,
            dist: usize,
            writer: *Writer,
        ) !void {
            if (dist > self.dict_size or dist > self.len) {
                return error.CorruptInput;
            }

            var offset = (self.dict_size + self.cursor - dist) % self.dict_size;
            var i: usize = 0;
            while (i < len) : (i += 1) {
                const x = self.get(offset);
                try self.appendLiteral(gpa, x, writer);
                offset += 1;
                if (offset == self.dict_size) {
                    offset = 0;
                }
            }
        }

        pub fn finish(self: *CircularBuffer, writer: *Writer) !void {
            if (self.cursor > 0) {
                try writer.writeAll(self.buf.items[0..self.cursor]);
                self.cursor = 0;
            }
        }

        pub fn deinit(self: *CircularBuffer, gpa: Allocator) void {
            self.buf.deinit(gpa);
            self.* = undefined;
        }
    };

    pub fn BitTree(comptime num_bits: usize) type {
        return struct {
            probs: [1 << num_bits]u16 = @splat(0x400),

            pub fn parse(self: *@This(), reader: *Reader, decoder: *RangeDecoder, n_read: *u64) !u32 {
                return decoder.parseBitTree(reader, num_bits, &self.probs, n_read);
            }

            pub fn parseReverse(
                self: *@This(),
                reader: *Reader,
                decoder: *RangeDecoder,
                n_read: *u64,
            ) !u32 {
                return decoder.parseReverseBitTree(reader, num_bits, &self.probs, 0, n_read);
            }

            pub fn reset(self: *@This()) void {
                @memset(&self.probs, 0x400);
            }
        };
    }

    pub const LenDecoder = struct {
        choice: u16 = 0x400,
        choice2: u16 = 0x400,
        low_coder: [16]BitTree(3) = @splat(.{}),
        mid_coder: [16]BitTree(3) = @splat(.{}),
        high_coder: BitTree(8) = .{},

        pub fn decode(
            self: *LenDecoder,
            reader: *Reader,
            decoder: *RangeDecoder,
            pos_state: usize,
            n_read: *u64,
        ) !usize {
            if (!try decoder.decodeBit(reader, &self.choice, n_read)) {
                return @as(usize, try self.low_coder[pos_state].parse(reader, decoder, n_read));
            } else if (!try decoder.decodeBit(reader, &self.choice2, n_read)) {
                return @as(usize, try self.mid_coder[pos_state].parse(reader, decoder, n_read)) + 8;
            } else {
                return @as(usize, try self.high_coder.parse(reader, decoder, n_read)) + 16;
            }
        }

        pub fn reset(self: *LenDecoder) void {
            self.choice = 0x400;
            self.choice2 = 0x400;
            for (&self.low_coder) |*t| t.reset();
            for (&self.mid_coder) |*t| t.reset();
            self.high_coder.reset();
        }
    };

    pub const Vec2d = struct {
        data: []u16,
        cols: usize,

        pub fn init(gpa: Allocator, value: u16, w: usize, h: usize) !Vec2d {
            const len = try math.mul(usize, w, h);
            const data = try gpa.alloc(u16, len);
            @memset(data, value);
            return .{
                .data = data,
                .cols = h,
            };
        }

        pub fn deinit(v: *Vec2d, gpa: Allocator) void {
            gpa.free(v.data);
            v.* = undefined;
        }

        pub fn fill(v: *Vec2d, value: u16) void {
            @memset(v.data, value);
        }

        fn get(v: Vec2d, row: usize) ![]u16 {
            const start_row = try math.mul(usize, row, v.cols);
            const end_row = try math.add(usize, start_row, v.cols);
            return v.data[start_row..end_row];
        }
    };

    pub const Options = struct {
        unpacked_size: UnpackedSize = .read_from_header,
        mem_limit: ?usize = null,
        allow_incomplete: bool = false,
    };

    pub const UnpackedSize = union(enum) {
        read_from_header,
        read_header_but_use_provided: ?u64,
        use_provided: ?u64,
    };

    const ProcessingStatus = enum {
        more,
        finished,
    };

    pub const Properties = struct {
        lc: u4,
        lp: u3,
        pb: u3,

        fn validate(self: Properties) void {
            assert(self.lc <= 8);
            assert(self.lp <= 4);
            assert(self.pb <= 4);
        }
    };

    pub const Params = struct {
        properties: Properties,
        dict_size: u32,
        unpacked_size: ?u64,

        pub fn readHeader(reader: *Reader, options: Options) !Params {
            var props = try reader.takeByte();
            if (props >= 225) return error.CorruptInput;

            const lc: u4 = @intCast(props % 9);
            props /= 9;
            const lp: u3 = @intCast(props % 5);
            props /= 5;
            const pb: u3 = @intCast(props);

            const dict_size_provided = try reader.takeInt(u32, .little);
            const dict_size = @max(0x1000, dict_size_provided);

            const unpacked_size = switch (options.unpacked_size) {
                .read_from_header => blk: {
                    const unpacked_size_provided = try reader.takeInt(u64, .little);
                    const marker_mandatory = unpacked_size_provided == 0xFFFF_FFFF_FFFF_FFFF;
                    break :blk if (marker_mandatory) null else unpacked_size_provided;
                },
                .read_header_but_use_provided => |x| blk: {
                    _ = try reader.takeInt(u64, .little);
                    break :blk x;
                },
                .use_provided => |x| x,
            };

            return .{
                .properties = .{ .lc = lc, .lp = lp, .pb = pb },
                .dict_size = dict_size,
                .unpacked_size = unpacked_size,
            };
        }
    };
};

pub const Decompress = struct {
    gpa: Allocator,
    input: *Reader,
    reader: Reader,
    buffer: Decode.CircularBuffer,
    range_decoder: RangeDecoder,
    decode: Decode,
    err: ?Error,
    unpacked_size: ?u64,

    pub const Error = error{
        OutOfMemory,
        ReadFailed,
        CorruptInput,
        DecompressedSizeMismatch,
        EndOfStream,
        Overflow,
    };

    /// Takes ownership of `buffer` which may be resized with `gpa`.
    ///
    /// LZMA was explicitly designed to take advantage of large heap memory
    /// being available, with a dictionary size anywhere from 4K to 4G. Thus,
    /// this API dynamically allocates the dictionary as-needed.
    pub fn initParams(
        input: *Reader,
        gpa: Allocator,
        buffer: []u8,
        params: Decode.Params,
        mem_limit: usize,
    ) !Decompress {
        return .{
            .gpa = gpa,
            .input = input,
            .buffer = Decode.CircularBuffer.init(params.dict_size, mem_limit),
            .range_decoder = try RangeDecoder.init(input),
            .decode = try Decode.init(gpa, params.properties),
            .reader = .{
                .buffer = buffer,
                .vtable = &.{
                    .readVec = readVec,
                    .stream = stream,
                    .discard = discard,
                },
                .seek = 0,
                .end = 0,
            },
            .err = null,
            .unpacked_size = params.unpacked_size,
        };
    }

    /// Takes ownership of `buffer` which may be resized with `gpa`.
    ///
    /// LZMA was explicitly designed to take advantage of large heap memory
    /// being available, with a dictionary size anywhere from 4K to 4G. Thus,
    /// this API dynamically allocates the dictionary as-needed.
    pub fn initOptions(
        input: *Reader,
        gpa: Allocator,
        buffer: []u8,
        options: Decode.Options,
        mem_limit: usize,
    ) !Decompress {
        const params = try Decode.Params.readHeader(input, options);
        return initParams(input, gpa, buffer, params, mem_limit);
    }

    /// Reclaim ownership of the buffer passed to `init`.
    pub fn takeBuffer(d: *Decompress) []u8 {
        const buffer = d.reader.buffer;
        d.reader.buffer = &.{};
        return buffer;
    }

    pub fn deinit(d: *Decompress) void {
        const gpa = d.gpa;
        gpa.free(d.reader.buffer);
        d.buffer.deinit(gpa);
        d.decode.deinit(gpa);
        d.* = undefined;
    }

    fn readVec(r: *Reader, data: [][]u8) Reader.Error!usize {
        _ = data;
        return readIndirect(r);
    }

    fn stream(r: *Reader, w: *Writer, limit: std.Io.Limit) Reader.StreamError!usize {
        _ = w;
        _ = limit;
        return readIndirect(r);
    }

    fn discard(r: *Reader, limit: std.Io.Limit) Reader.Error!usize {
        const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
        _ = d;
        _ = limit;
        @panic("TODO");
    }

    fn readIndirect(r: *Reader) Reader.Error!usize {
        const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
        const gpa = d.gpa;
        var allocating = Writer.Allocating.initOwnedSlice(gpa, r.buffer);
        allocating.writer.end = r.end;
        defer {
            r.buffer = allocating.writer.buffer;
            r.end = allocating.writer.end;
        }
        if (d.decode.state == math.maxInt(usize)) return error.EndOfStream;

        process_next: {
            if (d.unpacked_size) |unpacked_size| {
                if (d.buffer.len >= unpacked_size) break :process_next;
            } else if (d.range_decoder.isFinished()) {
                break :process_next;
            }
            var n_read: u64 = 0;
            switch (d.decode.process(d.input, &allocating, &d.buffer, &d.range_decoder, &n_read) catch |err| switch (err) {
                error.WriteFailed => {
                    d.err = error.OutOfMemory;
                    return error.ReadFailed;
                },
                error.EndOfStream => {
                    d.err = error.EndOfStream;
                    return error.ReadFailed;
                },
                else => |e| {
                    d.err = e;
                    return error.ReadFailed;
                },
            }) {
                .more => return 0,
                .finished => break :process_next,
            }
        }

        if (d.unpacked_size) |unpacked_size| {
            if (d.buffer.len != unpacked_size) {
                d.err = error.DecompressedSizeMismatch;
                return error.ReadFailed;
            }
        }

        d.buffer.finish(&allocating.writer) catch |err| switch (err) {
            error.WriteFailed => {
                d.err = error.OutOfMemory;
                return error.ReadFailed;
            },
        };
        d.decode.state = math.maxInt(usize);
        return 0;
    }
};

test {
    _ = @import("lzma/test.zig");
}
