const std = @import("../../../std.zig");
const mem = std.mem;

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
            .code = try reader.readIntBig(u32),
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

pub fn BitTree(comptime num_bits: usize) type {
    return struct {
        probs: [1 << num_bits]u16 = .{0x400} ** (1 << num_bits),

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
    low_coder: [16]BitTree(3) = .{.{}} ** 16,
    mid_coder: [16]BitTree(3) = .{.{}} ** 16,
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
