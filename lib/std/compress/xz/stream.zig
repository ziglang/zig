const std = @import("std");
const block = @import("block.zig");
const check = @import("check.zig");
const multibyte = @import("multibyte.zig");
const Allocator = std.mem.Allocator;
const Crc32 = std.hash.Crc32;

test {
    _ = @import("stream_test.zig");
}

const Flags = packed struct(u16) {
    reserved1: u8,
    check_kind: check.Kind,
    reserved2: u4,
};

pub fn stream(allocator: Allocator, reader: anytype) !Stream(@TypeOf(reader)) {
    return Stream(@TypeOf(reader)).init(allocator, reader);
}

pub fn Stream(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error || block.Decoder(ReaderType).Error;
        pub const Reader = std.io.Reader(*Self, Error, read);

        allocator: Allocator,
        block_decoder: block.Decoder(ReaderType),
        in_reader: ReaderType,

        fn init(allocator: Allocator, source: ReaderType) !Self {
            const Header = extern struct {
                magic: [6]u8,
                flags: Flags,
                crc32: u32,
            };

            const header = try source.readStruct(Header);

            if (!std.mem.eql(u8, &header.magic, &.{ 0xFD, '7', 'z', 'X', 'Z', 0x00 }))
                return error.BadHeader;

            if (header.flags.reserved1 != 0 or header.flags.reserved2 != 0)
                return error.BadHeader;

            const hash = Crc32.hash(std.mem.asBytes(&header.flags));
            if (hash != header.crc32)
                return error.WrongChecksum;

            return Self{
                .allocator = allocator,
                .block_decoder = try block.decoder(allocator, source, header.flags.check_kind),
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

                const record_count = try multibyte.readInt(counting_reader);
                if (record_count != self.block_decoder.block_count)
                    return error.CorruptInput;

                var i: usize = 0;
                while (i < record_count) : (i += 1) {
                    // TODO: validate records
                    _ = try multibyte.readInt(counting_reader);
                    _ = try multibyte.readInt(counting_reader);
                }

                while (counter.bytes_read % 4 != 0) {
                    if (try counting_reader.readByte() != 0)
                        return error.CorruptInput;
                }

                const hash_a = hasher.hasher.final();
                const hash_b = try counting_reader.readIntLittle(u32);
                if (hash_a != hash_b)
                    return error.WrongChecksum;

                break :blk counter.bytes_read;
            };

            const Footer = extern struct {
                crc32: u32,
                backward_size: u32,
                flags: Flags,
                magic: [2]u8,
            };

            const footer = try self.in_reader.readStruct(Footer);
            const backward_size = (footer.backward_size + 1) * 4;
            if (backward_size != index_size)
                return error.CorruptInput;

            if (footer.flags.reserved1 != 0 or footer.flags.reserved2 != 0)
                return error.CorruptInput;

            var hasher = Crc32.init();
            hasher.update(std.mem.asBytes(&footer.backward_size));
            hasher.update(std.mem.asBytes(&footer.flags));
            const hash = hasher.final();
            if (hash != footer.crc32)
                return error.WrongChecksum;

            if (!std.mem.eql(u8, &footer.magic, &.{ 'Y', 'Z' }))
                return error.CorruptInput;

            return 0;
        }
    };
}
