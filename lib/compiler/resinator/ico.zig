//! https://devblogs.microsoft.com/oldnewthing/20120720-00/?p=7083
//! https://learn.microsoft.com/en-us/previous-versions/ms997538(v=msdn.10)
//! https://learn.microsoft.com/en-us/windows/win32/menurc/newheader
//! https://learn.microsoft.com/en-us/windows/win32/menurc/resdir
//! https://learn.microsoft.com/en-us/windows/win32/menurc/localheader

const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

pub const ReadError = std.mem.Allocator.Error || error{ InvalidHeader, InvalidImageType, ImpossibleDataSize, UnexpectedEOF, ReadError };

pub fn read(allocator: std.mem.Allocator, reader: anytype, max_size: u64) ReadError!IconDir {
    // Some Reader implementations have an empty ReadError error set which would
    // cause 'unreachable else' if we tried to use an else in the switch, so we
    // need to detect this case and not try to translate to ReadError
    const empty_reader_errorset = @typeInfo(@TypeOf(reader).Error).error_set == null or @typeInfo(@TypeOf(reader).Error).error_set.?.len == 0;
    if (empty_reader_errorset) {
        return readAnyError(allocator, reader, max_size) catch |err| switch (err) {
            error.EndOfStream => error.UnexpectedEOF,
            else => |e| return e,
        };
    } else {
        return readAnyError(allocator, reader, max_size) catch |err| switch (err) {
            error.OutOfMemory,
            error.InvalidHeader,
            error.InvalidImageType,
            error.ImpossibleDataSize,
            => |e| return e,
            error.EndOfStream => error.UnexpectedEOF,
            // The remaining errors are dependent on the `reader`, so
            // we just translate them all to generic ReadError
            else => error.ReadError,
        };
    }
}

// TODO: This seems like a somewhat strange pattern, could be a better way
//       to do this. Maybe it makes more sense to handle the translation
//       at the call site instead of having a helper function here.
pub fn readAnyError(allocator: std.mem.Allocator, reader: anytype, max_size: u64) !IconDir {
    const reserved = try reader.readInt(u16, .little);
    if (reserved != 0) {
        return error.InvalidHeader;
    }

    const image_type = reader.readEnum(ImageType, .little) catch |err| switch (err) {
        error.InvalidValue => return error.InvalidImageType,
        else => |e| return e,
    };

    const num_images = try reader.readInt(u16, .little);

    // To avoid over-allocation in the case of a file that says it has way more
    // entries than it actually does, we use an ArrayList with a conservatively
    // limited initial capacity instead of allocating the entire slice at once.
    const initial_capacity = @min(num_images, 8);
    var entries = try std.ArrayList(Entry).initCapacity(allocator, initial_capacity);
    errdefer entries.deinit();

    var i: usize = 0;
    while (i < num_images) : (i += 1) {
        var entry: Entry = undefined;
        entry.width = try reader.readByte();
        entry.height = try reader.readByte();
        entry.num_colors = try reader.readByte();
        entry.reserved = try reader.readByte();
        switch (image_type) {
            .icon => {
                entry.type_specific_data = .{ .icon = .{
                    .color_planes = try reader.readInt(u16, .little),
                    .bits_per_pixel = try reader.readInt(u16, .little),
                } };
            },
            .cursor => {
                entry.type_specific_data = .{ .cursor = .{
                    .hotspot_x = try reader.readInt(u16, .little),
                    .hotspot_y = try reader.readInt(u16, .little),
                } };
            },
        }
        entry.data_size_in_bytes = try reader.readInt(u32, .little);
        entry.data_offset_from_start_of_file = try reader.readInt(u32, .little);
        // Validate that the offset/data size is feasible
        if (@as(u64, entry.data_offset_from_start_of_file) + entry.data_size_in_bytes > max_size) {
            return error.ImpossibleDataSize;
        }
        // and that the data size is large enough for at least the header of an image
        // Note: This avoids needing to deal with a miscompilation from the Win32 RC
        //       compiler when the data size of an image is specified as zero but there
        //       is data to-be-read at the offset. The Win32 RC compiler will output
        //       an ICON/CURSOR resource with a bogus size in its header but with no actual
        //       data bytes in it, leading to an invalid .res. Similarly, if, for example,
        //       there is valid PNG data at the image's offset, but the size is specified
        //       as fewer bytes than the PNG header, then the Win32 RC compiler will still
        //       treat it as a PNG (e.g. unconditionally set num_planes to 1) but the data
        //       of the resource will only be 1 byte so treating it as a PNG doesn't make
        //       sense (especially not when you have to read past the data size to determine
        //       that it's a PNG).
        if (entry.data_size_in_bytes < 16) {
            return error.ImpossibleDataSize;
        }
        try entries.append(entry);
    }

    return .{
        .image_type = image_type,
        .entries = try entries.toOwnedSlice(),
        .allocator = allocator,
    };
}

