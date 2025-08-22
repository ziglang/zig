const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Crc32 = std.hash.Crc32;
const Crc64 = std.hash.crc.Crc64Xz;
const Sha256 = std.crypto.hash.sha2.Sha256;
const lzma2 = std.compress.lzma2;

pub const Check = enum(u4) {
    none = 0x00,
    crc32 = 0x01,
    crc64 = 0x04,
    sha256 = 0x0A,
    _,
};

fn readStreamFlags(reader: anytype, check: *Check) !void {
    const reserved1 = try reader.readByte();
    if (reserved1 != 0) return error.CorruptInput;
    const byte = try reader.readByte();
    if ((byte >> 4) != 0) return error.CorruptInput;
    check.* = @enumFromInt(@as(u4, @truncate(byte)));
}

pub fn decompress(allocator: Allocator, reader: anytype) !Decompress(@TypeOf(reader)) {
    return Decompress(@TypeOf(reader)).init(allocator, reader);
}

pub fn Decompress(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error || Decoder(ReaderType).Error;
        pub const Reader = std.io.GenericReader(*Self, Error, read);

        allocator: Allocator,
        block_decoder: Decoder(ReaderType),
        in_reader: ReaderType,

        fn init(allocator: Allocator, source: ReaderType) !Self {
            const magic = try source.readBytesNoEof(6);
            if (!std.mem.eql(u8, &magic, &.{ 0xFD, '7', 'z', 'X', 'Z', 0x00 }))
                return error.BadHeader;

            var check: Check = undefined;
            const hash_a = blk: {
                var hasher = hashedReader(source, Crc32.init());
                try readStreamFlags(hasher.reader(), &check);
                break :blk hasher.hasher.final();
            };

            const hash_b = try source.readInt(u32, .little);
            if (hash_a != hash_b)
                return error.WrongChecksum;

            return Self{
                .allocator = allocator,
                .block_decoder = try decoder(allocator, source, check),
                .in_reader = source,
            };
        }

        pub fn deinit(self: *Self) void {
            self.block_decoder.deinit();
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0)
                return 0;

            const r = try self.block_decoder.read(buffer);
            if (r != 0)
                return r;

            const index_size = blk: {
                var hasher = hashedReader(self.in_reader, Crc32.init());
                hasher.hasher.update(&[1]u8{0x00});

                var counter = std.io.countingReader(hasher.reader());
                counter.bytes_read += 1;

                const counting_reader = counter.reader();

                const record_count = try std.leb.readUleb128(u64, counting_reader);
                if (record_count != self.block_decoder.block_count)
                    return error.CorruptInput;

                var i: usize = 0;
                while (i < record_count) : (i += 1) {
                    // TODO: validate records
                    _ = try std.leb.readUleb128(u64, counting_reader);
                    _ = try std.leb.readUleb128(u64, counting_reader);
                }

                while (counter.bytes_read % 4 != 0) {
                    if (try counting_reader.readByte() != 0)
                        return error.CorruptInput;
                }

                const hash_a = hasher.hasher.final();
                const hash_b = try counting_reader.readInt(u32, .little);
                if (hash_a != hash_b)
                    return error.WrongChecksum;

                break :blk counter.bytes_read;
            };

            const hash_a = try self.in_reader.readInt(u32, .little);

            const hash_b = blk: {
                var hasher = hashedReader(self.in_reader, Crc32.init());
                const hashed_reader = hasher.reader();

                const backward_size = (@as(u64, try hashed_reader.readInt(u32, .little)) + 1) * 4;
                if (backward_size != index_size)
                    return error.CorruptInput;

                var check: Check = undefined;
                try readStreamFlags(hashed_reader, &check);

                break :blk hasher.hasher.final();
            };

            if (hash_a != hash_b)
                return error.WrongChecksum;

            const magic = try self.in_reader.readBytesNoEof(2);
            if (!std.mem.eql(u8, &magic, &.{ 'Y', 'Z' }))
                return error.CorruptInput;

            return 0;
        }
    };
}

pub fn HashedReader(ReaderType: type, HasherType: type) type {
    return struct {
        child_reader: ReaderType,
        hasher: HasherType,

        pub const Error = ReaderType.Error;
        pub const Reader = std.io.GenericReader(*@This(), Error, read);

        pub fn read(self: *@This(), buf: []u8) Error!usize {
            const amt = try self.child_reader.read(buf);
            self.hasher.update(buf[0..amt]);
            return amt;
        }

        pub fn reader(self: *@This()) Reader {
            return .{ .context = self };
        }
    };
}

pub fn hashedReader(
    reader: anytype,
    hasher: anytype,
) HashedReader(@TypeOf(reader), @TypeOf(hasher)) {
    return .{ .child_reader = reader, .hasher = hasher };
}

const DecodeError = error{
    CorruptInput,
    EndOfStream,
    EndOfStreamWithNoError,
    WrongChecksum,
    Unsupported,
    Overflow,
};

pub fn decoder(allocator: Allocator, reader: anytype, check: Check) !Decoder(@TypeOf(reader)) {
    return Decoder(@TypeOf(reader)).init(allocator, reader, check);
}

pub fn Decoder(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        pub const Error =
            ReaderType.Error ||
            DecodeError ||
            Allocator.Error;
        pub const Reader = std.io.GenericReader(*Self, Error, read);

        allocator: Allocator,
        inner_reader: ReaderType,
        check: Check,
        err: ?Error,
        to_read: ArrayList(u8),
        read_pos: usize,
        block_count: usize,

        fn init(allocator: Allocator, in_reader: ReaderType, check: Check) !Self {
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
                var header_hasher = hashedReader(block_reader, Crc32.init());
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
                    packed_size = try std.leb.readUleb128(u64, header_reader);

                if (flags.has_unpacked_size)
                    unpacked_size = try std.leb.readUleb128(u64, header_reader);

                const FilterId = enum(u64) {
                    lzma2 = 0x21,
                    _,
                };

                const filter_id = @as(
                    FilterId,
                    @enumFromInt(try std.leb.readUleb128(u64, header_reader)),
                );

                if (@intFromEnum(filter_id) >= 0x4000_0000_0000_0000)
                    return error.CorruptInput;

                if (filter_id != .lzma2)
                    return error.Unsupported;

                const properties_size = try std.leb.readUleb128(u64, header_reader);
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

test {
    _ = @import("xz/test.zig");
}
