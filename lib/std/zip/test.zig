const std = @import("std");
const testing = std.testing;
const zip = @import("../zip.zig");
const maxInt = std.math.maxInt;
const assert = std.debug.assert;

const File = struct {
    name: []const u8,
    content: []const u8,
    compression: zip.CompressionMethod,
};

fn expectFiles(
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
        var file_reader = file.reader();
        var file_br = file_reader.readable(&.{});
        var content_buf: [4096]u8 = undefined;
        const n = try file_br.readSliceShort(&content_buf);
        try testing.expectEqualStrings(test_file.content, content_buf[0..n]);
    }
}

// Used to store any data from writing a file to the zip archive that's needed
// when writing the corresponding central directory record.
const FileStore = struct {
    compression: zip.CompressionMethod,
    file_offset: u64,
    crc32: u32,
    compressed_size: u32,
    uncompressed_size: usize,
};

fn makeZip(file_writer: *std.fs.File.Writer, files: []const File, options: WriteZipOptions) !std.io.BufferedReader {
    const store = try std.testing.allocator.alloc(FileStore, files.len);
    defer std.testing.allocator.free(store);
    return makeZipWithStore(file_writer, files, options, store);
}

fn makeZipWithStore(
    file_writer: *std.fs.File.Writer,
    files: []const File,
    options: WriteZipOptions,
    store: []FileStore,
) !void {
    var buffer: [200]u8 = undefined;
    var bw = file_writer.writable(&buffer);
    try writeZip(&bw, files, store, options);
}

