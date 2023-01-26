// Ported from https://github.com/gendx/lzma-rs

const std = @import("../../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const LzmaProperties = struct {
    lc: u4,
    lp: u3,
    pb: u3,

    fn validate(self: LzmaProperties) void {
        assert(self.lc <= 8);
        assert(self.lp <= 4);
        assert(self.pb <= 4);
    }
};

pub const DecoderState = struct {
    lzma_props: LzmaProperties,
    unpacked_size: ?u64,
    literal_probs: Vec2D(u16),
    pos_slot_decoder: [4]BitTree,
    align_decoder: BitTree,
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

    pub fn init(allocator: Allocator) !DecoderState {
        return .{
            .lzma_props = LzmaProperties{ .lc = 0, .lp = 0, .pb = 0 },
            .unpacked_size = null,
            .literal_probs = try Vec2D(u16).init(allocator, 0x400, 1, 0x300),
            .pos_slot_decoder = .{
                try BitTree.init(allocator, 6),
                try BitTree.init(allocator, 6),
                try BitTree.init(allocator, 6),
                try BitTree.init(allocator, 6),
            },
            .align_decoder = try BitTree.init(allocator, 4),
            .pos_decoders = .{0x400} ** 115,
            .is_match = .{0x400} ** 192,
            .is_rep = .{0x400} ** 12,
            .is_rep_g0 = .{0x400} ** 12,
            .is_rep_g1 = .{0x400} ** 12,
            .is_rep_g2 = .{0x400} ** 12,
            .is_rep_0long = .{0x400} ** 192,
            .state = 0,
            .rep = .{0} ** 4,
            .len_decoder = try LenDecoder.init(allocator),
            .rep_len_decoder = try LenDecoder.init(allocator),
        };
    }

    pub fn deinit(self: *DecoderState, allocator: Allocator) void {
        self.literal_probs.deinit(allocator);
        for (self.pos_slot_decoder) |*t| t.deinit(allocator);
        self.align_decoder.deinit(allocator);
        self.len_decoder.deinit(allocator);
        self.rep_len_decoder.deinit(allocator);
    }

    pub fn reset_state(self: *DecoderState, allocator: Allocator, new_props: LzmaProperties) !void {
        new_props.validate();
        if (self.lzma_props.lc + self.lzma_props.lp == new_props.lc + new_props.lp) {
            self.literal_probs.fill(0x400);
        } else {
            self.literal_probs.deinit(allocator);
            self.literal_probs = try Vec2D(u16).init(allocator, 0x400, @as(usize, 1) << (new_props.lc + new_props.lp), 0x300);
        }

        self.lzma_props = new_props;
        for (self.pos_slot_decoder) |*t| t.reset();
        self.align_decoder.reset();
        self.pos_decoders = .{0x400} ** 115;
        self.is_match = .{0x400} ** 192;
        self.is_rep = .{0x400} ** 12;
        self.is_rep_g0 = .{0x400} ** 12;
        self.is_rep_g1 = .{0x400} ** 12;
        self.is_rep_g2 = .{0x400} ** 12;
        self.is_rep_0long = .{0x400} ** 192;
        self.state = 0;
        self.rep = .{0} ** 4;
        self.len_decoder.reset();
        self.rep_len_decoder.reset();
    }

    fn processNextInner(
        self: *DecoderState,
        allocator: Allocator,
        output: *LzAccumBuffer,
        rangecoder: *RangeDecoder,
        update: bool,
    ) !ProcessingStatus {
        const pos_state = output.len() & ((@as(usize, 1) << self.lzma_props.pb) - 1);

        if (!try rangecoder.decodeBit(
            &self.is_match[(self.state << 4) + pos_state],
            update,
        )) {
            const byte: u8 = try self.decodeLiteral(output, rangecoder, update);

            if (update) {
                try output.appendLiteral(allocator, byte);

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
        if (try rangecoder.decodeBit(&self.is_rep[self.state], update)) {
            if (!try rangecoder.decodeBit(&self.is_rep_g0[self.state], update)) {
                if (!try rangecoder.decodeBit(
                    &self.is_rep_0long[(self.state << 4) + pos_state],
                    update,
                )) {
                    if (update) {
                        self.state = if (self.state < 7) 9 else 11;
                        const dist = self.rep[0] + 1;
                        try output.appendLz(allocator, 1, dist);
                    }
                    return .continue_;
                }
            } else {
                const idx: usize = if (!try rangecoder.decodeBit(&self.is_rep_g1[self.state], update))
                    1
                else if (!try rangecoder.decodeBit(&self.is_rep_g2[self.state], update))
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

            len = try self.rep_len_decoder.decode(rangecoder, pos_state, update);

            if (update) {
                self.state = if (self.state < 7) 8 else 11;
            }
        } else {
            if (update) {
                self.rep[3] = self.rep[2];
                self.rep[2] = self.rep[1];
                self.rep[1] = self.rep[0];
            }

            len = try self.len_decoder.decode(rangecoder, pos_state, update);

            if (update) {
                self.state = if (self.state < 7) 7 else 10;
            }

            const rep_0 = try self.decodeDistance(rangecoder, len, update);

            if (update) {
                self.rep[0] = rep_0;
                if (self.rep[0] == 0xFFFF_FFFF) {
                    if (rangecoder.isFinished()) {
                        return .finished;
                    }
                    return error.CorruptInput;
                }
            }
        }

        if (update) {
            len += 2;

            const dist = self.rep[0] + 1;
            try output.appendLz(allocator, len, dist);
        }

        return .continue_;
    }

    fn processNext(
        self: *DecoderState,
        allocator: Allocator,
        output: *LzAccumBuffer,
        rangecoder: *RangeDecoder,
    ) !ProcessingStatus {
        return self.processNextInner(allocator, output, rangecoder, true);
    }

    pub fn process(
        self: *DecoderState,
        allocator: Allocator,
        output: *LzAccumBuffer,
        rangecoder: *RangeDecoder,
    ) !void {
        while (true) {
            if (self.unpacked_size) |unpacked_size| {
                if (output.len() >= unpacked_size) {
                    break;
                }
            } else if (rangecoder.isFinished()) {
                break;
            }

            if (try self.processNext(allocator, output, rangecoder) == .finished) {
                break;
            }
        }

        if (self.unpacked_size) |len| {
            if (len != output.len()) {
                return error.CorruptInput;
            }
        }
    }

    fn decodeLiteral(
        self: *DecoderState,
        output: *LzAccumBuffer,
        rangecoder: *RangeDecoder,
        update: bool,
    ) !u8 {
        const def_prev_byte = 0;
        const prev_byte = @as(usize, output.lastOr(def_prev_byte));

        var result: usize = 1;
        const lit_state = ((output.len() & ((@as(usize, 1) << self.lzma_props.lp) - 1)) << self.lzma_props.lc) +
            (prev_byte >> (8 - self.lzma_props.lc));
        const probs = try self.literal_probs.get(lit_state);

        if (self.state >= 7) {
            var match_byte = @as(usize, try output.lastN(self.rep[0] + 1));

            while (result < 0x100) {
                const match_bit = (match_byte >> 7) & 1;
                match_byte <<= 1;
                const bit = @boolToInt(try rangecoder.decodeBit(
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
            result = (result << 1) ^ @boolToInt(try rangecoder.decodeBit(&probs[result], update));
        }

        return @truncate(u8, result - 0x100);
    }

    fn decodeDistance(
        self: *DecoderState,
        rangecoder: *RangeDecoder,
        length: usize,
        update: bool,
    ) !usize {
        const len_state = if (length > 3) 3 else length;

        const pos_slot = @as(usize, try self.pos_slot_decoder[len_state].parse(rangecoder, update));
        if (pos_slot < 4)
            return pos_slot;

        const num_direct_bits = @intCast(u5, (pos_slot >> 1) - 1);
        var result = (2 ^ (pos_slot & 1)) << num_direct_bits;

        if (pos_slot < 14) {
            result += try rangecoder.parseReverseBitTree(
                num_direct_bits,
                &self.pos_decoders,
                result - pos_slot,
                update,
            );
        } else {
            result += @as(usize, try rangecoder.get(num_direct_bits - 4)) << 4;
            result += try self.align_decoder.parseReverse(rangecoder, update);
        }

        return result;
    }
};

const ProcessingStatus = enum {
    continue_,
    finished,
};

pub const LzAccumBuffer = struct {
    to_read: ArrayListUnmanaged(u8) = .{},
    buf: ArrayListUnmanaged(u8) = .{},

    pub fn deinit(self: *LzAccumBuffer, allocator: Allocator) void {
        self.to_read.deinit(allocator);
        self.buf.deinit(allocator);
    }

    pub fn read(self: *LzAccumBuffer, output: []u8) usize {
        const input = self.to_read.items;
        const n = std.math.min(input.len, output.len);
        std.mem.copy(u8, output[0..n], input[0..n]);
        std.mem.copy(u8, input, input[n..]);
        self.to_read.shrinkRetainingCapacity(input.len - n);
        return n;
    }

    pub fn ensureUnusedCapacity(
        self: *LzAccumBuffer,
        allocator: Allocator,
        additional_count: usize,
    ) !void {
        try self.buf.ensureUnusedCapacity(allocator, additional_count);
    }

    pub fn appendAssumeCapacity(self: *LzAccumBuffer, byte: u8) void {
        self.buf.appendAssumeCapacity(byte);
    }

    pub fn reset(self: *LzAccumBuffer, allocator: Allocator) !void {
        try self.to_read.appendSlice(allocator, self.buf.items);
        self.buf.clearRetainingCapacity();
    }

    pub fn len(self: *const LzAccumBuffer) usize {
        return self.buf.items.len;
    }

    pub fn lastOr(self: *const LzAccumBuffer, lit: u8) u8 {
        const buf_len = self.buf.items.len;
        return if (buf_len == 0)
            lit
        else
            self.buf.items[buf_len - 1];
    }

    pub fn lastN(self: *const LzAccumBuffer, dist: usize) !u8 {
        const buf_len = self.buf.items.len;
        if (dist > buf_len) {
            return error.CorruptInput;
        }

        return self.buf.items[buf_len - dist];
    }

    pub fn appendLiteral(self: *LzAccumBuffer, allocator: Allocator, lit: u8) !void {
        try self.buf.append(allocator, lit);
    }

    pub fn appendLz(self: *LzAccumBuffer, allocator: Allocator, length: usize, dist: usize) !void {
        const buf_len = self.buf.items.len;
        if (dist > buf_len) {
            return error.CorruptInput;
        }

        var offset = buf_len - dist;
        var i: usize = 0;
        while (i < length) : (i += 1) {
            const x = self.buf.items[offset];
            try self.buf.append(allocator, x);
            offset += 1;
        }
    }
};

pub const RangeDecoder = struct {
    stream: std.io.FixedBufferStream([]const u8),
    range: u32,
    code: u32,

    pub fn init(buffer: []const u8) !RangeDecoder {
        var dec = RangeDecoder{
            .stream = std.io.fixedBufferStream(buffer),
            .range = 0xFFFF_FFFF,
            .code = 0,
        };
        const reader = dec.stream.reader();
        _ = try reader.readByte();
        dec.code = try reader.readIntBig(u32);
        return dec;
    }

    pub fn fromParts(
        buffer: []const u8,
        range: u32,
        code: u32,
    ) RangeDecoder {
        return .{
            .stream = std.io.fixedBufferStream(buffer),
            .range = range,
            .code = code,
        };
    }

    pub fn set(self: *RangeDecoder, range: u32, code: u32) void {
        self.range = range;
        self.code = code;
    }

    pub fn readInto(self: *RangeDecoder, dest: []u8) !usize {
        return self.stream.read(dest);
    }

    pub inline fn isFinished(self: *const RangeDecoder) bool {
        return self.code == 0 and self.isEof();
    }

    pub inline fn isEof(self: *const RangeDecoder) bool {
        return self.stream.pos == self.stream.buffer.len;
    }

    inline fn normalize(self: *RangeDecoder) !void {
        if (self.range < 0x0100_0000) {
            self.range <<= 8;
            self.code = (self.code << 8) ^ @as(u32, try self.stream.reader().readByte());
        }
    }

    inline fn getBit(self: *RangeDecoder) !bool {
        self.range >>= 1;

        const bit = self.code >= self.range;
        if (bit)
            self.code -= self.range;

        try self.normalize();
        return bit;
    }

    fn get(self: *RangeDecoder, count: usize) !u32 {
        var result: u32 = 0;
        var i: usize = 0;
        while (i < count) : (i += 1)
            result = (result << 1) ^ @boolToInt(try self.getBit());
        return result;
    }

    pub inline fn decodeBit(self: *RangeDecoder, prob: *u16, update: bool) !bool {
        const bound = (self.range >> 11) * prob.*;

        if (self.code < bound) {
            if (update)
                prob.* += (0x800 - prob.*) >> 5;
            self.range = bound;

            try self.normalize();
            return false;
        } else {
            if (update)
                prob.* -= prob.* >> 5;
            self.code -= bound;
            self.range -= bound;

            try self.normalize();
            return true;
        }
    }

    fn parseBitTree(
        self: *RangeDecoder,
        num_bits: u5,
        probs: []u16,
        update: bool,
    ) !u32 {
        var tmp: u32 = 1;
        var i: u5 = 0;
        while (i < num_bits) : (i += 1) {
            const bit = try self.decodeBit(&probs[tmp], update);
            tmp = (tmp << 1) ^ @boolToInt(bit);
        }
        return tmp - (@as(u32, 1) << num_bits);
    }

    pub fn parseReverseBitTree(
        self: *RangeDecoder,
        num_bits: u5,
        probs: []u16,
        offset: usize,
        update: bool,
    ) !u32 {
        var result: u32 = 0;
        var tmp: usize = 1;
        var i: u5 = 0;
        while (i < num_bits) : (i += 1) {
            const bit = @boolToInt(try self.decodeBit(&probs[offset + tmp], update));
            tmp = (tmp << 1) ^ bit;
            result ^= @as(u32, bit) << i;
        }
        return result;
    }
};

fn Vec2D(comptime T: type) type {
    return struct {
        data: []T,
        cols: usize,

        const Self = @This();

        pub fn init(allocator: Allocator, data: T, rows: usize, cols: usize) !Self {
            const len = try std.math.mul(usize, rows, cols);
            var vec2d = Self{
                .data = try allocator.alloc(T, len),
                .cols = cols,
            };
            vec2d.fill(data);
            return vec2d;
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.data);
        }

        pub fn fill(self: *Self, value: T) void {
            std.mem.set(T, self.data, value);
        }

        pub fn get(self: *Self, row: usize) ![]T {
            const start_row = try std.math.mul(usize, row, self.cols);
            return self.data[start_row .. start_row + self.cols];
        }
    };
}

const BitTree = struct {
    num_bits: u5,
    probs: ArrayListUnmanaged(u16),

    pub fn init(allocator: Allocator, num_bits: u5) !BitTree {
        var probs_len = @as(usize, 1) << num_bits;
        var probs = try ArrayListUnmanaged(u16).initCapacity(allocator, probs_len);
        while (probs_len > 0) : (probs_len -= 1)
            probs.appendAssumeCapacity(0x400);
        return .{ .num_bits = num_bits, .probs = probs };
    }

    pub fn deinit(self: *BitTree, allocator: Allocator) void {
        self.probs.deinit(allocator);
    }

    pub fn parse(
        self: *BitTree,
        rangecoder: *RangeDecoder,
        update: bool,
    ) !u32 {
        return rangecoder.parseBitTree(self.num_bits, self.probs.items, update);
    }

    pub fn parseReverse(
        self: *BitTree,
        rangecoder: *RangeDecoder,
        update: bool,
    ) !u32 {
        return rangecoder.parseReverseBitTree(self.num_bits, self.probs.items, 0, update);
    }

    pub fn reset(self: *BitTree) void {
        std.mem.set(u16, self.probs.items, 0x400);
    }
};

const LenDecoder = struct {
    choice: u16,
    choice2: u16,
    low_coder: [16]BitTree,
    mid_coder: [16]BitTree,
    high_coder: BitTree,

    pub fn init(allocator: Allocator) !LenDecoder {
        return .{
            .choice = 0x400,
            .choice2 = 0x400,
            .low_coder = .{
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
            },
            .mid_coder = .{
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
                try BitTree.init(allocator, 3),
            },
            .high_coder = try BitTree.init(allocator, 8),
        };
    }

    pub fn deinit(self: *LenDecoder, allocator: Allocator) void {
        for (self.low_coder) |*t| t.deinit(allocator);
        for (self.mid_coder) |*t| t.deinit(allocator);
        self.high_coder.deinit(allocator);
    }

    pub fn decode(
        self: *LenDecoder,
        rangecoder: *RangeDecoder,
        pos_state: usize,
        update: bool,
    ) !usize {
        if (!try rangecoder.decodeBit(&self.choice, update)) {
            return @as(usize, try self.low_coder[pos_state].parse(rangecoder, update));
        } else if (!try rangecoder.decodeBit(&self.choice2, update)) {
            return @as(usize, try self.mid_coder[pos_state].parse(rangecoder, update)) + 8;
        } else {
            return @as(usize, try self.high_coder.parse(rangecoder, update)) + 16;
        }
    }

    pub fn reset(self: *LenDecoder) void {
        self.choice = 0x400;
        self.choice2 = 0x400;
        for (self.low_coder) |*t| t.reset();
        for (self.mid_coder) |*t| t.reset();
        self.high_coder.reset();
    }
};
