const std = @import("../std.zig");

/// When decompressing, the output buffer is used as the history window, so
/// less than this may result in failure to decompress streams that were
/// compressed with a larger window.
pub const max_window_len = history_len * 2;

pub const history_len = 32768;

/// Deflate is a lossless data compression file format that uses a combination
/// of LZ77 and Huffman coding.
pub const Compress = @import("flate/Compress.zig");

/// Inflate is the decoding process that consumes a Deflate bitstream and
/// produces the original full-size data.
pub const Decompress = @import("flate/Decompress.zig");

/// Compression without Lempel-Ziv match searching. Faster compression, less
/// memory requirements but bigger compressed sizes.
pub const HuffmanEncoder = @import("flate/HuffmanEncoder.zig");

/// Container of the deflate bit stream body. Container adds header before
/// deflate bit stream and footer after. It can bi gzip, zlib or raw (no header,
/// no footer, raw bit stream).
///
/// Zlib format is defined in rfc 1950. Header has 2 bytes and footer 4 bytes
/// addler 32 checksum.
///
/// Gzip format is defined in rfc 1952. Header has 10+ bytes and footer 4 bytes
/// crc32 checksum and 4 bytes of uncompressed data length.
///
/// rfc 1950: https://datatracker.ietf.org/doc/html/rfc1950#page-4
/// rfc 1952: https://datatracker.ietf.org/doc/html/rfc1952#page-5
pub const Container = enum {
    raw, // no header or footer
    gzip, // gzip header and footer
    zlib, // zlib header and footer

    pub fn size(w: Container) usize {
        return headerSize(w) + footerSize(w);
    }

    pub fn headerSize(w: Container) usize {
        return header(w).len;
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

    pub fn header(container: Container) []const u8 {
        return switch (container) {
            // GZIP 10 byte header (https://datatracker.ietf.org/doc/html/rfc1952#page-5):
            //  - ID1 (IDentification 1), always 0x1f
            //  - ID2 (IDentification 2), always 0x8b
            //  - CM (Compression Method), always 8 = deflate
            //  - FLG (Flags), all set to 0
            //  - 4 bytes, MTIME (Modification time), not used, all set to zero
            //  - XFL (eXtra FLags), all set to zero
            //  - OS (Operating System), 03 = Unix
            .gzip => &[_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 },
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
            .zlib => &[_]u8{ 0x78, 0b10_0_11100 },
            .raw => &.{},
        };
    }

    pub const Hasher = union(Container) {
        raw: void,
        gzip: struct {
            crc: std.hash.Crc32 = .init(),
            count: u32 = 0,
        },
        zlib: std.hash.Adler32,

        pub fn init(containter: Container) Hasher {
            return switch (containter) {
                .gzip => .{ .gzip = .{} },
                .zlib => .{ .zlib = .{} },
                .raw => .raw,
            };
        }

        pub fn container(h: Hasher) Container {
            return h;
        }

        pub fn update(h: *Hasher, buf: []const u8) void {
            switch (h.*) {
                .raw => {},
                .gzip => |*gzip| {
                    gzip.update(buf);
                    gzip.count +%= buf.len;
                },
                .zlib => |*zlib| {
                    zlib.update(buf);
                },
                inline .gzip, .zlib => |*x| x.update(buf),
            }
        }

        pub fn writeFooter(hasher: *Hasher, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            var bits: [4]u8 = undefined;
            switch (hasher.*) {
                .gzip => |*gzip| {
                    // GZIP 8 bytes footer
                    //  - 4 bytes, CRC32 (CRC-32)
                    //  - 4 bytes, ISIZE (Input SIZE) - size of the original (uncompressed) input data modulo 2^32
                    std.mem.writeInt(u32, &bits, gzip.final(), .little);
                    try writer.writeAll(&bits);

                    std.mem.writeInt(u32, &bits, gzip.bytes_read, .little);
                    try writer.writeAll(&bits);
                },
                .zlib => |*zlib| {
                    // ZLIB (RFC 1950) is big-endian, unlike GZIP (RFC 1952).
                    // 4 bytes of ADLER32 (Adler-32 checksum)
                    // Checksum value of the uncompressed data (excluding any
                    // dictionary data) computed according to Adler-32
                    // algorithm.
                    std.mem.writeInt(u32, &bits, zlib.final, .big);
                    try writer.writeAll(&bits);
                },
                .raw => {},
            }
        }
    };

    pub const Metadata = union(Container) {
        raw: void,
        gzip: struct {
            crc: u32 = 0,
            count: u32 = 0,
        },
        zlib: struct {
            adler: u32 = 0,
        },

        pub fn init(containter: Container) Metadata {
            return switch (containter) {
                .gzip => .{ .gzip = .{} },
                .zlib => .{ .zlib = .{} },
                .raw => .raw,
            };
        }

        pub fn container(m: Metadata) Container {
            return m;
        }
    };
};

test {
    _ = HuffmanEncoder;
    _ = Compress;
    _ = Decompress;
}