pub const ImageType = enum(u16) {
    icon = 1,
    cursor = 2,
};

pub const IconDir = struct {
    image_type: ImageType,
    /// Note: entries.len will always fit into a u16, since the field containing the
    /// number of images in an ico file is a u16.
    entries: []Entry,
    allocator: std.mem.Allocator,

    pub fn deinit(self: IconDir) void {
        self.allocator.free(self.entries);
    }

    pub const res_header_byte_len = 6;

    pub fn getResDataSize(self: IconDir) u32 {
        // maxInt(u16) * Entry.res_byte_len = 917,490 which is well within the u32 range.
        // Note: self.entries.len is limited to maxInt(u16)
        return @intCast(IconDir.res_header_byte_len + self.entries.len * Entry.res_byte_len);
    }

    pub fn writeResData(self: IconDir, writer: anytype, first_image_id: u16) !void {
        try writer.writeInt(u16, 0, .little);
        try writer.writeInt(u16, @intFromEnum(self.image_type), .little);
        // We know that entries.len must fit into a u16
        try writer.writeInt(u16, @as(u16, @intCast(self.entries.len)), .little);

        var image_id = first_image_id;
        for (self.entries) |entry| {
            try entry.writeResData(writer, image_id);
            image_id += 1;
        }
    }
};

pub const Entry = struct {
    // Icons are limited to u8 sizes, cursors can have u16,
    // so we store as u16 and truncate when needed.
    width: u16,
    height: u16,
    num_colors: u8,
    /// This should always be zero, but whatever value it is gets
    /// carried over so we need to store it
    reserved: u8,
    type_specific_data: union(ImageType) {
        icon: struct {
            color_planes: u16,
            bits_per_pixel: u16,
        },
        cursor: struct {
            hotspot_x: u16,
            hotspot_y: u16,
        },
    },
    data_size_in_bytes: u32,
    data_offset_from_start_of_file: u32,

    pub const res_byte_len = 14;

    pub fn writeResData(self: Entry, writer: anytype, id: u16) !void {
        switch (self.type_specific_data) {
            .icon => |icon_data| {
                try writer.writeInt(u8, @as(u8, @truncate(self.width)), .little);
                try writer.writeInt(u8, @as(u8, @truncate(self.height)), .little);
                try writer.writeInt(u8, self.num_colors, .little);
                try writer.writeInt(u8, self.reserved, .little);
                try writer.writeInt(u16, icon_data.color_planes, .little);
                try writer.writeInt(u16, icon_data.bits_per_pixel, .little);
                try writer.writeInt(u32, self.data_size_in_bytes, .little);
            },
            .cursor => |cursor_data| {
                try writer.writeInt(u16, self.width, .little);
                try writer.writeInt(u16, self.height, .little);
                try writer.writeInt(u16, cursor_data.hotspot_x, .little);
                try writer.writeInt(u16, cursor_data.hotspot_y, .little);
                try writer.writeInt(u32, self.data_size_in_bytes + 4, .little);
            },
        }
        try writer.writeInt(u16, id, .little);
    }
};

test "icon" {
    const data = "\x00\x00\x01\x00\x01\x00\x10\x10\x00\x00\x01\x00\x10\x00\x10\x00\x00\x00\x16\x00\x00\x00" ++ [_]u8{0} ** 16;
    var fbs = std.io.fixedBufferStream(data);
    const icon = try read(std.testing.allocator, fbs.reader(), data.len);
    defer icon.deinit();

    try std.testing.expectEqual(ImageType.icon, icon.image_type);
    try std.testing.expectEqual(@as(usize, 1), icon.entries.len);
}

test "icon too many images" {
    // Note that with verifying that all data sizes are within the file bounds and >= 16,
    // it's not possible to hit EOF when looking for more RESDIR structures, since they are
    // themselves 16 bytes long, so we'll always hit ImpossibleDataSize instead.
    const data = "\x00\x00\x01\x00\x02\x00\x10\x10\x00\x00\x01\x00\x10\x00\x10\x00\x00\x00\x16\x00\x00\x00" ++ [_]u8{0} ** 16;
    var fbs = std.io.fixedBufferStream(data);
    try std.testing.expectError(error.ImpossibleDataSize, read(std.testing.allocator, fbs.reader(), data.len));
}

