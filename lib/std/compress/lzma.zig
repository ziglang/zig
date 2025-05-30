const std = @import("../std.zig");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const testing = std.testing;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

pub const RangeDecoder = struct {
    range: u32,
    code: u32,

    pub fn init(rd: *RangeDecoder, br: *std.io.Reader) std.io.Reader.Error!usize {
        const reserved = try br.takeByte();
        if (reserved != 0) return error.CorruptInput;
        rd.* = .{
            .range = 0xFFFF_FFFF,
            .code = try br.takeInt(u32, .big),
        };
        return 5;
    }

    pub inline fn isFinished(self: RangeDecoder) bool {
        return self.code == 0;
    }

    inline fn normalize(self: *RangeDecoder, br: *std.io.Reader) !void {
        if (self.range < 0x0100_0000) {
            self.range <<= 8;
            self.code = (self.code << 8) ^ @as(u32, try br.takeByte());
        }
    }

    inline fn getBit(self: *RangeDecoder, br: *std.io.Reader) !bool {
        self.range >>= 1;

        const bit = self.code >= self.range;
        if (bit)
            self.code -= self.range;

        try self.normalize(br);
        return bit;
    }

    pub fn get(self: *RangeDecoder, br: *std.io.Reader, count: usize) !u32 {
        var result: u32 = 0;
        var i: usize = 0;
        while (i < count) : (i += 1)
            result = (result << 1) ^ @intFromBool(try self.getBit(br));
        return result;
    }

    pub inline fn decodeBit(self: *RangeDecoder, br: *std.io.Reader, prob: *u16, update: bool) !bool {
        const bound = (self.range >> 11) * prob.*;

        if (self.code < bound) {
            if (update)
                prob.* += (0x800 - prob.*) >> 5;
            self.range = bound;

            try self.normalize(br);
            return false;
        } else {
            if (update)
                prob.* -= prob.* >> 5;
            self.code -= bound;
            self.range -= bound;

            try self.normalize(br);
            return true;
        }
    }

    fn parseBitTree(
        self: *RangeDecoder,
        br: *std.io.Reader,
        num_bits: u5,
        probs: []u16,
        update: bool,
    ) !u32 {
        var tmp: u32 = 1;
        var i: @TypeOf(num_bits) = 0;
        while (i < num_bits) : (i += 1) {
            const bit = try self.decodeBit(br, &probs[tmp], update);
            tmp = (tmp << 1) ^ @intFromBool(bit);
        }
        return tmp - (@as(u32, 1) << num_bits);
    }

    pub fn parseReverseBitTree(
        self: *RangeDecoder,
        br: *std.io.Reader,
        num_bits: u5,
        probs: []u16,
        offset: usize,
        update: bool,
    ) !u32 {
        var result: u32 = 0;
        var tmp: usize = 1;
        var i: @TypeOf(num_bits) = 0;
        while (i < num_bits) : (i += 1) {
            const bit = @intFromBool(try self.decodeBit(br, &probs[offset + tmp], update));
            tmp = (tmp << 1) ^ bit;
            result ^= @as(u32, bit) << i;
        }
        return result;
    }
};

