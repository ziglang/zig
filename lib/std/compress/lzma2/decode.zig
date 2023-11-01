const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;

const lzma = @import("../lzma.zig");
const DecoderState = lzma.decode.DecoderState;
const LzAccumBuffer = lzma.decode.lzbuffer.LzAccumBuffer;
const Properties = lzma.decode.Properties;
const RangeDecoder = lzma.decode.rangecoder.RangeDecoder;

pub const Decoder = struct {
    lzma_state: DecoderState,

    pub fn init(allocator: Allocator) !Decoder {
        return Decoder{
            .lzma_state = try DecoderState.init(
                allocator,
                Properties{
                    .lc = 0,
                    .lp = 0,
                    .pb = 0,
                },
                null,
            ),
        };
    }

    pub fn deinit(self: *Decoder, allocator: Allocator) void {
        self.lzma_state.deinit(allocator);
        self.* = undefined;
    }

    pub fn decompress(
        self: *Decoder,
        allocator: Allocator,
        reader: anytype,
        writer: anytype,
    ) !void {
        var accum = LzAccumBuffer.init(std.math.maxInt(usize));
        defer accum.deinit(allocator);

        while (true) {
            const status = try reader.readByte();

            switch (status) {
                0 => break,
                1 => try parseUncompressed(allocator, reader, writer, &accum, true),
                2 => try parseUncompressed(allocator, reader, writer, &accum, false),
                else => try self.parseLzma(allocator, reader, writer, &accum, status),
            }
        }

        try accum.finish(writer);
    }

    fn parseLzma(
        self: *Decoder,
        allocator: Allocator,
        reader: anytype,
        writer: anytype,
        accum: *LzAccumBuffer,
        status: u8,
    ) !void {
        if (status & 0x80 == 0) {
            return error.CorruptInput;
        }

        const Reset = struct {
            dict: bool,
            state: bool,
            props: bool,
        };

        const reset = switch ((status >> 5) & 0x3) {
            0 => Reset{
                .dict = false,
                .state = false,
                .props = false,
            },
            1 => Reset{
                .dict = false,
                .state = true,
                .props = false,
            },
            2 => Reset{
                .dict = false,
                .state = true,
                .props = true,
            },
            3 => Reset{
                .dict = true,
                .state = true,
                .props = true,
            },
            else => unreachable,
        };

        const unpacked_size = blk: {
            var tmp: u64 = status & 0x1F;
            tmp <<= 16;
            tmp |= try reader.readInt(u16, .big);
            break :blk tmp + 1;
        };

        const packed_size = blk: {
            const tmp: u17 = try reader.readInt(u16, .big);
            break :blk tmp + 1;
        };

        if (reset.dict) {
            try accum.reset(writer);
        }

        if (reset.state) {
            var new_props = self.lzma_state.lzma_props;

            if (reset.props) {
                var props = try reader.readByte();
                if (props >= 225) {
                    return error.CorruptInput;
                }

                const lc = @as(u4, @intCast(props % 9));
                props /= 9;
                const lp = @as(u3, @intCast(props % 5));
                props /= 5;
                const pb = @as(u3, @intCast(props));

                if (lc + lp > 4) {
                    return error.CorruptInput;
                }

                new_props = Properties{ .lc = lc, .lp = lp, .pb = pb };
            }

            try self.lzma_state.resetState(allocator, new_props);
        }

        self.lzma_state.unpacked_size = unpacked_size + accum.len;

        var counter = std.io.countingReader(reader);
        const counter_reader = counter.reader();

        var rangecoder = try RangeDecoder.init(counter_reader);
        while (try self.lzma_state.process(allocator, counter_reader, writer, accum, &rangecoder) == .continue_) {}

        if (counter.bytes_read != packed_size) {
            return error.CorruptInput;
        }
    }

    fn parseUncompressed(
        allocator: Allocator,
        reader: anytype,
        writer: anytype,
        accum: *LzAccumBuffer,
        reset_dict: bool,
    ) !void {
        const unpacked_size = @as(u17, try reader.readInt(u16, .big)) + 1;

        if (reset_dict) {
            try accum.reset(writer);
        }

        var i: @TypeOf(unpacked_size) = 0;
        while (i < unpacked_size) : (i += 1) {
            try accum.appendByte(allocator, try reader.readByte());
        }
    }
};
