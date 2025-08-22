const std = @import("../std.zig");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

pub const RangeDecoder = struct {
    range: u32,
    code: u32,

    pub fn init(reader: anytype) !RangeDecoder {
        const reserved = try reader.readByte();
        if (reserved != 0) {
            return error.CorruptInput;
        }
        return RangeDecoder{
            .range = 0xFFFF_FFFF,
            .code = try reader.readInt(u32, .big),
        };
    }

    pub fn fromParts(
        range: u32,
        code: u32,
    ) RangeDecoder {
        return .{
            .range = range,
            .code = code,
        };
    }

    pub fn set(self: *RangeDecoder, range: u32, code: u32) void {
        self.range = range;
        self.code = code;
    }

    pub inline fn isFinished(self: RangeDecoder) bool {
        return self.code == 0;
    }

    inline fn normalize(self: *RangeDecoder, reader: anytype) !void {
        if (self.range < 0x0100_0000) {
            self.range <<= 8;
            self.code = (self.code << 8) ^ @as(u32, try reader.readByte());
        }
    }

    inline fn getBit(self: *RangeDecoder, reader: anytype) !bool {
        self.range >>= 1;

        const bit = self.code >= self.range;
        if (bit)
            self.code -= self.range;

        try self.normalize(reader);
        return bit;
    }

    pub fn get(self: *RangeDecoder, reader: anytype, count: usize) !u32 {
        var result: u32 = 0;
        var i: usize = 0;
        while (i < count) : (i += 1)
            result = (result << 1) ^ @intFromBool(try self.getBit(reader));
        return result;
    }

    pub inline fn decodeBit(self: *RangeDecoder, reader: anytype, prob: *u16, update: bool) !bool {
        const bound = (self.range >> 11) * prob.*;

        if (self.code < bound) {
            if (update)
                prob.* += (0x800 - prob.*) >> 5;
            self.range = bound;

            try self.normalize(reader);
            return false;
        } else {
            if (update)
                prob.* -= prob.* >> 5;
            self.code -= bound;
            self.range -= bound;

            try self.normalize(reader);
            return true;
        }
    }

    fn parseBitTree(
        self: *RangeDecoder,
        reader: anytype,
        num_bits: u5,
        probs: []u16,
        update: bool,
    ) !u32 {
        var tmp: u32 = 1;
        var i: @TypeOf(num_bits) = 0;
        while (i < num_bits) : (i += 1) {
            const bit = try self.decodeBit(reader, &probs[tmp], update);
            tmp = (tmp << 1) ^ @intFromBool(bit);
        }
        return tmp - (@as(u32, 1) << num_bits);
    }

    pub fn parseReverseBitTree(
        self: *RangeDecoder,
        reader: anytype,
        num_bits: u5,
        probs: []u16,
        offset: usize,
        update: bool,
    ) !u32 {
        var result: u32 = 0;
        var tmp: usize = 1;
        var i: @TypeOf(num_bits) = 0;
        while (i < num_bits) : (i += 1) {
            const bit = @intFromBool(try self.decodeBit(reader, &probs[offset + tmp], update));
            tmp = (tmp << 1) ^ bit;
            result ^= @as(u32, bit) << i;
        }
        return result;
    }
};