test "icon data size past EOF" {
    const data = "\x00\x00\x01\x00\x01\x00\x10\x10\x00\x00\x01\x00\x10\x00\x10\x01\x00\x00\x16\x00\x00\x00" ++ [_]u8{0} ** 16;
    var fbs = std.io.fixedBufferStream(data);
    try std.testing.expectError(error.ImpossibleDataSize, read(std.testing.allocator, fbs.reader(), data.len));
}

test "icon data offset past EOF" {
    const data = "\x00\x00\x01\x00\x01\x00\x10\x10\x00\x00\x01\x00\x10\x00\x10\x00\x00\x00\x17\x00\x00\x00" ++ [_]u8{0} ** 16;
    var fbs = std.io.fixedBufferStream(data);
    try std.testing.expectError(error.ImpossibleDataSize, read(std.testing.allocator, fbs.reader(), data.len));
}

test "icon data size too small" {
    const data = "\x00\x00\x01\x00\x01\x00\x10\x10\x00\x00\x01\x00\x10\x00\x0F\x00\x00\x00\x16\x00\x00\x00";
    var fbs = std.io.fixedBufferStream(data);
    try std.testing.expectError(error.ImpossibleDataSize, read(std.testing.allocator, fbs.reader(), data.len));
}

pub const ImageFormat = enum(u2) {
    dib,
    png,
    riff,

    const riff_header = std.mem.readInt(u32, "RIFF", native_endian);
    const png_signature = std.mem.readInt(u64, "\x89PNG\r\n\x1a\n", native_endian);
    const ihdr_code = std.mem.readInt(u32, "IHDR", native_endian);
    const acon_form_type = std.mem.readInt(u32, "ACON", native_endian);

    pub fn detect(header_bytes: *const [16]u8) ImageFormat {
        if (std.mem.readInt(u32, header_bytes[0..4], native_endian) == riff_header) return .riff;
        if (std.mem.readInt(u64, header_bytes[0..8], native_endian) == png_signature) return .png;
        return .dib;
    }

    pub fn validate(format: ImageFormat, header_bytes: *const [16]u8) bool {
        return switch (format) {
            .png => std.mem.readInt(u32, header_bytes[12..16], native_endian) == ihdr_code,
            .riff => std.mem.readInt(u32, header_bytes[8..12], native_endian) == acon_form_type,
            .dib => true,
        };
    }
};

/// Contains only the fields of BITMAPINFOHEADER (WinGDI.h) that are both:
/// - relevant to what we need, and
/// - are shared between all versions of BITMAPINFOHEADER (V4, V5).
pub const BitmapHeader = extern struct {
    bcSize: u32,
    bcWidth: i32,
    bcHeight: i32,
    bcPlanes: u16,
    bcBitCount: u16,

    pub fn version(self: *const BitmapHeader) Version {
        return Version.get(self.bcSize);
    }

    /// https://en.wikipedia.org/wiki/BMP_file_format#DIB_header_(bitmap_information_header)
    pub const Version = enum(u3) {
        unknown,
        @"win2.0", // Windows 2.0 or later
        @"nt3.1", // Windows NT, 3.1x or later
        @"nt4.0", // Windows NT 4.0, 95 or later
        @"nt5.0", // Windows NT 5.0, 98 or later

        pub fn get(header_size: u32) Version {
            return switch (header_size) {
                len(.@"win2.0") => .@"win2.0",
                len(.@"nt3.1") => .@"nt3.1",
                len(.@"nt4.0") => .@"nt4.0",
                len(.@"nt5.0") => .@"nt5.0",
                else => .unknown,
            };
        }

        pub fn len(comptime v: Version) comptime_int {
            return switch (v) {
                .@"win2.0" => 12,
                .@"nt3.1" => 40,
                .@"nt4.0" => 108,
                .@"nt5.0" => 124,
                .unknown => unreachable,
            };
        }

        pub fn nameForErrorDisplay(v: Version) []const u8 {
            return switch (v) {
                .unknown => "unknown",
                .@"win2.0" => "Windows 2.0 (BITMAPCOREHEADER)",
                .@"nt3.1" => "Windows NT, 3.1x (BITMAPINFOHEADER)",
                .@"nt4.0" => "Windows NT 4.0, 95 (BITMAPV4HEADER)",
                .@"nt5.0" => "Windows NT 5.0, 98 (BITMAPV5HEADER)",
            };
        }
    };
};
