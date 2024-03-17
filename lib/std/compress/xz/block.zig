const std = @import("../../std.zig");
const lzma2 = std.compress.lzma2;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
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
        to_read: ArrayListUnmanaged(u8),
        read_pos: usize,
        block_count: usize,

        fn init(allocator: Allocator, in_reader: ReaderType, check: xz.Check) !Self {
            return Self{
                .allocator = allocator,
                .inner_reader = in_reader,
                .check = check,
                .err = null,
                .to_read = .{},
                .read_pos = 0,
                .block_count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.to_read.deinit(self.allocator);
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, output: []u8) Error!usize {
            while (true) {
                const unread_len = self.to_read.items.len - self.read_pos;
                if (unread_len > 0) {
                    const n = @min(unread_len, output.len);
                    @memcpy(output[0..n], self.to_read.items[self.read_pos..][0..n]);
                    self.read_pos += n;
                    return n;
                }
                if (self.err) |e| {
                    if (e == DecodeError.EndOfStreamWithNoError) {
                        return 0;
                    }
                    return e;
                }
                if (self.read_pos > 0) {
                    self.to_read.shrinkRetainingCapacity(0);
                    self.read_pos = 0;
                }
                self.readBlock() catch |e| {
                    self.err = e;
                };
            }
        }

        fn readBlock(self: *Self) Error!void {
            var block_counter = std.io.countingReader(self.inner_reader);
            const block_reader = block_counter.reader();

            var packed_size: ?u64 = null;
            var unpacked_size: ?u64 = null;

            // Block Header
            {
                var header_hasher = std.compress.hashedReader(block_reader, Crc32.init());
                const header_reader = header_hasher.reader();

                const header_size = @as(u64, try header_reader.readByte()) * 4;
                if (header_size == 0)
                    return error.EndOfStreamWithNoError;

                const Flags = packed struct(u8) {
                    last_filter_index: u2,
                    reserved: u4,
                    has_packed_size: bool,
                    has_unpacked_size: bool,
                };

                const flags = @as(Flags, @bitCast(try header_reader.readByte()));
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

                const filter_id = @as(
                    FilterId,
                    @enumFromInt(try std.leb.readULEB128(u64, header_reader)),
                );

                if (@intFromEnum(filter_id) >= 0x4000_0000_0000_0000)
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
                const hash_b = try header_reader.readInt(u32, .little);
                if (hash_a != hash_b)
                    return error.WrongChecksum;
            }

            // Compressed Data
            var packed_counter = std.io.countingReader(block_reader);
            try lzma2.decompress(
                self.allocator,
                packed_counter.reader(),
                self.to_read.writer(self.allocator),
            );

            if (packed_size) |s| {
                if (s != packed_counter.bytes_read)
                    return error.CorruptInput;
            }

            const unpacked_bytes = self.to_read.items;
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
                    const hash_b = try self.inner_reader.readInt(u32, .little);
                    if (hash_a != hash_b)
                        return error.WrongChecksum;
                },
                .crc64 => {
                    const hash_a = Crc64.hash(unpacked_bytes);
                    const hash_b = try self.inner_reader.readInt(u64, .little);
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
    };
}
