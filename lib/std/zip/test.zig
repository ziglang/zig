const std = @import("std");
const testing = std.testing;
const zip = @import("../zip.zig");
const maxInt = std.math.maxInt;

pub const File = struct {
    name: []const u8,
    content: []const u8,
    compression: zip.CompressionMethod,
};

pub fn expectFiles(
    test_files: []const File,
    dir: std.fs.Dir,
    opt: struct {
        strip_prefix: ?[]const u8 = null,
    },
) !void {
    for (test_files) |test_file| {
        var normalized_sub_path_buf: [std.fs.max_path_bytes]u8 = undefined;

        const name = blk: {
            if (opt.strip_prefix) |strip_prefix| {
                try testing.expect(test_file.name.len >= strip_prefix.len);
                try testing.expectEqualStrings(strip_prefix, test_file.name[0..strip_prefix.len]);
                break :blk test_file.name[strip_prefix.len..];
            }
            break :blk test_file.name;
        };
        const normalized_sub_path = normalized_sub_path_buf[0..name.len];
        @memcpy(normalized_sub_path, name);
        std.mem.replaceScalar(u8, normalized_sub_path, '\\', '/');
        var file = try dir.openFile(normalized_sub_path, .{});
        defer file.close();
        var content_buf: [4096]u8 = undefined;
        const n = try file.reader().readAll(&content_buf);
        try testing.expectEqualStrings(test_file.content, content_buf[0..n]);
    }
}

// Used to store any data from writing a file to the zip archive that's needed
// when writing the corresponding central directory record.
pub const FileStore = struct {
    compression: zip.CompressionMethod,
    file_offset: u64,
    crc32: u32,
    compressed_size: u32,
    uncompressed_size: usize,
};

pub fn makeZip(
    buf: []u8,
    comptime files: []const File,
    options: WriteZipOptions,
) !std.io.FixedBufferStream([]u8) {
    var store: [files.len]FileStore = undefined;
    return try makeZipWithStore(buf, files, options, &store);
}

pub fn makeZipWithStore(
    buf: []u8,
    files: []const File,
    options: WriteZipOptions,
    store: []FileStore,
) !std.io.FixedBufferStream([]u8) {
    var fbs = std.io.fixedBufferStream(buf);
    try writeZip(fbs.writer(), files, store, options);
    return std.io.fixedBufferStream(buf[0..fbs.pos]);
}

pub const WriteZipOptions = struct {
    end: ?EndRecordOptions = null,
};
pub const EndRecordOptions = struct {
    zip64: ?Zip64Options = null,
    sig: ?[4]u8 = null,
    disk_number: ?u16 = null,
    central_directory_disk_number: ?u16 = null,
    record_count_disk: ?u16 = null,
    record_count_total: ?u16 = null,
    central_directory_size: ?u32 = null,
    central_directory_offset: ?u32 = null,
    comment_len: ?u16 = null,
    comment: ?[]const u8 = null,
};
pub const Zip64Options = struct {
    locator_sig: ?[4]u8 = null,
    locator_zip64_disk_count: ?u32 = null,
    locator_record_file_offset: ?u64 = null,
    locator_total_disk_count: ?u32 = null,
    //record_size: ?u64 = null,
    central_directory_size: ?u64 = null,
};

pub fn writeZip(
    writer: anytype,
    files: []const File,
    store: []FileStore,
    options: WriteZipOptions,
) !void {
    if (store.len < files.len) return error.FileStoreTooSmall;
    var zipper = initZipper(writer);
    for (files, 0..) |file, i| {
        store[i] = try zipper.writeFile(.{
            .name = file.name,
            .content = file.content,
            .compression = file.compression,
        });
    }
    for (files, 0..) |file, i| {
        try zipper.writeCentralRecord(store[i], .{
            .name = file.name,
        });
    }
    try zipper.writeEndRecord(if (options.end) |e| e else .{});
}

pub fn initZipper(writer: anytype) Zipper(@TypeOf(writer)) {
    return .{ .counting_writer = std.io.countingWriter(writer) };
}

