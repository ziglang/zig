const std = @import("../../std.zig");
const lzma = @import("lzma.zig");
const Allocator = std.mem.Allocator;
const Crc32 = std.hash.Crc32;
const Crc64 = std.hash.crc.Crc64Xz;
const Sha256 = std.crypto.hash.sha2.Sha256;
const xz = std.compress.xz;

const DecodeError = error{
    CorruptInput,
    EndOfStream,
    EndOfStreamWithNoError,
    WrongChecksum,
    Unsupported,
    Overflow,
};

pub fn decoder(allocator: Allocator, reader: anytype, check: xz.Check) !Decoder(@TypeOf(reader)) {
    return Decoder(@TypeOf(reader)).init(allocator, reader, check);
}

pub fn Decoder(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        pub const Error =
            ReaderType.Error ||
            DecodeError ||
            Allocator.Error;
        pub const Reader = std.io.Reader(*Self, Error, read);

        allocator: Allocator,
        inner_reader: ReaderType,
        check: xz.Check,
        err: ?Error,
        accum: lzma.LzAccumBuffer,
        lzma_state: lzma.DecoderState,
        block_count: usize,

        fn init(allocator: Allocator, in_reader: ReaderType, check: xz.Check) !Self {
            return Self{
                .allocator = allocator,
                .inner_reader = in_reader,
                .check = check,
                .err = null,
                .accum = .{},
                .lzma_state = try lzma.DecoderState.init(allocator),
                .block_count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.accum.deinit(self.allocator);
            self.lzma_state.deinit(self.allocator);
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, output: []u8) Error!usize {
            while (true) {
                if (self.accum.to_read.items.len > 0) {
                    const n = self.accum.read(output);
                    if (self.accum.to_read.items.len == 0 and self.err != null) {
                        if (self.err.? == DecodeError.EndOfStreamWithNoError) {
                            return n;
                        }
                        return self.err.?;
                    }
                    return n;
                }
                if (self.err != null) {
                    if (self.err.? == DecodeError.EndOfStreamWithNoError) {
                        return 0;
                    }
                    return self.err.?;
                }
                self.readBlock() catch |e| {
                    self.err = e;
                    if (self.accum.to_read.items.len == 0) {
                        try self.accum.reset(self.allocator);
                    }
                };
            }
        }

        fn readBlock(self: *Self) Error!void {
            const unpacked_pos = self.accum.to_read.items.len;

            var block_counter = std.io.countingReader(self.inner_reader);
            const block_reader = block_counter.reader();

            var packed_size: ?u64 = null;
            var unpacked_size: ?u64 = null;

            // Block Header
            {
                var header_hasher = std.compress.hashedReader(block_reader, Crc32.init());
                const header_reader = header_hasher.reader();

                const header_size = try header_reader.readByte() * 4;
                if (header_size == 0)
                    return error.EndOfStreamWithNoError;

                const Flags = packed struct(u8) {
                    last_filter_index: u2,
                    reserved: u4,
                    has_packed_size: bool,
                    has_unpacked_size: bool,
                };

                const flags = @bitCast(Flags, try header_reader.readByte());
                const filter_count = @as(u3, flags.last_filter_index) + 1;
                if (filter_count > 1)
                    return error.Unsupported;

                if (flags.has_packed_size)
                    packed_size = try std.leb.readULEB128(u64, header_reader);

                if (flags.has_unpacked_size)
                    unpacked_size = try std.leb.readULEB128(u64, header_reader);

                const FilterId = enum(u64) {
                    lzma2 = 0x21,
                    _,
                };

                const filter_id = @intToEnum(
                    FilterId,
                    try std.leb.readULEB128(u64, header_reader),
                );

                if (@enumToInt(filter_id) >= 0x4000_0000_0000_0000)
                    return error.CorruptInput;

                if (filter_id != .lzma2)
                    return error.Unsupported;

                const properties_size = try std.leb.readULEB128(u64, header_reader);
                if (properties_size != 1)
                    return error.CorruptInput;

                // TODO: use filter properties
                _ = try header_reader.readByte();

                while (block_counter.bytes_read != header_size) {
                    if (try header_reader.readByte() != 0)
                        return error.CorruptInput;
                }

                const hash_a = header_hasher.hasher.final();
                const hash_b = try header_reader.readIntLittle(u32);
                if (hash_a != hash_b)
                    return error.WrongChecksum;
            }

            // Compressed Data
            var packed_counter = std.io.countingReader(block_reader);
            const packed_reader = packed_counter.reader();
            while (try self.readLzma2Chunk(packed_reader)) {}

            if (packed_size) |s| {
                if (s != packed_counter.bytes_read)
                    return error.CorruptInput;
            }

            const unpacked_bytes = self.accum.to_read.items[unpacked_pos..];
            if (unpacked_size) |s| {
                if (s != unpacked_bytes.len)
                    return error.CorruptInput;
            }

            // Block Padding
            while (block_counter.bytes_read % 4 != 0) {
                if (try block_reader.readByte() != 0)
                    return error.CorruptInput;
            }

            switch (self.check) {
                .none => {},
                .crc32 => {
                    const hash_a = Crc32.hash(unpacked_bytes);
                    const hash_b = try self.inner_reader.readIntLittle(u32);
                    if (hash_a != hash_b)
                        return error.WrongChecksum;
                },
                .crc64 => {
                    const hash_a = Crc64.hash(unpacked_bytes);
                    const hash_b = try self.inner_reader.readIntLittle(u64);
                    if (hash_a != hash_b)
                        return error.WrongChecksum;
                },
                .sha256 => {
                    var hash_a: [Sha256.digest_length]u8 = undefined;
                    Sha256.hash(unpacked_bytes, &hash_a, .{});

                    var hash_b: [Sha256.digest_length]u8 = undefined;
                    try self.inner_reader.readNoEof(&hash_b);

                    if (!std.mem.eql(u8, &hash_a, &hash_b))
                        return error.WrongChecksum;
                },
                else => return error.Unsupported,
            }

            self.block_count += 1;
        }

        fn readLzma2Chunk(self: *Self, packed_reader: anytype) Error!bool {
            const status = try packed_reader.readByte();
            switch (status) {
                0 => {
                    try self.accum.reset(self.allocator);
                    return false;
                },
                1, 2 => {
                    if (status == 1)
                        try self.accum.reset(self.allocator);

                    const size = try packed_reader.readIntBig(u16) + 1;
                    try self.accum.ensureUnusedCapacity(self.allocator, size);

                    var i: usize = 0;
                    while (i < size) : (i += 1)
                        self.accum.appendAssumeCapacity(try packed_reader.readByte());

                    return true;
                },
                else => {
                    if (status & 0x80 == 0)
                        return error.CorruptInput;

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
                        tmp |= try packed_reader.readIntBig(u16);
                        break :blk tmp + 1;
                    };

                    const packed_size = blk: {
                        const tmp: u17 = try packed_reader.readIntBig(u16);
                        break :blk tmp + 1;
                    };

                    if (reset.dict)
                        try self.accum.reset(self.allocator);

                    if (reset.state) {
                        var new_props = self.lzma_state.lzma_props;

                        if (reset.props) {
                            var props = try packed_reader.readByte();
                            if (props >= 225)
                                return error.CorruptInput;

                            const lc = @intCast(u4, props % 9);
                            props /= 9;
                            const lp = @intCast(u3, props % 5);
                            props /= 5;
                            const pb = @intCast(u3, props);

                            if (lc + lp > 4)
                                return error.CorruptInput;

                            new_props = .{ .lc = lc, .lp = lp, .pb = pb };
                        }

                        try self.lzma_state.reset_state(self.allocator, new_props);
                    }

                    self.lzma_state.unpacked_size = unpacked_size + self.accum.len();

                    const buffer = try self.allocator.alloc(u8, packed_size);
                    defer self.allocator.free(buffer);

                    for (buffer) |*b|
                        b.* = try packed_reader.readByte();

                    var rangecoder = try lzma.RangeDecoder.init(buffer);
                    try self.lzma_state.process(self.allocator, &self.accum, &rangecoder);

                    return true;
                },
            }
        }
    };
}
