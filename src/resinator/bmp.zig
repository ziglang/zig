//! https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
//! https://learn.microsoft.com/en-us/previous-versions//dd183376(v=vs.85)
//! https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfo
//! https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapcoreheader
//! https://archive.org/details/mac_Graphics_File_Formats_Second_Edition_1996/page/n607/mode/2up
//! https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapv5header
//!
//! Notes:
//! - The Microsoft documentation is incredibly unclear about the color table when the
//!   bit depth is >= 16.
//!   + For bit depth 24 it says "the bmiColors member of BITMAPINFO is NULL" but also
//!     says "the bmiColors color table is used for optimizing colors used on palette-based
//!     devices, and must contain the number of entries specified by the bV5ClrUsed member"
//!   + For bit depth 16 and 32, it seems to imply that if the compression is BI_BITFIELDS
//!     or BI_ALPHABITFIELDS, then the color table *only* consists of the bit masks, but
//!     doesn't really say this outright and the Wikipedia article seems to disagree
//!   For the purposes of this implementation, color tables can always be present for any
//!   bit depth and compression, and the color table follows the header + any optional
//!   bit mask fields dictated by the specified compression.

const std = @import("std");
const BitmapHeader = @import("ico.zig").BitmapHeader;
const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

pub const windows_format_id = std.mem.readInt(u16, "BM", native_endian);
pub const file_header_len = 14;

pub const ReadError = error{
    UnexpectedEOF,
    InvalidFileHeader,
    ImpossiblePixelDataOffset,
    UnknownBitmapVersion,
    InvalidBitsPerPixel,
    TooManyColorsInPalette,
    MissingBitfieldMasks,
};

pub const BitmapInfo = struct {
    dib_header_size: u32,
    /// Contains the interpreted number of colors in the palette (e.g.
    /// if the field's value is zero and the bit depth is <= 8, this
    /// will contain the maximum number of colors for the bit depth
    /// rather than the field's value directly).
    colors_in_palette: u32,
    bytes_per_color_palette_element: u8,
    pixel_data_offset: u32,
    compression: Compression,

    pub fn getExpectedPaletteByteLen(self: *const BitmapInfo) u64 {
        return @as(u64, self.colors_in_palette) * self.bytes_per_color_palette_element;
    }

    pub fn getActualPaletteByteLen(self: *const BitmapInfo) u64 {
        return self.getByteLenBetweenHeadersAndPixels() - self.getBitmasksByteLen();
    }

    pub fn getByteLenBetweenHeadersAndPixels(self: *const BitmapInfo) u64 {
        return @as(u64, self.pixel_data_offset) - self.dib_header_size - file_header_len;
    }

    pub fn getBitmasksByteLen(self: *const BitmapInfo) u8 {
        return switch (self.compression) {
            .BI_BITFIELDS => 12,
            .BI_ALPHABITFIELDS => 16,
            else => 0,
        };
    }

    pub fn getMissingPaletteByteLen(self: *const BitmapInfo) u64 {
        if (self.getActualPaletteByteLen() >= self.getExpectedPaletteByteLen()) return 0;
        return self.getExpectedPaletteByteLen() - self.getActualPaletteByteLen();
    }

    /// Returns the full byte len of the DIB header + optional bitmasks + color palette
    pub fn getExpectedByteLenBeforePixelData(self: *const BitmapInfo) u64 {
        return @as(u64, self.dib_header_size) + self.getBitmasksByteLen() + self.getExpectedPaletteByteLen();
    }

    /// Returns the full expected byte len
    pub fn getExpectedByteLen(self: *const BitmapInfo, file_size: u64) u64 {
        return self.getExpectedByteLenBeforePixelData() + self.getPixelDataLen(file_size);
    }

    pub fn getPixelDataLen(self: *const BitmapInfo, file_size: u64) u64 {
        return file_size - self.pixel_data_offset;
    }
};

