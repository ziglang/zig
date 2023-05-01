const std = @import("../std.zig");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const decode = @import("lzma/decode.zig");

pub fn decompress(
    allocator: Allocator,
    reader: anytype,
) !Decompress(@TypeOf(reader)) {
    return decompressWithOptions(allocator, reader, .{});
}

pub fn decompressWithOptions(
    allocator: Allocator,
    reader: anytype,
    options: decode.Options,
) !Decompress(@TypeOf(reader)) {
    const params = try decode.Params.readHeader(reader, options);
    return Decompress(@TypeOf(reader)).init(allocator, reader, params, options.memlimit);
}

pub fn Decompress(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error =
            ReaderType.Error ||
            Allocator.Error ||
            error{ CorruptInput, EndOfStream, Overflow };

        pub const Reader = std.io.Reader(*Self, Error, read);

        allocator: Allocator,
        in_reader: ReaderType,
        to_read: std.ArrayListUnmanaged(u8),

        buffer: decode.lzbuffer.LzCircularBuffer,
        decoder: decode.rangecoder.RangeDecoder,
        state: decode.DecoderState,

        pub fn init(allocator: Allocator, source: ReaderType, params: decode.Params, memlimit: ?usize) !Self {
            return Self{
                .allocator = allocator,
                .in_reader = source,
                .to_read = .{},

                .buffer = decode.lzbuffer.LzCircularBuffer.init(params.dict_size, memlimit orelse math.maxInt(usize)),
                .decoder = try decode.rangecoder.RangeDecoder.init(source),
                .state = try decode.DecoderState.init(allocator, params.properties, params.unpacked_size),
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
            @memcpy(input[0 .. input.len - n], input[n..]);
            self.to_read.shrinkRetainingCapacity(input.len - n);
            return n;
        }
    };
}

test {
    _ = @import("lzma/test.zig");
    _ = @import("lzma/vec2d.zig");
}