/// Provides methods to format and write the contents of a zip archive
/// to the underlying Writer.
pub fn Zipper(comptime Writer: type) type {
    return struct {
        counting_writer: std.io.CountingWriter(Writer),
        central_count: u64 = 0,
        first_central_offset: ?u64 = null,
        last_central_limit: ?u64 = null,

        const Self = @This();

        pub fn writeFile(
            self: *Self,
            opt: struct {
                name: []const u8,
                content: []const u8,
                compression: zip.CompressionMethod,
            },
        ) !FileStore {
            const writer = self.counting_writer.writer();

            const file_offset: u64 = @intCast(self.counting_writer.bytes_written);
            const crc32 = std.hash.Crc32.hash(opt.content);

            {
                const hdr: zip.LocalFileHeader = .{
                    .signature = zip.local_file_header_sig,
                    .version_needed_to_extract = 10,
                    .flags = .{ .encrypted = false, ._ = 0 },
                    .compression_method = opt.compression,
                    .last_modification_time = 0,
                    .last_modification_date = 0,
                    .crc32 = crc32,
                    .compressed_size = 0,
                    .uncompressed_size = @intCast(opt.content.len),
                    .filename_len = @intCast(opt.name.len),
                    .extra_len = 0,
                };
                try writer.writeStructEndian(hdr, .little);
            }
            try writer.writeAll(opt.name);

            var compressed_size: u32 = undefined;
            switch (opt.compression) {
                .store => {
                    try writer.writeAll(opt.content);
                    compressed_size = @intCast(opt.content.len);
                },
                .deflate => {
                    const offset = self.counting_writer.bytes_written;
                    var fbs = std.io.fixedBufferStream(opt.content);
                    try std.compress.flate.deflate.compress(.raw, fbs.reader(), writer, .{});
                    std.debug.assert(fbs.pos == opt.content.len);
                    compressed_size = @intCast(self.counting_writer.bytes_written - offset);
                },
                else => unreachable,
            }
            return .{
                .compression = opt.compression,
                .file_offset = file_offset,
                .crc32 = crc32,
                .compressed_size = compressed_size,
                .uncompressed_size = opt.content.len,
            };
        }

        pub fn writeCentralRecord(
            self: *Self,
            store: FileStore,
            opt: struct {
                name: []const u8,
                version_needed_to_extract: u16 = 10,
            },
        ) !void {
            if (self.first_central_offset == null) {
                self.first_central_offset = self.counting_writer.bytes_written;
            }
            self.central_count += 1;

            const hdr: zip.CentralDirectoryFileHeader = .{
                .signature = zip.central_file_header_sig,
                .version_made_by = 0,
                .version_needed_to_extract = opt.version_needed_to_extract,
                .flags = .{ .encrypted = false, ._ = 0 },
                .compression_method = store.compression,
                .last_modification_time = 0,
                .last_modification_date = 0,
                .crc32 = store.crc32,
                .compressed_size = store.compressed_size,
                .uncompressed_size = @intCast(store.uncompressed_size),
                .filename_len = @intCast(opt.name.len),
                .extra_len = 0,
                .comment_len = 0,
                .disk_number = 0,
                .internal_file_attributes = 0,
                .external_file_attributes = 0,
                .local_file_header_offset = @intCast(store.file_offset),
            };
            try self.counting_writer.writer().writeStructEndian(hdr, .little);
            try self.counting_writer.writer().writeAll(opt.name);
            self.last_central_limit = self.counting_writer.bytes_written;
        }

        pub fn writeEndRecord(self: *Self, opt: EndRecordOptions) !void {
            const cd_offset = self.first_central_offset orelse 0;
            const cd_end = self.last_central_limit orelse 0;

            if (opt.zip64) |zip64| {
                const end64_off = cd_end;
                const fixed: zip.EndRecord64 = .{
                    .signature = zip.end_record64_sig,
                    .end_record_size = @sizeOf(zip.EndRecord64) - 12,
                    .version_made_by = 0,
                    .version_needed_to_extract = 45,
                    .disk_number = 0,
                    .central_directory_disk_number = 0,
                    .record_count_disk = @intCast(self.central_count),
                    .record_count_total = @intCast(self.central_count),
                    .central_directory_size = @intCast(cd_end - cd_offset),
                    .central_directory_offset = @intCast(cd_offset),
                };
                try self.counting_writer.writer().writeStructEndian(fixed, .little);
                const locator: zip.EndLocator64 = .{
                    .signature = if (zip64.locator_sig) |s| s else zip.end_locator64_sig,
                    .zip64_disk_count = if (zip64.locator_zip64_disk_count) |c| c else 0,
                    .record_file_offset = if (zip64.locator_record_file_offset) |o| o else @intCast(end64_off),
                    .total_disk_count = if (zip64.locator_total_disk_count) |c| c else 1,
                };
                try self.counting_writer.writer().writeStructEndian(locator, .little);
            }
            const hdr: zip.EndRecord = .{
                .signature = if (opt.sig) |s| s else zip.end_record_sig,
                .disk_number = if (opt.disk_number) |n| n else 0,
                .central_directory_disk_number = if (opt.central_directory_disk_number) |n| n else 0,
                .record_count_disk = if (opt.record_count_disk) |c| c else @intCast(self.central_count),
                .record_count_total = if (opt.record_count_total) |c| c else @intCast(self.central_count),
                .central_directory_size = if (opt.central_directory_size) |s| s else @intCast(cd_end - cd_offset),
                .central_directory_offset = if (opt.central_directory_offset) |o| o else @intCast(cd_offset),
                .comment_len = if (opt.comment_len) |l| l else (if (opt.comment) |c| @as(u16, @intCast(c.len)) else 0),
            };
            try self.counting_writer.writer().writeStructEndian(hdr, .little);
            if (opt.comment) |c|
                try self.counting_writer.writer().writeAll(c);
        }
    };
}
