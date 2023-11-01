const std = @import("../../std.zig");
const assert = std.debug.assert;
const math = std.math;
const Allocator = std.mem.Allocator;

pub const lzbuffer = @import("decode/lzbuffer.zig");
pub const rangecoder = @import("decode/rangecoder.zig");

const LzCircularBuffer = lzbuffer.LzCircularBuffer;
const BitTree = rangecoder.BitTree;
const LenDecoder = rangecoder.LenDecoder;
const RangeDecoder = rangecoder.RangeDecoder;
const Vec2D = @import("vec2d.zig").Vec2D;

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

pub const DecoderState = struct {
    lzma_props: Properties,
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

    pub fn init(
        allocator: Allocator,
        lzma_props: Properties,
        unpacked_size: ?u64,
    ) !DecoderState {
        return .{
            .lzma_props = lzma_props,
            .unpacked_size = unpacked_size,
            .literal_probs = try Vec2D(u16).init(allocator, 0x400, .{ @as(usize, 1) << (lzma_props.lc + lzma_props.lp), 0x300 }),
            .pos_slot_decoder = .{.{}} ** 4,
            .align_decoder = .{},
            .pos_decoders = .{0x400} ** 115,
            .is_match = .{0x400} ** 192,
            .is_rep = .{0x400} ** 12,
            .is_rep_g0 = .{0x400} ** 12,
            .is_rep_g1 = .{0x400} ** 12,
            .is_rep_g2 = .{0x400} ** 12,
            .is_rep_0long = .{0x400} ** 192,
            .state = 0,
            .rep = .{0} ** 4,
            .len_decoder = .{},
            .rep_len_decoder = .{},
        };
    }

    pub fn deinit(self: *DecoderState, allocator: Allocator) void {
        self.literal_probs.deinit(allocator);
        self.* = undefined;
    }

    pub fn resetState(self: *DecoderState, allocator: Allocator, new_props: Properties) !void {
        new_props.validate();
        if (self.lzma_props.lc + self.lzma_props.lp == new_props.lc + new_props.lp) {
            self.literal_probs.fill(0x400);
        } else {
            self.literal_probs.deinit(allocator);
            self.literal_probs = try Vec2D(u16).init(allocator, 0x400, .{ @as(usize, 1) << (new_props.lc + new_props.lp), 0x300 });
        }

        self.lzma_props = new_props;
        for (&self.pos_slot_decoder) |*t| t.reset();
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
        self: *DecoderState,
        allocator: Allocator,
        reader: anytype,
        writer: anytype,
        buffer: anytype,
        decoder: *RangeDecoder,
    ) !ProcessingStatus {
        return self.processNextInner(allocator, reader, writer, buffer, decoder, true);
    }

    pub fn process(
        self: *DecoderState,
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
        self: *DecoderState,
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
        self: *DecoderState,
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
};