pub const Decode = struct {
    lzma_props: Properties,
    unpacked_size: ?u64,
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

    pub fn init(
        allocator: Allocator,
        lzma_props: Properties,
        unpacked_size: ?u64,
    ) !Decode {
        return .{
            .lzma_props = lzma_props,
            .unpacked_size = unpacked_size,
            .literal_probs = try Vec2d.init(allocator, 0x400, .{ @as(usize, 1) << (lzma_props.lc + lzma_props.lp), 0x300 }),
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

    pub fn deinit(self: *Decode, allocator: Allocator) void {
        self.literal_probs.deinit(allocator);
        self.* = undefined;
    }

    pub fn resetState(self: *Decode, allocator: Allocator, new_props: Properties) !void {
        new_props.validate();
        if (self.lzma_props.lc + self.lzma_props.lp == new_props.lc + new_props.lp) {
            self.literal_probs.fill(0x400);
        } else {
            self.literal_probs.deinit(allocator);
            self.literal_probs = try Vec2d.init(allocator, 0x400, .{ @as(usize, 1) << (new_props.lc + new_props.lp), 0x300 });
        }

        self.lzma_props = new_props;
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

    fn processNextInner(
        self: *Decode,
        allocator: Allocator,
        reader: anytype,
        writer: anytype,
        buffer: anytype,
        decoder: *RangeDecoder,
        update: bool,
    ) !ProcessingStatus {
        const pos_state = buffer.len & ((@as(usize, 1) << self.lzma_props.pb) - 1);

        if (!try decoder.decodeBit(
            reader,
            &self.is_match[(self.state << 4) + pos_state],
            update,
        )) {
            const byte: u8 = try self.decodeLiteral(reader, buffer, decoder, update);

            if (update) {
                try buffer.appendLiteral(allocator, byte, writer);

                self.state = if (self.state < 4)
                    0
                else if (self.state < 10)
                    self.state - 3
                else
                    self.state - 6;
            }
            return .continue_;
        }

        var len: usize = undefined;
        if (try decoder.decodeBit(reader, &self.is_rep[self.state], update)) {
            if (!try decoder.decodeBit(reader, &self.is_rep_g0[self.state], update)) {
                if (!try decoder.decodeBit(
                    reader,
                    &self.is_rep_0long[(self.state << 4) + pos_state],
                    update,
                )) {
                    if (update) {
                        self.state = if (self.state < 7) 9 else 11;
                        const dist = self.rep[0] + 1;
                        try buffer.appendLz(allocator, 1, dist, writer);
                    }
                    return .continue_;
                }
            } else {
                const idx: usize = if (!try decoder.decodeBit(reader, &self.is_rep_g1[self.state], update))
                    1
                else if (!try decoder.decodeBit(reader, &self.is_rep_g2[self.state], update))
                    2
                else
                    3;
                if (update) {
                    const dist = self.rep[idx];
                    var i = idx;
                    while (i > 0) : (i -= 1) {
                        self.rep[i] = self.rep[i - 1];
                    }
                    self.rep[0] = dist;
                }
            }

            len = try self.rep_len_decoder.decode(reader, decoder, pos_state, update);

            if (update) {
                self.state = if (self.state < 7) 8 else 11;
            }
        } else {
            if (update) {
                self.rep[3] = self.rep[2];
                self.rep[2] = self.rep[1];
                self.rep[1] = self.rep[0];
            }

            len = try self.len_decoder.decode(reader, decoder, pos_state, update);

            if (update) {
                self.state = if (self.state < 7) 7 else 10;
            }

            const rep_0 = try self.decodeDistance(reader, decoder, len, update);

            if (update) {
                self.rep[0] = rep_0;
                if (self.rep[0] == 0xFFFF_FFFF) {
                    if (decoder.isFinished()) {
                        return .finished;
                    }
                    return error.CorruptInput;
                }
            }
        }

        if (update) {
            len += 2;

            const dist = self.rep[0] + 1;
            try buffer.appendLz(allocator, len, dist, writer);
        }

        return .continue_;
    }

    fn processNext(
        self: *Decode,
        allocator: Allocator,
        reader: anytype,
        writer: anytype,
        buffer: anytype,
        decoder: *RangeDecoder,
    ) !ProcessingStatus {
        return self.processNextInner(allocator, reader, writer, buffer, decoder, true);
    }

    pub fn process(
        self: *Decode,
        allocator: Allocator,
        reader: anytype,
        writer: anytype,
        buffer: anytype,
        decoder: *RangeDecoder,
    ) !ProcessingStatus {
        process_next: {
            if (self.unpacked_size) |unpacked_size| {
                if (buffer.len >= unpacked_size) {
                    break :process_next;
                }
            } else if (decoder.isFinished()) {
                break :process_next;
            }

            switch (try self.processNext(allocator, reader, writer, buffer, decoder)) {
                .continue_ => return .continue_,
                .finished => break :process_next,
            }
        }

        if (self.unpacked_size) |unpacked_size| {
            if (buffer.len != unpacked_size) {
                return error.CorruptInput;
            }
        }

        return .finished;
    }

    fn decodeLiteral(
        self: *Decode,
        reader: anytype,
        buffer: anytype,
        decoder: *RangeDecoder,
        update: bool,
    ) !u8 {
        const def_prev_byte = 0;
        const prev_byte = @as(usize, buffer.lastOr(def_prev_byte));

        var result: usize = 1;
        const lit_state = ((buffer.len & ((@as(usize, 1) << self.lzma_props.lp) - 1)) << self.lzma_props.lc) +
            (prev_byte >> (8 - self.lzma_props.lc));
        const probs = try self.literal_probs.getMut(lit_state);

        if (self.state >= 7) {
            var match_byte = @as(usize, try buffer.lastN(self.rep[0] + 1));

            while (result < 0x100) {
                const match_bit = (match_byte >> 7) & 1;
                match_byte <<= 1;
                const bit = @intFromBool(try decoder.decodeBit(
                    reader,
                    &probs[((@as(usize, 1) + match_bit) << 8) + result],
                    update,
                ));
                result = (result << 1) ^ bit;
                if (match_bit != bit) {
                    break;
                }
            }
        }

        while (result < 0x100) {
            result = (result << 1) ^ @intFromBool(try decoder.decodeBit(reader, &probs[result], update));
        }

        return @as(u8, @truncate(result - 0x100));
    }

    fn decodeDistance(
        self: *Decode,
        reader: anytype,
        decoder: *RangeDecoder,
        length: usize,
        update: bool,
    ) !usize {
        const len_state = if (length > 3) 3 else length;

        const pos_slot = @as(usize, try self.pos_slot_decoder[len_state].parse(reader, decoder, update));
        if (pos_slot < 4)
            return pos_slot;

        const num_direct_bits = @as(u5, @intCast((pos_slot >> 1) - 1));
        var result = (2 ^ (pos_slot & 1)) << num_direct_bits;

        if (pos_slot < 14) {
            result += try decoder.parseReverseBitTree(
                reader,
                num_direct_bits,
                &self.pos_decoders,
                result - pos_slot,
                update,
            );
        } else {
            result += @as(usize, try decoder.get(reader, num_direct_bits - 4)) << 4;
            result += try self.align_decoder.parseReverse(reader, decoder, update);
        }

        return result;
    }

    /// A circular buffer for LZ sequences
    pub const LzCircularBuffer = struct {
        /// Circular buffer
        buf: ArrayList(u8),

        /// Length of the buffer
        dict_size: usize,

        /// Buffer memory limit
        memlimit: usize,

        /// Current position
        cursor: usize,

        /// Total number of bytes sent through the buffer
        len: usize,

        const Self = @This();

        pub fn init(dict_size: usize, memlimit: usize) Self {
            return Self{
                .buf = .{},
                .dict_size = dict_size,
                .memlimit = memlimit,
                .cursor = 0,
                .len = 0,
            };
        }

        pub fn get(self: Self, index: usize) u8 {
            return if (0 <= index and index < self.buf.items.len)
                self.buf.items[index]
            else
                0;
        }

        pub fn set(self: *Self, allocator: Allocator, index: usize, value: u8) !void {
            if (index >= self.memlimit) {
                return error.CorruptInput;
            }
            try self.buf.ensureTotalCapacity(allocator, index + 1);
            while (self.buf.items.len < index) {
                self.buf.appendAssumeCapacity(0);
            }
            self.buf.appendAssumeCapacity(value);
        }

        /// Retrieve the last byte or return a default
        pub fn lastOr(self: Self, lit: u8) u8 {
            return if (self.len == 0)
                lit
            else
                self.get((self.dict_size + self.cursor - 1) % self.dict_size);
        }

        /// Retrieve the n-th last byte
        pub fn lastN(self: Self, dist: usize) !u8 {
            if (dist > self.dict_size or dist > self.len) {
                return error.CorruptInput;
            }

            const offset = (self.dict_size + self.cursor - dist) % self.dict_size;
            return self.get(offset);
        }

        /// Append a literal
        pub fn appendLiteral(
            self: *Self,
            allocator: Allocator,
            lit: u8,
            writer: anytype,
        ) !void {
            try self.set(allocator, self.cursor, lit);
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
            self: *Self,
            allocator: Allocator,
            len: usize,
            dist: usize,
            writer: anytype,
        ) !void {
            if (dist > self.dict_size or dist > self.len) {
                return error.CorruptInput;
            }

            var offset = (self.dict_size + self.cursor - dist) % self.dict_size;
            var i: usize = 0;
            while (i < len) : (i += 1) {
                const x = self.get(offset);
                try self.appendLiteral(allocator, x, writer);
                offset += 1;
                if (offset == self.dict_size) {
                    offset = 0;
                }
            }
        }

        pub fn finish(self: *Self, writer: anytype) !void {
            if (self.cursor > 0) {
                try writer.writeAll(self.buf.items[0..self.cursor]);
                self.cursor = 0;
            }
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.buf.deinit(allocator);
            self.* = undefined;
        }
    };

    pub fn BitTree(comptime num_bits: usize) type {
        return struct {
            probs: [1 << num_bits]u16 = @splat(0x400),

            const Self = @This();

            pub fn parse(
                self: *Self,
                reader: anytype,
                decoder: *RangeDecoder,
                update: bool,
            ) !u32 {
                return decoder.parseBitTree(reader, num_bits, &self.probs, update);
            }

            pub fn parseReverse(
                self: *Self,
                reader: anytype,
                decoder: *RangeDecoder,
                update: bool,
            ) !u32 {
                return decoder.parseReverseBitTree(reader, num_bits, &self.probs, 0, update);
            }

            pub fn reset(self: *Self) void {
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
            reader: anytype,
            decoder: *RangeDecoder,
            pos_state: usize,
            update: bool,
        ) !usize {
            if (!try decoder.decodeBit(reader, &self.choice, update)) {
                return @as(usize, try self.low_coder[pos_state].parse(reader, decoder, update));
            } else if (!try decoder.decodeBit(reader, &self.choice2, update)) {
                return @as(usize, try self.mid_coder[pos_state].parse(reader, decoder, update)) + 8;
            } else {
                return @as(usize, try self.high_coder.parse(reader, decoder, update)) + 16;
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

        const Self = @This();

        pub fn init(allocator: Allocator, value: u16, size: struct { usize, usize }) !Self {
            const len = try math.mul(usize, size[0], size[1]);
            const data = try allocator.alloc(u16, len);
            @memset(data, value);
            return Self{
                .data = data,
                .cols = size[1],
            };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.data);
            self.* = undefined;
        }

        pub fn fill(self: *Self, value: u16) void {
            @memset(self.data, value);
        }

        inline fn _get(self: Self, row: usize) ![]u16 {
            const start_row = try math.mul(usize, row, self.cols);
            const end_row = try math.add(usize, start_row, self.cols);
            return self.data[start_row..end_row];
        }

        pub fn get(self: Self, row: usize) ![]const u16 {
            return self._get(row);
        }

        pub fn getMut(self: *Self, row: usize) ![]u16 {
            return self._get(row);
        }
    };

    pub const Options = struct {
        unpacked_size: UnpackedSize = .read_from_header,
        memlimit: ?usize = null,
        allow_incomplete: bool = false,
    };

    pub const UnpackedSize = union(enum) {
        read_from_header,
        read_header_but_use_provided: ?u64,
        use_provided: ?u64,
    };

    const ProcessingStatus = enum {
        continue_,
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

        pub fn readHeader(reader: anytype, options: Options) !Params {
            var props = try reader.readByte();
            if (props >= 225) {
                return error.CorruptInput;
            }

            const lc = @as(u4, @intCast(props % 9));
            props /= 9;
            const lp = @as(u3, @intCast(props % 5));
            props /= 5;
            const pb = @as(u3, @intCast(props));

            const dict_size_provided = try reader.readInt(u32, .little);
            const dict_size = @max(0x1000, dict_size_provided);

            const unpacked_size = switch (options.unpacked_size) {
                .read_from_header => blk: {
                    const unpacked_size_provided = try reader.readInt(u64, .little);
                    const marker_mandatory = unpacked_size_provided == 0xFFFF_FFFF_FFFF_FFFF;
                    break :blk if (marker_mandatory)
                        null
                    else
                        unpacked_size_provided;
                },
                .read_header_but_use_provided => |x| blk: {
                    _ = try reader.readInt(u64, .little);
                    break :blk x;
                },
                .use_provided => |x| x,
            };

            return Params{
                .properties = Properties{ .lc = lc, .lp = lp, .pb = pb },
                .dict_size = dict_size,
                .unpacked_size = unpacked_size,
            };
        }
    };
};

pub fn decompress(
    allocator: Allocator,
    reader: anytype,
) !Decompress(@TypeOf(reader)) {
    return decompressWithOptions(allocator, reader, .{});
}

pub fn decompressWithOptions(
    allocator: Allocator,
    reader: anytype,
    options: Decode.Options,
) !Decompress(@TypeOf(reader)) {
    const params = try Decode.Params.readHeader(reader, options);
    return Decompress(@TypeOf(reader)).init(allocator, reader, params, options.memlimit);
}

pub fn Decompress(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error =
            ReaderType.Error ||
            Allocator.Error ||
            error{ CorruptInput, EndOfStream, Overflow };

        pub const Reader = std.io.GenericReader(*Self, Error, read);

        allocator: Allocator,
        in_reader: ReaderType,
        to_read: std.ArrayListUnmanaged(u8),

        buffer: Decode.LzCircularBuffer,
        decoder: RangeDecoder,
        state: Decode,

        pub fn init(allocator: Allocator, source: ReaderType, params: Decode.Params, memlimit: ?usize) !Self {
            return Self{
                .allocator = allocator,
                .in_reader = source,
                .to_read = .{},

                .buffer = Decode.LzCircularBuffer.init(params.dict_size, memlimit orelse math.maxInt(usize)),
                .decoder = try RangeDecoder.init(source),
                .state = try Decode.init(allocator, params.properties, params.unpacked_size),
            };
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn deinit(self: *Self) void {
            self.to_read.deinit(self.allocator);
            self.buffer.deinit(self.allocator);
            self.state.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn read(self: *Self, output: []u8) Error!usize {
            const writer = self.to_read.writer(self.allocator);
            while (self.to_read.items.len < output.len) {
                switch (try self.state.process(self.allocator, self.in_reader, writer, &self.buffer, &self.decoder)) {
                    .continue_ => {},
                    .finished => {
                        try self.buffer.finish(writer);
                        break;
                    },
                }
            }
            const input = self.to_read.items;
            const n = @min(input.len, output.len);
            @memcpy(output[0..n], input[0..n]);
            std.mem.copyForwards(u8, input[0 .. input.len - n], input[n..]);
            self.to_read.shrinkRetainingCapacity(input.len - n);
            return n;
        }
    };
}

test {
    _ = @import("lzma/test.zig");
}