const WriteZipOptions = struct {
    end: ?EndRecordOptions = null,
    local_header: ?LocalHeaderOptions = null,
};
const LocalHeaderOptions = struct {
    zip64: ?LocalHeaderZip64Options = null,
    compressed_size: ?u32 = null,
    uncompressed_size: ?u32 = null,
    extra_len: ?u16 = null,
};
const LocalHeaderZip64Options = struct {
    data_size: ?u16 = null,
};
const EndRecordOptions = struct {
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
const Zip64Options = struct {
    locator_sig: ?[4]u8 = null,
    locator_zip64_disk_count: ?u32 = null,
    locator_record_file_offset: ?u64 = null,
    locator_total_disk_count: ?u32 = null,
    //record_size: ?u64 = null,
    central_directory_size: ?u64 = null,
};

fn writeZip(
    writer: *std.io.BufferedWriter,
    files: []const File,
    store: []FileStore,
    options: WriteZipOptions,
) !void {
    if (store.len < files.len) return error.FileStoreTooSmall;
    var zipper: Zipper = .init(writer);
    for (files, 0..) |file, i| {
        store[i] = try zipper.writeFile(.{
            .name = file.name,
            .content = file.content,
            .compression = file.compression,
            .write_options = options,
        });
    }
    for (files, 0..) |file, i| {
        try zipper.writeCentralRecord(store[i], .{
            .name = file.name,
        });
    }
    try zipper.writeEndRecord(if (options.end) |e| e else .{});
}

/// Provides methods to format and write the contents of a zip archive
/// to the underlying Writer.
const Zipper = struct {
    writer: *std.io.BufferedWriter,
    init_count: u64,
    central_count: u64 = 0,
    first_central_offset: ?u64 = null,
    last_central_limit: ?u64 = null,

    fn init(writer: *std.io.BufferedWriter) Zipper {
        return .{ .writer = writer, .init_count = writer.count };
    }

    fn writeFile(
        self: *Zipper,
        opt: struct {
            name: []const u8,
            content: []const u8,
            compression: zip.CompressionMethod,
            write_options: WriteZipOptions,
        },
    ) !FileStore {
        const writer = self.writer;

        const file_offset: u64 = writer.count - self.init_count;
        const crc32 = std.hash.Crc32.hash(opt.content);

        const header_options = opt.write_options.local_header;
        {
            var compressed_size: u32 = 0;
            var uncompressed_size: u32 = 0;
            var extra_len: u16 = 0;
            if (header_options) |hdr_options| {
                compressed_size = if (hdr_options.compressed_size) |size| size else 0;
                uncompressed_size = if (hdr_options.uncompressed_size) |size| size else @intCast(opt.content.len);
                extra_len = if (hdr_options.extra_len) |len| len else 0;
            }
            const hdr: zip.LocalFileHeader = .{
                .signature = zip.local_file_header_sig,
                .version_needed_to_extract = 10,
                .flags = .{ .encrypted = false, ._ = 0 },
                .compression_method = opt.compression,
                .last_modification_time = 0,
                .last_modification_date = 0,
                .crc32 = crc32,
                .compressed_size = compressed_size,
                .uncompressed_size = uncompressed_size,
                .filename_len = @intCast(opt.name.len),
                .extra_len = extra_len,
            };
            try writer.writeStructEndian(hdr, .little);
        }
        try writer.writeAll(opt.name);

        if (header_options) |hdr| {
            if (hdr.zip64) |options| {
                try writer.writeInt(u16, 0x0001, .little);
                const data_size = if (options.data_size) |size| size else 8;
                try writer.writeInt(u16, data_size, .little);
                try writer.writeInt(u64, 0, .little);
                try writer.writeInt(u64, @intCast(opt.content.len), .little);
            }
        }

        var compressed_size: u32 = undefined;
        switch (opt.compression) {
            .store => {
                try writer.writeAll(opt.content);
                compressed_size = @intCast(opt.content.len);
            },
            .deflate => {
                const offset = writer.count;
                var br: std.io.BufferedReader = undefined;
                br.initFixed(@constCast(opt.content));
                var compress: std.compress.flate.Compress = .init(&br, .{});
                var compress_br = compress.readable(&.{});
                const n = try compress_br.readRemaining(writer);
                assert(br.seek == opt.content.len);
                try testing.expectEqual(n, writer.count - offset);
                compressed_size = @intCast(n);
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

    fn writeCentralRecord(
        self: *Zipper,
        store: FileStore,
        opt: struct {
            name: []const u8,
            version_needed_to_extract: u16 = 10,
        },
    ) !void {
        if (self.first_central_offset == null) {
            self.first_central_offset = self.writer.count - self.init_count;
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
        try self.writer.writeStructEndian(hdr, .little);
        try self.writer.writeAll(opt.name);
        self.last_central_limit = self.writer.count - self.init_count;
    }

    fn writeEndRecord(self: *Zipper, opt: EndRecordOptions) !void {
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
            try self.writer.writeStructEndian(fixed, .little);
            const locator: zip.EndLocator64 = .{
                .signature = if (zip64.locator_sig) |s| s else zip.end_locator64_sig,
                .zip64_disk_count = if (zip64.locator_zip64_disk_count) |c| c else 0,
                .record_file_offset = if (zip64.locator_record_file_offset) |o| o else @intCast(end64_off),
                .total_disk_count = if (zip64.locator_total_disk_count) |c| c else 1,
            };
            try self.writer.writeStructEndian(locator, .little);
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
        try self.writer.writeStructEndian(hdr, .little);
        if (opt.comment) |c|
            try self.writer.writeAll(c);
    }
};

fn testZip(options: zip.ExtractOptions, comptime files: []const File, write_opt: WriteZipOptions) !void {
    var store: [files.len]FileStore = undefined;
    try testZipWithStore(options, files, write_opt, &store);
}
fn testZipWithStore(
    options: zip.ExtractOptions,
    test_files: []const File,
    write_opt: WriteZipOptions,
    store: []FileStore,
) !void {
    var tmp = testing.tmpDir(.{ .no_follow = true });
    defer tmp.cleanup();

    var file = tmp.createFile();
    defer file.close();
    var file_writer = file.writer();
    try makeZipWithStore(&file_writer, test_files, write_opt, store);
    var file_reader = file_writer.moveToReader();
    try zip.extract(tmp.dir, &file_reader, options);
    try expectFiles(test_files, tmp.dir, .{});
}
fn testZipError(expected_error: anyerror, file: File, options: zip.ExtractOptions) !void {
    var tmp = testing.tmpDir(.{ .no_follow = true });
    defer tmp.cleanup();
    const tmp_file = tmp.createFile();
    defer tmp_file.close();
    var file_writer = tmp_file.writer();
    var store: [1]FileStore = undefined;
    try makeZipWithStore(&file_writer, &[_]File{file}, .{}, &store);
    var file_reader = file_writer.moveToReader();
    try testing.expectError(expected_error, zip.extract(tmp.dir, &file_reader, options));
}

test "zip one file" {
    try testZip(.{}, &[_]File{
        .{ .name = "onefile.txt", .content = "Just a single file\n", .compression = .store },
    }, .{});
}
test "zip multiple files" {
    try testZip(.{ .allow_backslashes = true }, &[_]File{
        .{ .name = "foo", .content = "a foo file\n", .compression = .store },
        .{ .name = "subdir/bar", .content = "bar is this right?\nanother newline\n", .compression = .store },
        .{ .name = "subdir\\whoa", .content = "you can do backslashes", .compression = .store },
        .{ .name = "subdir/another/baz", .content = "bazzy mc bazzerson", .compression = .store },
    }, .{});
}
test "zip deflated" {
    try testZip(.{}, &[_]File{
        .{ .name = "deflateme", .content = "This is a deflated file.\nIt should be smaller in the Zip file1\n", .compression = .deflate },
        // TODO: re-enable this if/when we add support for deflate64
        //.{ .name = "deflateme64", .content = "The 64k version of deflate!\n", .compression = .deflate64 },
        .{ .name = "raw", .content = "Not all files need to be deflated in the same Zip.\n", .compression = .store },
    }, .{});
}
test "zip verify filenames" {
    // no empty filenames
    try testZipError(error.ZipBadFilename, .{ .name = "", .content = "", .compression = .store }, .{});
    // no absolute paths
    try testZipError(error.ZipBadFilename, .{ .name = "/", .content = "", .compression = .store }, .{});
    try testZipError(error.ZipBadFilename, .{ .name = "/foo", .content = "", .compression = .store }, .{});
    try testZipError(error.ZipBadFilename, .{ .name = "/foo/bar", .content = "", .compression = .store }, .{});
    // no '..' components
    try testZipError(error.ZipBadFilename, .{ .name = "..", .content = "", .compression = .store }, .{});
    try testZipError(error.ZipBadFilename, .{ .name = "foo/..", .content = "", .compression = .store }, .{});
    try testZipError(error.ZipBadFilename, .{ .name = "foo/bar/..", .content = "", .compression = .store }, .{});
    try testZipError(error.ZipBadFilename, .{ .name = "foo/bar/../", .content = "", .compression = .store }, .{});
    // no backslashes
    try testZipError(error.ZipFilenameHasBackslash, .{ .name = "foo\\bar", .content = "", .compression = .store }, .{});
}

test "zip64" {
    const test_files = [_]File{
        .{ .name = "fram", .content = "fram foo fro fraba", .compression = .store },
        .{ .name = "subdir/barro", .content = "aljdk;jal;jfd;lajkf", .compression = .store },
    };

    try testZip(.{}, &test_files, .{
        .end = .{
            .zip64 = .{},
            .record_count_disk = std.math.maxInt(u16), // trigger zip64
        },
    });
    try testZip(.{}, &test_files, .{
        .end = .{
            .zip64 = .{},
            .record_count_total = std.math.maxInt(u16), // trigger zip64
        },
    });
    try testZip(.{}, &test_files, .{
        .end = .{
            .zip64 = .{},
            .record_count_disk = std.math.maxInt(u16), // trigger zip64
            .record_count_total = std.math.maxInt(u16), // trigger zip64
        },
    });
    try testZip(.{}, &test_files, .{
        .end = .{
            .zip64 = .{},
            .central_directory_size = std.math.maxInt(u32), // trigger zip64
        },
    });
    try testZip(.{}, &test_files, .{
        .end = .{
            .zip64 = .{},
            .central_directory_offset = std.math.maxInt(u32), // trigger zip64
        },
    });
    try testZip(.{}, &test_files, .{
        .end = .{
            .zip64 = .{},
            .central_directory_offset = std.math.maxInt(u32), // trigger zip64
        },
        .local_header = .{
            .zip64 = .{ // trigger local header zip64
                .data_size = 16,
            },
            .compressed_size = std.math.maxInt(u32),
            .uncompressed_size = std.math.maxInt(u32),
            .extra_len = 20,
        },
    });
}

test "bad zip files" {
    var tmp = testing.tmpDir(.{ .no_follow = true });
    defer tmp.cleanup();
    var buffer: [4096]u8 = undefined;

    const file_a = [_]File{.{ .name = "a", .content = "", .compression = .store }};

    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &.{}, .{ .end = .{ .sig = [_]u8{ 1, 2, 3, 4 } } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipNoEndRecord, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &.{}, .{ .end = .{ .comment_len = 1 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipNoEndRecord, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &.{}, .{ .end = .{ .comment = "a", .comment_len = 0 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipNoEndRecord, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &.{}, .{ .end = .{ .disk_number = 1 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipMultiDiskUnsupported, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &.{}, .{ .end = .{ .central_directory_disk_number = 1 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipMultiDiskUnsupported, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &.{}, .{ .end = .{ .record_count_disk = 1 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipDiskRecordCountTooLarge, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &.{}, .{ .end = .{ .central_directory_size = 1 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipCdOversized, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &file_a, .{ .end = .{ .central_directory_size = 0 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipCdUndersized, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &file_a, .{ .end = .{ .central_directory_offset = 0 } });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipBadCdOffset, zip.extract(tmp.dir, &file_reader, .{}));
    }
    {
        const tmp_file = tmp.createFile();
        defer tmp_file.close();
        var file_writer = tmp_file.writable(&buffer);
        try makeZip(&file_writer, &file_a, .{
            .end = .{
                .zip64 = .{ .locator_sig = [_]u8{ 1, 2, 3, 4 } },
                .central_directory_size = std.math.maxInt(u32), // trigger 64
            },
        });
        var file_reader = file_writer.moveToReader();
        try testing.expectError(error.ZipBadLocatorSig, zip.extract(tmp.dir, &file_reader, .{}));
    }
}
