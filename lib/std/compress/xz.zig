const std = @import("std");
const block = @import("xz/block.zig");
const Allocator = std.mem.Allocator;
const Crc32 = std.hash.Crc32;

pub const Check = enum(u4) {
    none = 0x00,
    crc32 = 0x01,
    crc64 = 0x04,
    sha256 = 0x0A,
    _,
};

fn readStreamFlags(reader: anytype, check: *Check) !void {
    var bit_reader = std.io.bitReader(.little, reader);

    const reserved1 = try bit_reader.readBitsNoEof(u8, 8);
    if (reserved1 != 0)
        return error.CorruptInput;

    check.* = @as(Check, @enumFromInt(try bit_reader.readBitsNoEof(u4, 4)));

    const reserved2 = try bit_reader.readBitsNoEof(u4, 4);
    if (reserved2 != 0)
        return error.CorruptInput;
}

pub fn decompress(allocator: Allocator, reader: anytype) !Decompress(@TypeOf(reader)) {
    return Decompress(@TypeOf(reader)).init(allocator, reader);
}

pub fn Decompress(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error || block.Decoder(ReaderType).Error;
        pub const Reader = std.io.Reader(*Self, Error, read);

        allocator: Allocator,
        block_decoder: block.Decoder(ReaderType),
        in_reader: ReaderType,

        fn init(allocator: Allocator, source: ReaderType) !Self {
            const magic = try source.readBytesNoEof(6);
            if (!std.mem.eql(u8, &magic, &.{ 0xFD, '7', 'z', 'X', 'Z', 0x00 }))
                return error.BadHeader;

            var check: Check = undefined;
            const hash_a = blk: {
                var hasher = std.compress.hashedReader(source, Crc32.init());
                try readStreamFlags(hasher.reader(), &check);
                break :blk hasher.hasher.final();
            };

            const hash_b = try source.readInt(u32, .little);
            if (hash_a != hash_b)
                return error.WrongChecksum;

            return Self{
                .allocator = allocator,
                .block_decoder = try block.decoder(allocator, source, check),
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
                var hasher = std.compress.hashedReader(self.in_reader, Crc32.init());
                hasher.hasher.update(&[1]u8{0x00});

                var counter = std.io.countingReader(hasher.reader());
                counter.bytes_read += 1;

                const counting_reader = counter.reader();

                const record_count = try std.leb.readULEB128(u64, counting_reader);
                if (record_count != self.block_decoder.block_count)
                    return error.CorruptInput;

                var i: usize = 0;
                while (i < record_count) : (i += 1) {
                    // TODO: validate records
                    _ = try std.leb.readULEB128(u64, counting_reader);
                    _ = try std.leb.readULEB128(u64, counting_reader);
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
                var hasher = std.compress.hashedReader(self.in_reader, Crc32.init());
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

test {
    _ = @import("xz/test.zig");
}