pub fn read(reader: anytype, max_size: u64) ReadError!BitmapInfo {
    var bitmap_info: BitmapInfo = undefined;
    const file_header = reader.readBytesNoEof(file_header_len) catch return error.UnexpectedEOF;

    const id = std.mem.readInt(u16, file_header[0..2], native_endian);
    if (id != windows_format_id) return error.InvalidFileHeader;

    bitmap_info.pixel_data_offset = std.mem.readInt(u32, file_header[10..14], .little);
    if (bitmap_info.pixel_data_offset > max_size) return error.ImpossiblePixelDataOffset;

    bitmap_info.dib_header_size = reader.readInt(u32, .little) catch return error.UnexpectedEOF;
    if (bitmap_info.pixel_data_offset < file_header_len + bitmap_info.dib_header_size) return error.ImpossiblePixelDataOffset;
    const dib_version = BitmapHeader.Version.get(bitmap_info.dib_header_size);
    switch (dib_version) {
        .@"nt3.1", .@"nt4.0", .@"nt5.0" => {
            var dib_header_buf: [@sizeOf(BITMAPINFOHEADER)]u8 align(@alignOf(BITMAPINFOHEADER)) = undefined;
            std.mem.writeInt(u32, dib_header_buf[0..4], bitmap_info.dib_header_size, .little);
            reader.readNoEof(dib_header_buf[4..]) catch return error.UnexpectedEOF;
            var dib_header: *BITMAPINFOHEADER = @ptrCast(&dib_header_buf);
            structFieldsLittleToNative(BITMAPINFOHEADER, dib_header);

            bitmap_info.colors_in_palette = try dib_header.numColorsInTable();
            bitmap_info.bytes_per_color_palette_element = 4;
            bitmap_info.compression = @enumFromInt(dib_header.biCompression);

            if (bitmap_info.getByteLenBetweenHeadersAndPixels() < bitmap_info.getBitmasksByteLen()) {
                return error.MissingBitfieldMasks;
            }
        },
        .@"win2.0" => {
            var dib_header_buf: [@sizeOf(BITMAPCOREHEADER)]u8 align(@alignOf(BITMAPCOREHEADER)) = undefined;
            std.mem.writeInt(u32, dib_header_buf[0..4], bitmap_info.dib_header_size, .little);
            reader.readNoEof(dib_header_buf[4..]) catch return error.UnexpectedEOF;
            const dib_header: *BITMAPCOREHEADER = @ptrCast(&dib_header_buf);
            structFieldsLittleToNative(BITMAPCOREHEADER, dib_header);

            // > The size of the color palette is calculated from the BitsPerPixel value.
            // > The color palette has 2, 16, 256, or 0 entries for a BitsPerPixel of
            // > 1, 4, 8, and 24, respectively.
            bitmap_info.colors_in_palette = switch (dib_header.bcBitCount) {
                inline 1, 4, 8 => |bit_count| 1 << bit_count,
                24 => 0,
                else => return error.InvalidBitsPerPixel,
            };
            bitmap_info.bytes_per_color_palette_element = 3;

            bitmap_info.compression = .BI_RGB;
        },
        .unknown => return error.UnknownBitmapVersion,
    }

    return bitmap_info;
}

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapcoreheader
pub const BITMAPCOREHEADER = extern struct {
    bcSize: u32,
    bcWidth: u16,
    bcHeight: u16,
    bcPlanes: u16,
    bcBitCount: u16,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
pub const BITMAPINFOHEADER = extern struct {
    bcSize: u32,
    biWidth: i32,
    biHeight: i32,
    biPlanes: u16,
    biBitCount: u16,
    biCompression: u32,
    biSizeImage: u32,
    biXPelsPerMeter: i32,
    biYPelsPerMeter: i32,
    biClrUsed: u32,
    biClrImportant: u32,

    /// Returns error.TooManyColorsInPalette if the number of colors specified
    /// exceeds the number of possible colors referenced in the pixel data (i.e.
    /// if 1 bit is used per pixel, then the color table can't have more than 2 colors
    /// since any more couldn't possibly be indexed in the pixel data)
    ///
    /// Returns error.InvalidBitsPerPixel if the bit depth is not 1, 4, 8, 16, 24, or 32.
    pub fn numColorsInTable(self: BITMAPINFOHEADER) !u32 {
        switch (self.biBitCount) {
            inline 1, 4, 8 => |bit_count| switch (self.biClrUsed) {
                // > If biClrUsed is zero, the array contains the maximum number of
                // > colors for the given bitdepth; that is, 2^biBitCount colors
                0 => return 1 << bit_count,
                // > If biClrUsed is nonzero and the biBitCount member is less than 16,
                // > the biClrUsed member specifies the actual number of colors the
                // > graphics engine or device driver accesses.
                else => {
                    const max_colors = 1 << bit_count;
                    if (self.biClrUsed > max_colors) {
                        return error.TooManyColorsInPalette;
                    }
                    return self.biClrUsed;
                },
            },
            // > If biBitCount is 16 or greater, the biClrUsed member specifies
            // > the size of the color table used to optimize performance of the
            // > system color palettes.
            //
            // Note: Bit depths >= 16 only use the color table 'for optimizing colors
            // used on palette-based devices', but it still makes sense to limit their
            // colors since the pixel data is still limited to this number of colors
            // (i.e. even though the color table is not indexed by the pixel data,
            // the color table having more colors than the pixel data can represent
            // would never make sense and indicates a malformed bitmap).
            inline 16, 24, 32 => |bit_count| {
                const max_colors = 1 << bit_count;
                if (self.biClrUsed > max_colors) {
                    return error.TooManyColorsInPalette;
                }
                return self.biClrUsed;
            },
            else => return error.InvalidBitsPerPixel,
        }
    }
};

pub const Compression = enum(u32) {
    BI_RGB = 0,
    BI_RLE8 = 1,
    BI_RLE4 = 2,
    BI_BITFIELDS = 3,
    BI_JPEG = 4,
    BI_PNG = 5,
    BI_ALPHABITFIELDS = 6,
    BI_CMYK = 11,
    BI_CMYKRLE8 = 12,
    BI_CMYKRLE4 = 13,
    _,
};

fn structFieldsLittleToNative(comptime T: type, x: *T) void {
    inline for (@typeInfo(T).Struct.fields) |field| {
        @field(x, field.name) = std.mem.littleToNative(field.type, @field(x, field.name));
    }
}

test "read" {
    var bmp_data = "BM<\x00\x00\x00\x00\x00\x00\x006\x00\x00\x00(\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x10\x00\x00\x00\x00\x00\x06\x00\x00\x00\x12\x0b\x00\x00\x12\x0b\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\x7f\x00\x00\x00\x00".*;
    var fbs = std.io.fixedBufferStream(&bmp_data);

    {
        const bitmap = try read(fbs.reader(), bmp_data.len);
        try std.testing.expectEqual(@as(u32, BitmapHeader.Version.@"nt3.1".len()), bitmap.dib_header_size);
    }

    {
        fbs.reset();
        bmp_data[file_header_len] = 11;
        try std.testing.expectError(error.UnknownBitmapVersion, read(fbs.reader(), bmp_data.len));

        // restore
        bmp_data[file_header_len] = BitmapHeader.Version.@"nt3.1".len();
    }

    {
        fbs.reset();
        bmp_data[0] = 'b';
        try std.testing.expectError(error.InvalidFileHeader, read(fbs.reader(), bmp_data.len));

        // restore
        bmp_data[0] = 'B';
    }

    {
        const cutoff_len = file_header_len + BitmapHeader.Version.@"nt3.1".len() - 1;
        var dib_cutoff_fbs = std.io.fixedBufferStream(bmp_data[0..cutoff_len]);
        try std.testing.expectError(error.UnexpectedEOF, read(dib_cutoff_fbs.reader(), bmp_data.len));
    }

    {
        const cutoff_len = file_header_len - 1;
        var bmp_cutoff_fbs = std.io.fixedBufferStream(bmp_data[0..cutoff_len]);
        try std.testing.expectError(error.UnexpectedEOF, read(bmp_cutoff_fbs.reader(), bmp_data.len));
    }
}
