//! Container of the deflate bit stream body. Container adds header before
//! deflate bit stream and footer after. It can bi gzip, zlib or raw (no header,
//! no footer, raw bit stream).
//!
//! Zlib format is defined in rfc 1950. Header has 2 bytes and footer 4 bytes
//! addler 32 checksum.
//!
//! Gzip format is defined in rfc 1952. Header has 10+ bytes and footer 4 bytes
//! crc32 checksum and 4 bytes of uncompressed data length.
//!
//!
//! rfc 1950: https://datatracker.ietf.org/doc/html/rfc1950#page-4
//! rfc 1952: https://datatracker.ietf.org/doc/html/rfc1952#page-5
//!

const std = @import("std");

pub const Container = enum {
    raw, // no header or footer
    gzip, // gzip header and footer
    zlib, // zlib header and footer

    pub fn size(w: Container) usize {
        return headerSize(w) + footerSize(w);
    }

    pub fn headerSize(w: Container) usize {
        return switch (w) {
            .gzip => 10,
            .zlib => 2,
            .raw => 0,
        };
    }

    pub fn footerSize(w: Container) usize {
        return switch (w) {
            .gzip => 8,
            .zlib => 4,
            .raw => 0,
        };
    }

    pub const list = [_]Container{ .raw, .gzip, .zlib };

    pub const Error = error{
        BadGzipHeader,
        BadZlibHeader,
        WrongGzipChecksum,
        WrongGzipSize,
        WrongZlibChecksum,
    };

    pub fn writeHeader(comptime wrap: Container, writer: anytype) !void {
        switch (wrap) {
            .gzip => {
                // GZIP 10 byte header (https://datatracker.ietf.org/doc/html/rfc1952#page-5):
                //  - ID1 (IDentification 1), always 0x1f
                //  - ID2 (IDentification 2), always 0x8b
                //  - CM (Compression Method), always 8 = deflate
                //  - FLG (Flags), all set to 0
                //  - 4 bytes, MTIME (Modification time), not used, all set to zero
                //  - XFL (eXtra FLags), all set to zero
                //  - OS (Operating System), 03 = Unix
                const gzipHeader = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 };
                try writer.writeAll(&gzipHeader);
            },
            .zlib => {
                // ZLIB has a two-byte header (https://datatracker.ietf.org/doc/html/rfc1950#page-4):
                // 1st byte:
                //  - First four bits is the CINFO (compression info), which is 7 for the default deflate window size.
                //  - The next four bits is the CM (compression method), which is 8 for deflate.
                // 2nd byte:
                //  - Two bits is the FLEVEL (compression level). Values are: 0=fastest, 1=fast, 2=default, 3=best.
                //  - The next bit, FDICT, is set if a dictionary is given.
                //  - The final five FCHECK bits form a mod-31 checksum.
                //
                // CINFO = 7, CM = 8, FLEVEL = 0b10, FDICT = 0, FCHECK = 0b11100
                const zlibHeader = [_]u8{ 0x78, 0b10_0_11100 };
                try writer.writeAll(&zlibHeader);
            },
            .raw => {},
        }
    }

    pub fn writeFooter(comptime wrap: Container, hasher: *Hasher(wrap), writer: anytype) !void {
        var bits: [4]u8 = undefined;
        switch (wrap) {
            .gzip => {
                // GZIP 8 bytes footer
                //  - 4 bytes, CRC32 (CRC-32)
                //  - 4 bytes, ISIZE (Input SIZE) - size of the original (uncompressed) input data modulo 2^32
                std.mem.writeInt(u32, &bits, hasher.chksum(), .little);
                try writer.writeAll(&bits);

                std.mem.writeInt(u32, &bits, hasher.bytesRead(), .little);
                try writer.writeAll(&bits);
            },
            .zlib => {
                // ZLIB (RFC 1950) is big-endian, unlike GZIP (RFC 1952).
                // 4 bytes of ADLER32 (Adler-32 checksum)
                // Checksum value of the uncompressed data (excluding any
                // dictionary data) computed according to Adler-32
                // algorithm.
                std.mem.writeInt(u32, &bits, hasher.chksum(), .big);
                try writer.writeAll(&bits);
            },
            .raw => {},
        }
    }

    pub fn parseHeader(comptime wrap: Container, reader: anytype) !void {
        switch (wrap) {
            .gzip => try parseGzipHeader(reader),
            .zlib => try parseZlibHeader(reader),
            .raw => {},
        }
    }

    fn parseGzipHeader(reader: anytype) !void {
        const magic1 = try reader.read(u8);
        const magic2 = try reader.read(u8);
        const method = try reader.read(u8);
        const flags = try reader.read(u8);
        try reader.skipBytes(6); // mtime(4), xflags, os
        if (magic1 != 0x1f or magic2 != 0x8b or method != 0x08)
            return error.BadGzipHeader;
        // Flags description: https://www.rfc-editor.org/rfc/rfc1952.html#page-5
        if (flags != 0) {
            if (flags & 0b0000_0100 != 0) { // FEXTRA
                const extra_len = try reader.read(u16);
                try reader.skipBytes(extra_len);
            }
            if (flags & 0b0000_1000 != 0) { // FNAME
                try reader.skipStringZ();
            }
            if (flags & 0b0001_0000 != 0) { // FCOMMENT
                try reader.skipStringZ();
            }
            if (flags & 0b0000_0010 != 0) { // FHCRC
                try reader.skipBytes(2);
            }
        }
    }

    fn parseZlibHeader(reader: anytype) !void {
        const cm = try reader.read(u4);
        const cinfo = try reader.read(u4);
        _ = try reader.read(u8);
        if (cm != 8 or cinfo > 7) {
            return error.BadZlibHeader;
        }
    }

    pub fn parseFooter(comptime wrap: Container, hasher: *Hasher(wrap), reader: anytype) !void {
        switch (wrap) {
            .gzip => {
                try reader.fill(0);
                if (try reader.read(u32) != hasher.chksum()) return error.WrongGzipChecksum;
                if (try reader.read(u32) != hasher.bytesRead()) return error.WrongGzipSize;
            },
            .zlib => {
                const chksum: u32 = @byteSwap(hasher.chksum());
                if (try reader.read(u32) != chksum) return error.WrongZlibChecksum;
            },
            .raw => {},
        }
    }

    pub fn Hasher(comptime wrap: Container) type {
        const HasherType = switch (wrap) {
            .gzip => std.hash.Crc32,
            .zlib => std.hash.Adler32,
            .raw => struct {
                pub fn init() @This() {
                    return .{};
                }
            },
        };

        return struct {
            hasher: HasherType = HasherType.init(),
            bytes: usize = 0,

            const Self = @This();

            pub fn update(self: *Self, buf: []const u8) void {
                switch (wrap) {
                    .raw => {},
                    else => {
                        self.hasher.update(buf);
                        self.bytes += buf.len;
                    },
                }
            }

            pub fn chksum(self: *Self) u32 {
                switch (wrap) {
                    .raw => return 0,
                    else => return self.hasher.final(),
                }
            }

            pub fn bytesRead(self: *Self) u32 {
                return @truncate(self.bytes);
            }
        };
    }
};