pub const LenDecoder = struct {
    choice: u16 = 0x400,
    choice2: u16 = 0x400,
    low_coder: [16]BitTree(3) = @splat(.{}),
    mid_coder: [16]BitTree(3) = @splat(.{}),
    high_coder: BitTree(8) = .{},

    pub fn decode(
        self: *LenDecoder,
        br: *std.io.Reader,
        decoder: *RangeDecoder,
        pos_state: usize,
        update: bool,
    ) !usize {
        if (!try decoder.decodeBit(br, &self.choice, update)) {
            return @as(usize, try self.low_coder[pos_state].parse(br, decoder, update));
        } else if (!try decoder.decodeBit(br, &self.choice2, update)) {
            return @as(usize, try self.mid_coder[pos_state].parse(br, decoder, update)) + 8;
        } else {
            return @as(usize, try self.high_coder.parse(br, decoder, update)) + 16;
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

pub fn BitTree(comptime num_bits: usize) type {
    return struct {
        probs: [1 << num_bits]u16 = @splat(0x400),

        const Self = @This();

        pub fn parse(
            self: *Self,
            br: *std.io.Reader,
            decoder: *RangeDecoder,
            update: bool,
        ) !u32 {
            return decoder.parseBitTree(br, num_bits, &self.probs, update);
        }

        pub fn parseReverse(
            self: *Self,
            br: *std.io.Reader,
            decoder: *RangeDecoder,
            update: bool,
        ) !u32 {
            return decoder.parseReverseBitTree(br, num_bits, &self.probs, 0, update);
        }

        pub fn reset(self: *Self) void {
            @memset(&self.probs, 0x400);
        }
    };
}

pub const Decode = struct {
    properties: Properties,
    unpacked_size: ?u64,
    literal_probs: Vec2D(u16),
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
        cont,
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

        pub fn readHeader(br: *std.io.Reader, options: Options) std.io.Reader.Error!Params {
            var props = try br.readByte();
            if (props >= 225) {
                return error.CorruptInput;
            }

            const lc = @as(u4, @intCast(props % 9));
            props /= 9;
            const lp = @as(u3, @intCast(props % 5));
            props /= 5;
            const pb = @as(u3, @intCast(props));

            const dict_size_provided = try br.readInt(u32, .little);
            const dict_size = @max(0x1000, dict_size_provided);

            const unpacked_size = switch (options.unpacked_size) {
                .read_from_header => blk: {
                    const unpacked_size_provided = try br.readInt(u64, .little);
                    const marker_mandatory = unpacked_size_provided == 0xFFFF_FFFF_FFFF_FFFF;
                    break :blk if (marker_mandatory)
                        null
                    else
                        unpacked_size_provided;
                },
                .read_header_but_use_provided => |x| blk: {
                    _ = try br.readInt(u64, .little);
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

    pub fn init(
        allocator: Allocator,
        properties: Properties,
        unpacked_size: ?u64,
    ) !Decode {
        return .{
            .properties = properties,
            .unpacked_size = unpacked_size,
            .literal_probs = try Vec2D(u16).init(allocator, 0x400, .{ @as(usize, 1) << (properties.lc + properties.lp), 0x300 }),
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
        if (self.properties.lc + self.properties.lp == new_props.lc + new_props.lp) {
            self.literal_probs.fill(0x400);
        } else {
            self.literal_probs.deinit(allocator);
            self.literal_probs = try Vec2D(u16).init(allocator, 0x400, .{ @as(usize, 1) << (new_props.lc + new_props.lp), 0x300 });
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

    fn processNextInner(
        self: *Decode,
        allocator: Allocator,
        br: *std.io.Reader,
        bw: *std.io.BufferedWriter,
        buffer: anytype,
        decoder: *RangeDecoder,
        bytes_read: *usize,
        update: bool,
    ) !ProcessingStatus {
        const pos_state = buffer.len & ((@as(usize, 1) << self.properties.pb) - 1);

        if (!try decoder.decodeBit(br, &self.is_match[(self.state << 4) + pos_state], update, bytes_read)) {
            const byte: u8 = try self.decodeLiteral(br, buffer, decoder, update, bytes_read);

            if (update) {
                try buffer.appendLiteral(allocator, byte, bw);

                self.state = if (self.state < 4)
                    0
                else if (self.state < 10)
                    self.state - 3
                else
                    self.state - 6;
            }
            return .cont;
        }

        var len: usize = undefined;
        if (try decoder.decodeBit(br, &self.is_rep[self.state], update, bytes_read)) {
            if (!try decoder.decodeBit(br, &self.is_rep_g0[self.state], update, bytes_read)) {
                if (!try decoder.decodeBit(br, &self.is_rep_0long[(self.state << 4) + pos_state], update, bytes_read)) {
                    if (update) {
                        self.state = if (self.state < 7) 9 else 11;
                        const dist = self.rep[0] + 1;
                        try buffer.appendLz(allocator, 1, dist, bw);
                    }
                    return .cont;
                }
            } else {
                const idx: usize = if (!try decoder.decodeBit(br, &self.is_rep_g1[self.state], update, bytes_read))
                    1
                else if (!try decoder.decodeBit(br, &self.is_rep_g2[self.state], update, bytes_read))
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

            len = try self.rep_len_decoder.decode(br, decoder, pos_state, update, bytes_read);

            if (update) {
                self.state = if (self.state < 7) 8 else 11;
            }
        } else {
            if (update) {
                self.rep[3] = self.rep[2];
                self.rep[2] = self.rep[1];
                self.rep[1] = self.rep[0];
            }

            len = try self.len_decoder.decode(br, decoder, pos_state, update, bytes_read);

            if (update) {
                self.state = if (self.state < 7) 7 else 10;
            }

            const rep_0 = try self.decodeDistance(br, decoder, len, update, bytes_read);

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
            try buffer.appendLz(allocator, len, dist, bw);
        }

        return .cont;
    }

    fn processNext(
        self: *Decode,
        allocator: Allocator,
        br: *std.io.Reader,
        bw: *std.io.BufferedWriter,
        buffer: anytype,
        decoder: *RangeDecoder,
        bytes_read: *usize,
    ) !ProcessingStatus {
        return self.processNextInner(allocator, br, bw, buffer, decoder, bytes_read, true);
    }

    pub fn process(
        self: *Decode,
        allocator: Allocator,
        br: *std.io.Reader,
        bw: *std.io.BufferedWriter,
        buffer: anytype,
        decoder: *RangeDecoder,
        bytes_read: *usize,
    ) !ProcessingStatus {
        process_next: {
            if (self.unpacked_size) |unpacked_size| {
                if (buffer.len >= unpacked_size) {
                    break :process_next;
                }
            } else if (decoder.isFinished()) {
                break :process_next;
            }

            switch (try self.processNext(allocator, br, bw, buffer, decoder, bytes_read)) {
                .cont => return .cont,
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
        br: *std.io.Reader,
        buffer: anytype,
        decoder: *RangeDecoder,
        update: bool,
        bytes_read: *usize,
    ) !u8 {
        const def_prev_byte = 0;
        const prev_byte = @as(usize, buffer.lastOr(def_prev_byte));

        var result: usize = 1;
        const lit_state = ((buffer.len & ((@as(usize, 1) << self.properties.lp) - 1)) << self.properties.lc) +
            (prev_byte >> (8 - self.properties.lc));
        const probs = try self.literal_probs.getMut(lit_state);

        if (self.state >= 7) {
            var match_byte = @as(usize, try buffer.lastN(self.rep[0] + 1));

            while (result < 0x100) {
                const match_bit = (match_byte >> 7) & 1;
                match_byte <<= 1;
                const bit = @intFromBool(try decoder.decodeBit(
                    br,
                    &probs[((@as(usize, 1) + match_bit) << 8) + result],
                    update,
                    bytes_read,
                ));
                result = (result << 1) ^ bit;
                if (match_bit != bit) {
                    break;
                }
            }
        }

        while (result < 0x100) {
            result = (result << 1) ^ @intFromBool(try decoder.decodeBit(br, &probs[result], update, bytes_read));
        }

        return @as(u8, @truncate(result - 0x100));
    }

    fn decodeDistance(
        self: *Decode,
        br: *std.io.Reader,
        decoder: *RangeDecoder,
        length: usize,
        update: bool,
        bytes_read: *usize,
    ) !usize {
        const len_state = if (length > 3) 3 else length;

        const pos_slot = @as(usize, try self.pos_slot_decoder[len_state].parse(br, decoder, update, bytes_read));
        if (pos_slot < 4)
            return pos_slot;

        const num_direct_bits = @as(u5, @intCast((pos_slot >> 1) - 1));
        var result = (2 ^ (pos_slot & 1)) << num_direct_bits;

        if (pos_slot < 14) {
            result += try decoder.parseReverseBitTree(
                br,
                num_direct_bits,
                &self.pos_decoders,
                result - pos_slot,
                update,
                bytes_read,
            );
        } else {
            result += @as(usize, try decoder.get(br, num_direct_bits - 4, bytes_read)) << 4;
            result += try self.align_decoder.parseReverse(br, decoder, update, bytes_read);
        }

        return result;
    }
};

pub const Decompress = struct {
    pub const Error =
        std.io.Reader.Error ||
        Allocator.Error ||
        error{ CorruptInput, EndOfStream, Overflow };

    allocator: Allocator,
    in_reader: *std.io.Reader,
    to_read: std.ArrayListUnmanaged(u8),

    buffer: LzCircularBuffer,
    decoder: RangeDecoder,
    state: Decode,

    pub fn initOptions(allocator: Allocator, br: *std.io.Reader, options: Decode.Options) !Decompress {
        const params = try Decode.Params.readHeader(br, options);
        return init(allocator, br, params, options.memlimit);
    }

    pub fn init(allocator: Allocator, source: *std.io.Reader, params: Decode.Params, memlimit: ?usize) !Decompress {
        return .{
            .allocator = allocator,
            .in_reader = source,
            .to_read = .{},

            .buffer = LzCircularBuffer.init(params.dict_size, memlimit orelse math.maxInt(usize)),
            .decoder = try RangeDecoder.init(source),
            .state = try Decode.init(allocator, params.properties, params.unpacked_size),
        };
    }

    pub fn reader(self: *Decompress) std.io.Reader {
        return .{ .context = self };
    }

    pub fn deinit(self: *Decompress) void {
        self.to_read.deinit(self.allocator);
        self.buffer.deinit(self.allocator);
        self.state.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn read(self: *Decompress, output: []u8) Error!usize {
        const bw = self.to_read.writer(self.allocator);
        while (self.to_read.items.len < output.len) {
            switch (try self.state.process(self.allocator, self.in_reader, bw, &self.buffer, &self.decoder)) {
                .cont => {},
                .finished => {
                    try self.buffer.finish(bw);
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

/// A circular buffer for LZ sequences
const LzCircularBuffer = struct {
    /// Circular buffer
    buf: std.ArrayListUnmanaged(u8),

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
        bw: *std.io.BufferedWriter,
    ) std.io.Writer.Error!void {
        try self.set(allocator, self.cursor, lit);
        self.cursor += 1;
        self.len += 1;

        // Flush the circular buffer to the output
        if (self.cursor == self.dict_size) {
            try bw.writeAll(self.buf.items);
            self.cursor = 0;
        }
    }

    /// Fetch an LZ sequence (length, distance) from inside the buffer
    pub fn appendLz(
        self: *Self,
        allocator: Allocator,
        len: usize,
        dist: usize,
        bw: *std.io.BufferedWriter,
    ) std.io.Writer.Error!void {
        if (dist > self.dict_size or dist > self.len) {
            return error.CorruptInput;
        }

        var offset = (self.dict_size + self.cursor - dist) % self.dict_size;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const x = self.get(offset);
            try self.appendLiteral(allocator, x, bw);
            offset += 1;
            if (offset == self.dict_size) {
                offset = 0;
            }
        }
    }

    pub fn finish(self: *Self, bw: *std.io.BufferedWriter) std.io.Writer.Error!void {
        if (self.cursor > 0) {
            try bw.writeAll(self.buf.items[0..self.cursor]);
            self.cursor = 0;
        }
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.buf.deinit(allocator);
        self.* = undefined;
    }
};

pub fn Vec2D(comptime T: type) type {
    return struct {
        data: []T,
        cols: usize,

        const Self = @This();

        pub fn init(allocator: Allocator, value: T, size: struct { usize, usize }) !Self {
            const len = try math.mul(usize, size[0], size[1]);
            const data = try allocator.alloc(T, len);
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

        pub fn fill(self: *Self, value: T) void {
            @memset(self.data, value);
        }

        inline fn _get(self: Self, row: usize) ![]T {
            const start_row = try math.mul(usize, row, self.cols);
            const end_row = try math.add(usize, start_row, self.cols);
            return self.data[start_row..end_row];
        }

        pub fn get(self: Self, row: usize) ![]const T {
            return self._get(row);
        }

        pub fn getMut(self: *Self, row: usize) ![]T {
            return self._get(row);
        }
    };
}

test "Vec2D init" {
    const allocator = testing.allocator;
    var vec2d = try Vec2D(i32).init(allocator, 1, .{ 2, 3 });
    defer vec2d.deinit(allocator);

    try expectEqualSlices(i32, &.{ 1, 1, 1 }, try vec2d.get(0));
    try expectEqualSlices(i32, &.{ 1, 1, 1 }, try vec2d.get(1));
}

test "Vec2D init overflow" {
    const allocator = testing.allocator;
    try expectError(
        error.Overflow,
        Vec2D(i32).init(allocator, 1, .{ math.maxInt(usize), math.maxInt(usize) }),
    );
}

test "Vec2D fill" {
    const allocator = testing.allocator;
    var vec2d = try Vec2D(i32).init(allocator, 0, .{ 2, 3 });
    defer vec2d.deinit(allocator);

    vec2d.fill(7);

    try expectEqualSlices(i32, &.{ 7, 7, 7 }, try vec2d.get(0));
    try expectEqualSlices(i32, &.{ 7, 7, 7 }, try vec2d.get(1));
}

test "Vec2D get" {
    var data = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const vec2d = Vec2D(i32){
        .data = &data,
        .cols = 2,
    };

    try expectEqualSlices(i32, &.{ 0, 1 }, try vec2d.get(0));
    try expectEqualSlices(i32, &.{ 2, 3 }, try vec2d.get(1));
    try expectEqualSlices(i32, &.{ 4, 5 }, try vec2d.get(2));
    try expectEqualSlices(i32, &.{ 6, 7 }, try vec2d.get(3));
}

test "Vec2D getMut" {
    var data = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    var vec2d = Vec2D(i32){
        .data = &data,
        .cols = 2,
    };

    const row = try vec2d.getMut(1);
    row[1] = 9;

    try expectEqualSlices(i32, &.{ 0, 1 }, try vec2d.get(0));
    // (1, 1) should be 9.
    try expectEqualSlices(i32, &.{ 2, 9 }, try vec2d.get(1));
    try expectEqualSlices(i32, &.{ 4, 5 }, try vec2d.get(2));
    try expectEqualSlices(i32, &.{ 6, 7 }, try vec2d.get(3));
}

test "Vec2D get multiplication overflow" {
    const allocator = testing.allocator;
    var matrix = try Vec2D(i32).init(allocator, 0, .{ 3, 4 });
    defer matrix.deinit(allocator);

    const row = (math.maxInt(usize) / 4) + 1;
    try expectError(error.Overflow, matrix.get(row));
    try expectError(error.Overflow, matrix.getMut(row));
}

test "Vec2D get addition overflow" {
    const allocator = testing.allocator;
    var matrix = try Vec2D(i32).init(allocator, 0, .{ 3, 5 });
    defer matrix.deinit(allocator);

    const row = math.maxInt(usize) / 5;
    try expectError(error.Overflow, matrix.get(row));
    try expectError(error.Overflow, matrix.getMut(row));
}

fn testDecompress(compressed: []const u8) ![]u8 {
    const allocator = std.testing.allocator;
    var br: std.io.Reader = undefined;
    br.initFixed(compressed);
    var decompressor = try Decompress.initOptions(allocator, &br, .{});
    defer decompressor.deinit();
    const reader = decompressor.reader();
    return reader.readAllAlloc(allocator, std.math.maxInt(usize));
}

fn testDecompressEqual(expected: []const u8, compressed: []const u8) !void {
    const allocator = std.testing.allocator;
    const decomp = try testDecompress(compressed);
    defer allocator.free(decomp);
    try std.testing.expectEqualSlices(u8, expected, decomp);
}

fn testDecompressError(expected: anyerror, compressed: []const u8) !void {
    return std.testing.expectError(expected, testDecompress(compressed));
}

test "decompress empty world" {
    try testDecompressEqual(
        "",
        &[_]u8{
            0x5d, 0x00, 0x00, 0x80, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x83, 0xff,
            0xfb, 0xff, 0xff, 0xc0, 0x00, 0x00, 0x00,
        },
    );
}

test "decompress hello world" {
    try testDecompressEqual(
        "Hello world\n",
        &[_]u8{
            0x5d, 0x00, 0x00, 0x80, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x24, 0x19,
            0x49, 0x98, 0x6f, 0x10, 0x19, 0xc6, 0xd7, 0x31, 0xeb, 0x36, 0x50, 0xb2, 0x98, 0x48, 0xff, 0xfe,
            0xa5, 0xb0, 0x00,
        },
    );
}

test "decompress huge dict" {
    try testDecompressEqual(
        "Hello world\n",
        &[_]u8{
            0x5d, 0x7f, 0x7f, 0x7f, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x24, 0x19,
            0x49, 0x98, 0x6f, 0x10, 0x19, 0xc6, 0xd7, 0x31, 0xeb, 0x36, 0x50, 0xb2, 0x98, 0x48, 0xff, 0xfe,
            0xa5, 0xb0, 0x00,
        },
    );
}

test "unknown size with end of payload marker" {
    try testDecompressEqual(
        "Hello\nWorld!\n",
        @embedFile("testdata/good-unknown_size-with_eopm.lzma"),
    );
}

test "known size without end of payload marker" {
    try testDecompressEqual(
        "Hello\nWorld!\n",
        @embedFile("testdata/good-known_size-without_eopm.lzma"),
    );
}

test "known size with end of payload marker" {
    try testDecompressEqual(
        "Hello\nWorld!\n",
        @embedFile("testdata/good-known_size-with_eopm.lzma"),
    );
}

test "too big uncompressed size in header" {
    try testDecompressError(
        error.CorruptInput,
        @embedFile("testdata/bad-too_big_size-with_eopm.lzma"),
    );
}

test "too small uncompressed size in header" {
    try testDecompressError(
        error.CorruptInput,
        @embedFile("testdata/bad-too_small_size-without_eopm-3.lzma"),
    );
}

test "reading one byte" {
    const compressed = @embedFile("testdata/good-known_size-with_eopm.lzma");
    var br: std.io.Reader = undefined;
    br.initFixed(compressed);
    var decompressor = try Decompress.initOptions(std.testing.allocator, &br, .{});
    defer decompressor.deinit();
    var buffer = [1]u8{0};
    _ = try decompressor.read(buffer[0..]);
}
