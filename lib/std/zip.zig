/// The .ZIP File Format Specification is found here:
///    https://pkwaredownloads.blob.core.windows.net/pem/APPNOTE.txt
///
/// Note that this file uses the abbreviation "cd" for "central directory"
///
const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;

pub const testutil = @import("zip/test.zig");
const File = testutil.File;
const FileStore = testutil.FileStore;

pub const CompressionMethod = enum(u16) {
    store = 0,
    deflate = 8,
    _,
};

pub const central_file_header_sig = [4]u8{ 'P', 'K', 1, 2 };
pub const local_file_header_sig = [4]u8{ 'P', 'K', 3, 4 };
pub const end_record_sig = [4]u8{ 'P', 'K', 5, 6 };
pub const end_record64_sig = [4]u8{ 'P', 'K', 6, 6 };
pub const end_locator64_sig = [4]u8{ 'P', 'K', 6, 7 };
pub const ExtraHeader = enum(u16) {
    zip64_info = 0x1,
    _,
};

const GeneralPurposeFlags = packed struct(u16) {
    encrypted: bool,
    _: u15,
};

pub const LocalFileHeader = extern struct {
    signature: [4]u8 align(1),
    version_needed_to_extract: u16 align(1),
    flags: GeneralPurposeFlags align(1),
    compression_method: CompressionMethod align(1),
    last_modification_time: u16 align(1),
    last_modification_date: u16 align(1),
    crc32: u32 align(1),
    compressed_size: u32 align(1),
    uncompressed_size: u32 align(1),
    filename_len: u16 align(1),
    extra_len: u16 align(1),
};

pub const CentralDirectoryFileHeader = extern struct {
    signature: [4]u8 align(1),
    version_made_by: u16 align(1),
    version_needed_to_extract: u16 align(1),
    flags: GeneralPurposeFlags align(1),
    compression_method: CompressionMethod align(1),
    last_modification_time: u16 align(1),
    last_modification_date: u16 align(1),
    crc32: u32 align(1),
    compressed_size: u32 align(1),
    uncompressed_size: u32 align(1),
    filename_len: u16 align(1),
    extra_len: u16 align(1),
    comment_len: u16 align(1),
    disk_number: u16 align(1),
    internal_file_attributes: u16 align(1),
    external_file_attributes: u32 align(1),
    local_file_header_offset: u32 align(1),
};

pub const EndRecord64 = extern struct {
    signature: [4]u8 align(1),
    end_record_size: u64 align(1),
    version_made_by: u16 align(1),
    version_needed_to_extract: u16 align(1),
    disk_number: u32 align(1),
    central_directory_disk_number: u32 align(1),
    record_count_disk: u64 align(1),
    record_count_total: u64 align(1),
    central_directory_size: u64 align(1),
    central_directory_offset: u64 align(1),
};

pub const EndLocator64 = extern struct {
    signature: [4]u8 align(1),
    zip64_disk_count: u32 align(1),
    record_file_offset: u64 align(1),
    total_disk_count: u32 align(1),
};

pub const EndRecord = extern struct {
    signature: [4]u8 align(1),
    disk_number: u16 align(1),
    central_directory_disk_number: u16 align(1),
    record_count_disk: u16 align(1),
    record_count_total: u16 align(1),
    central_directory_size: u32 align(1),
    central_directory_offset: u32 align(1),
    comment_len: u16 align(1),
    pub fn need_zip64(self: EndRecord) bool {
        return isMaxInt(self.record_count_disk) or
            isMaxInt(self.record_count_total) or
            isMaxInt(self.central_directory_size) or
            isMaxInt(self.central_directory_offset);
    }
};

/// Find and return the end record for the given seekable zip stream.
/// Note that `seekable_stream` must be an instance of `std.io.SeekableStream` and
/// its context must also have a `.reader()` method that returns an instance of
/// `std.io.Reader`.
pub fn findEndRecord(seekable_stream: anytype, stream_len: u64) !EndRecord {
    var buf: [@sizeOf(EndRecord) + std.math.maxInt(u16)]u8 = undefined;
    const record_len_max = @min(stream_len, buf.len);
    var loaded_len: u32 = 0;

    var comment_len: u16 = 0;
    while (true) {
        const record_len: u32 = @as(u32, comment_len) + @sizeOf(EndRecord);
        if (record_len > record_len_max)
            return error.ZipNoEndRecord;

        if (record_len > loaded_len) {
            const new_loaded_len = @min(loaded_len + 300, record_len_max);
            const read_len = new_loaded_len - loaded_len;

            try seekable_stream.seekTo(stream_len - @as(u64, new_loaded_len));
            const read_buf: []u8 = buf[buf.len - new_loaded_len ..][0..read_len];
            const len = try seekable_stream.context.reader().readAll(read_buf);
            if (len != read_len)
                return error.ZipTruncated;
            loaded_len = new_loaded_len;
        }

        const record_bytes = buf[buf.len - record_len ..][0..@sizeOf(EndRecord)];
        if (std.mem.eql(u8, record_bytes[0..4], &end_record_sig) and
            std.mem.readInt(u16, record_bytes[20..22], .little) == comment_len)
        {
            const record: *align(1) EndRecord = @ptrCast(record_bytes.ptr);
            if (builtin.target.cpu.arch.endian() != .little) {
                std.mem.byteSwapAllFields(@TypeOf(record.*), record);
            }
            return record.*;
        }

        if (comment_len == std.math.maxInt(u16))
            return error.ZipNoEndRecord;
        comment_len += 1;
    }
}

/// Decompresses the given data from `reader` into `writer`.  Stops early if more
/// than `uncompressed_size` bytes are processed and verifies that exactly that
/// number of bytes are decompressed.  Returns the CRC-32 of the uncompressed data.
/// `writer` can be anything with a `writeAll(self: *Self, chunk: []const u8) anyerror!void` method.
pub fn decompress(
    method: CompressionMethod,
    uncompressed_size: u64,
    reader: anytype,
    writer: anytype,
) !u32 {
    var hash = std.hash.Crc32.init();

    var total_uncompressed: u64 = 0;
    switch (method) {
        .store => {
            var buf: [std.mem.page_size]u8 = undefined;
            while (true) {
                const len = try reader.read(&buf);
                if (len == 0) break;
                try writer.writeAll(buf[0..len]);
                hash.update(buf[0..len]);
                total_uncompressed += @intCast(len);
            }
        },
        .deflate => {
            var br = std.io.bufferedReader(reader);
            var decompressor = std.compress.flate.decompressor(br.reader());
            while (try decompressor.next()) |chunk| {
                try writer.writeAll(chunk);
                hash.update(chunk);
                total_uncompressed += @intCast(chunk.len);
                if (total_uncompressed > uncompressed_size)
                    return error.ZipUncompressSizeTooSmall;
            }
            if (br.end != br.start)
                return error.ZipDeflateTruncated;
        },
        _ => return error.UnsupportedCompressionMethod,
    }
    if (total_uncompressed != uncompressed_size)
        return error.ZipUncompressSizeMismatch;

    return hash.final();
}

fn isBadFilename(filename: []const u8) bool {
    if (filename.len == 0 or filename[0] == '/')
        return true;

    var it = std.mem.splitScalar(u8, filename, '/');
    while (it.next()) |part| {
        if (std.mem.eql(u8, part, ".."))
            return true;
    }

    return false;
}

fn isMaxInt(uint: anytype) bool {
    return uint == std.math.maxInt(@TypeOf(uint));
}

const FileExtents = struct {
    uncompressed_size: u64,
    compressed_size: u64,
    local_file_header_offset: u64,
};

fn readZip64FileExtents(header: CentralDirectoryFileHeader, extents: *FileExtents, data: []u8) !void {
    var data_offset: usize = 0;
    if (isMaxInt(header.uncompressed_size)) {
        if (data_offset + 8 > data.len)
            return error.ZipBadCd64Size;
        extents.uncompressed_size = std.mem.readInt(u64, data[data_offset..][0..8], .little);
        data_offset += 8;
    }
    if (isMaxInt(header.compressed_size)) {
        if (data_offset + 8 > data.len)
            return error.ZipBadCd64Size;
        extents.compressed_size = std.mem.readInt(u64, data[data_offset..][0..8], .little);
        data_offset += 8;
    }
    if (isMaxInt(header.local_file_header_offset)) {
        if (data_offset + 8 > data.len)
            return error.ZipBadCd64Size;
        extents.local_file_header_offset = std.mem.readInt(u64, data[data_offset..][0..8], .little);
        data_offset += 8;
    }
    if (isMaxInt(header.disk_number)) {
        if (data_offset + 4 > data.len)
            return error.ZipInvalid;
        const disk_number = std.mem.readInt(u32, data[data_offset..][0..4], .little);
        if (disk_number != 0)
            return error.ZipMultiDiskUnsupported;
        data_offset += 4;
    }
    if (data_offset > data.len)
        return error.ZipBadCd64Size;
}

pub fn Iterator(comptime SeekableStream: type) type {
    return struct {
        stream: SeekableStream,

        cd_record_count: u64,
        cd_zip_offset: u64,
        cd_size: u64,

        cd_record_index: u64 = 0,
        cd_record_offset: u64 = 0,

        const Self = @This();

        pub fn init(stream: SeekableStream) !Self {
            const stream_len = try stream.getEndPos();

            const end_record = try findEndRecord(stream, stream_len);

            if (!isMaxInt(end_record.record_count_disk) and end_record.record_count_disk > end_record.record_count_total)
                return error.ZipDiskRecordCountTooLarge;

            if (end_record.disk_number != 0 or end_record.central_directory_disk_number != 0)
                return error.ZipMultiDiskUnsupported;

            {
                const counts_valid = !isMaxInt(end_record.record_count_disk) and !isMaxInt(end_record.record_count_total);
                if (counts_valid and end_record.record_count_disk != end_record.record_count_total)
                    return error.ZipMultiDiskUnsupported;
            }

            var result = Self{
                .stream = stream,
                .cd_record_count = end_record.record_count_total,
                .cd_zip_offset = end_record.central_directory_offset,
                .cd_size = end_record.central_directory_size,
            };
            if (!end_record.need_zip64()) return result;

            const locator_end_offset: u64 = @as(u64, end_record.comment_len) + @sizeOf(EndRecord) + @sizeOf(EndLocator64);
            if (locator_end_offset > stream_len)
                return error.ZipTruncated;
            try stream.seekTo(stream_len - locator_end_offset);
            const locator = try stream.context.reader().readStructEndian(EndLocator64, .little);
            if (!std.mem.eql(u8, &locator.signature, &end_locator64_sig))
                return error.ZipBadLocatorSig;
            if (locator.zip64_disk_count != 0)
                return error.ZipUnsupportedZip64DiskCount;
            if (locator.total_disk_count != 1)
                return error.ZipMultiDiskUnsupported;

            try stream.seekTo(locator.record_file_offset);

            const record64 = try stream.context.reader().readStructEndian(EndRecord64, .little);

            if (!std.mem.eql(u8, &record64.signature, &end_record64_sig))
                return error.ZipBadEndRecord64Sig;

            if (record64.end_record_size < @sizeOf(EndRecord64) - 12)
                return error.ZipEndRecord64SizeTooSmall;
            if (record64.end_record_size > @sizeOf(EndRecord64) - 12)
                return error.ZipEndRecord64UnhandledExtraData;

            if (record64.version_needed_to_extract > 45)
                return error.ZipUnsupportedVersion;

            {
                const is_multidisk = record64.disk_number != 0 or
                    record64.central_directory_disk_number != 0 or
                    record64.record_count_disk != record64.record_count_total;
                if (is_multidisk)
                    return error.ZipMultiDiskUnsupported;
            }

            if (isMaxInt(end_record.record_count_total)) {
                result.cd_record_count = record64.record_count_total;
            } else if (end_record.record_count_total != record64.record_count_total)
                return error.Zip64RecordCountTotalMismatch;

            if (isMaxInt(end_record.central_directory_offset)) {
                result.cd_zip_offset = record64.central_directory_offset;
            } else if (end_record.central_directory_offset != record64.central_directory_offset)
                return error.Zip64CentralDirectoryOffsetMismatch;

            if (isMaxInt(end_record.central_directory_size)) {
                result.cd_size = record64.central_directory_size;
            } else if (end_record.central_directory_size != record64.central_directory_size)
                return error.Zip64CentralDirectorySizeMismatch;

            return result;
        }

        pub fn next(self: *Self) !?Entry {
            if (self.cd_record_index == self.cd_record_count) {
                if (self.cd_record_offset != self.cd_size)
                    return if (self.cd_size > self.cd_record_offset)
                        error.ZipCdOversized
                    else
                        error.ZipCdUndersized;

                return null;
            }

            const header_zip_offset = self.cd_zip_offset + self.cd_record_offset;
            try self.stream.seekTo(header_zip_offset);
            const header = try self.stream.context.reader().readStructEndian(CentralDirectoryFileHeader, .little);
            if (!std.mem.eql(u8, &header.signature, &central_file_header_sig))
                return error.ZipBadCdOffset;

            self.cd_record_index += 1;
            self.cd_record_offset += @sizeOf(CentralDirectoryFileHeader) + header.filename_len + header.extra_len + header.comment_len;

            // Note: checking the version_needed_to_extract doesn't seem to be helpful, i.e. the zip file
            // at https://github.com/ninja-build/ninja/releases/download/v1.12.0/ninja-linux.zip
            // has an undocumented version 788 but extracts just fine.

            if (header.flags.encrypted)
                return error.ZipEncryptionUnsupported;
            // TODO: check/verify more flags
            if (header.disk_number != 0)
                return error.ZipMultiDiskUnsupported;

            var extents: FileExtents = .{
                .uncompressed_size = header.uncompressed_size,
                .compressed_size = header.compressed_size,
                .local_file_header_offset = header.local_file_header_offset,
            };

            if (header.extra_len > 0) {
                var extra_buf: [std.math.maxInt(u16)]u8 = undefined;
                const extra = extra_buf[0..header.extra_len];

                {
                    try self.stream.seekTo(header_zip_offset + @sizeOf(CentralDirectoryFileHeader) + header.filename_len);
                    const len = try self.stream.context.reader().readAll(extra);
                    if (len != extra.len)
                        return error.ZipTruncated;
                }

                var extra_offset: usize = 0;
                while (extra_offset + 4 <= extra.len) {
                    const header_id = std.mem.readInt(u16, extra[extra_offset..][0..2], .little);
                    const data_size = std.mem.readInt(u16, extra[extra_offset..][2..4], .little);
                    const end = extra_offset + 4 + data_size;
                    if (end > extra.len)
                        return error.ZipBadExtraFieldSize;
                    const data = extra[extra_offset + 4 .. end];
                    switch (@as(ExtraHeader, @enumFromInt(header_id))) {
                        .zip64_info => try readZip64FileExtents(header, &extents, data),
                        else => {}, // ignore
                    }
                    extra_offset = end;
                }
            }

            return .{
                .version_needed_to_extract = header.version_needed_to_extract,
                .flags = header.flags,
                .compression_method = header.compression_method,
                .last_modification_time = header.last_modification_time,
                .last_modification_date = header.last_modification_date,
                .header_zip_offset = header_zip_offset,
                .crc32 = header.crc32,
                .filename_len = header.filename_len,
                .compressed_size = extents.compressed_size,
                .uncompressed_size = extents.uncompressed_size,
                .file_offset = extents.local_file_header_offset,
            };
        }

        pub const Entry = struct {
            version_needed_to_extract: u16,
            flags: GeneralPurposeFlags,
            compression_method: CompressionMethod,
            last_modification_time: u16,
            last_modification_date: u16,
            header_zip_offset: u64,
            crc32: u32,
            filename_len: u32,
            compressed_size: u64,
            uncompressed_size: u64,
            file_offset: u64,

            pub fn extract(
                self: Entry,
                stream: SeekableStream,
                options: ExtractOptions,
                filename_buf: []u8,
                dest: std.fs.Dir,
            ) !u32 {
                if (filename_buf.len < self.filename_len)
                    return error.ZipInsufficientBuffer;
                const filename = filename_buf[0..self.filename_len];

                try stream.seekTo(self.header_zip_offset + @sizeOf(CentralDirectoryFileHeader));

                {
                    const len = try stream.context.reader().readAll(filename);
                    if (len != filename.len)
                        return error.ZipBadFileOffset;
                }

                const local_data_header_offset: u64 = local_data_header_offset: {
                    const local_header = blk: {
                        try stream.seekTo(self.file_offset);
                        break :blk try stream.context.reader().readStructEndian(LocalFileHeader, .little);
                    };
                    if (!std.mem.eql(u8, &local_header.signature, &local_file_header_sig))
                        return error.ZipBadFileOffset;
                    if (local_header.version_needed_to_extract != self.version_needed_to_extract)
                        return error.ZipMismatchVersionNeeded;
                    if (local_header.last_modification_time != self.last_modification_time)
                        return error.ZipMismatchModTime;
                    if (local_header.last_modification_date != self.last_modification_date)
                        return error.ZipMismatchModDate;

                    if (@as(u16, @bitCast(local_header.flags)) != @as(u16, @bitCast(self.flags)))
                        return error.ZipMismatchFlags;
                    if (local_header.crc32 != 0 and local_header.crc32 != self.crc32)
                        return error.ZipMismatchCrc32;
                    if (local_header.compressed_size != 0 and
                        local_header.compressed_size != self.compressed_size)
                        return error.ZipMismatchCompLen;
                    if (local_header.uncompressed_size != 0 and
                        local_header.uncompressed_size != self.uncompressed_size)
                        return error.ZipMismatchUncompLen;
                    if (local_header.filename_len != self.filename_len)
                        return error.ZipMismatchFilenameLen;

                    break :local_data_header_offset @as(u64, local_header.filename_len) +
                        @as(u64, local_header.extra_len);
                };

                if (isBadFilename(filename))
                    return error.ZipBadFilename;

                if (options.allow_backslashes) {
                    std.mem.replaceScalar(u8, filename, '\\', '/');
                } else {
                    if (std.mem.indexOfScalar(u8, filename, '\\')) |_|
                        return error.ZipFilenameHasBackslash;
                }

                // All entries that end in '/' are directories
                if (filename[filename.len - 1] == '/') {
                    if (self.uncompressed_size != 0)
                        return error.ZipBadDirectorySize;
                    try dest.makePath(filename[0 .. filename.len - 1]);
                    return std.hash.Crc32.hash(&.{});
                }

                const out_file = blk: {
                    if (std.fs.path.dirname(filename)) |dirname| {
                        var parent_dir = try dest.makeOpenPath(dirname, .{});
                        defer parent_dir.close();

                        const basename = std.fs.path.basename(filename);
                        break :blk try parent_dir.createFile(basename, .{ .exclusive = true });
                    }
                    break :blk try dest.createFile(filename, .{ .exclusive = true });
                };
                defer out_file.close();
                const local_data_file_offset: u64 =
                    @as(u64, self.file_offset) +
                    @as(u64, @sizeOf(LocalFileHeader)) +
                    local_data_header_offset;
                try stream.seekTo(local_data_file_offset);
                var limited_reader = std.io.limitedReader(stream.context.reader(), self.compressed_size);
                const crc = try decompress(
                    self.compression_method,
                    self.uncompressed_size,
                    limited_reader.reader(),
                    out_file.writer(),
                );
                if (limited_reader.bytes_left != 0)
                    return error.ZipDecompressTruncated;
                return crc;
            }
        };
    };
}

// returns true if `filename` starts with `root` followed by a forward slash
fn filenameInRoot(filename: []const u8, root: []const u8) bool {
    return (filename.len >= root.len + 1) and
        (filename[root.len] == '/') and
        std.mem.eql(u8, filename[0..root.len], root);
}

pub const Diagnostics = struct {
    allocator: std.mem.Allocator,

    /// The common root directory for all extracted files if there is one.
    root_dir: []const u8 = "",

    saw_first_file: bool = false,

    pub fn deinit(self: *Diagnostics) void {
        self.allocator.free(self.root_dir);
        self.* = undefined;
    }

    // This function assumes name is a filename from a zip file which has already been verified to
    // not start with a slash, backslashes have been normalized to forward slashes, and directories
    // always end in a slash.
    pub fn nextFilename(self: *Diagnostics, name: []const u8) error{OutOfMemory}!void {
        if (!self.saw_first_file) {
            self.saw_first_file = true;
            std.debug.assert(self.root_dir.len == 0);
            const root_len = std.mem.indexOfScalar(u8, name, '/') orelse return;
            std.debug.assert(root_len > 0);
            self.root_dir = try self.allocator.dupe(u8, name[0..root_len]);
        } else if (self.root_dir.len > 0) {
            if (!filenameInRoot(name, self.root_dir)) {
                self.allocator.free(self.root_dir);
                self.root_dir = "";
            }
        }
    }
};

pub const ExtractOptions = struct {
    /// Allow filenames within the zip to use backslashes.  Back slashes are normalized
    /// to forward slashes before forwarding them to platform APIs.
    allow_backslashes: bool = false,

    diagnostics: ?*Diagnostics = null,
};

/// Extract the zipped files inside `seekable_stream` to the given `dest` directory.
/// Note that `seekable_stream` must be an instance of `std.io.SeekableStream` and
/// its context must also have a `.reader()` method that returns an instance of
/// `std.io.Reader`.
pub fn extract(dest: std.fs.Dir, seekable_stream: anytype, options: ExtractOptions) !void {
    const SeekableStream = @TypeOf(seekable_stream);
    var iter = try Iterator(SeekableStream).init(seekable_stream);

    var filename_buf: [std.fs.max_path_bytes]u8 = undefined;
    while (try iter.next()) |entry| {
        const crc32 = try entry.extract(seekable_stream, options, &filename_buf, dest);
        if (crc32 != entry.crc32)
            return error.ZipCrcMismatch;
        if (options.diagnostics) |d| {
            try d.nextFilename(filename_buf[0..entry.filename_len]);
        }
    }
}

fn testZip(options: ExtractOptions, comptime files: []const File, write_opt: testutil.WriteZipOptions) !void {
    var store: [files.len]FileStore = undefined;
    try testZipWithStore(options, files, write_opt, &store);
}
fn testZipWithStore(
    options: ExtractOptions,
    test_files: []const File,
    write_opt: testutil.WriteZipOptions,
    store: []FileStore,
) !void {
    var zip_buf: [4096]u8 = undefined;
    var fbs = try testutil.makeZipWithStore(&zip_buf, test_files, write_opt, store);

    var tmp = testing.tmpDir(.{ .no_follow = true });
    defer tmp.cleanup();
    try extract(tmp.dir, fbs.seekableStream(), options);
    try testutil.expectFiles(test_files, tmp.dir, .{});
}
fn testZipError(expected_error: anyerror, file: File, options: ExtractOptions) !void {
    var zip_buf: [4096]u8 = undefined;
    var store: [1]FileStore = undefined;
    var fbs = try testutil.makeZipWithStore(&zip_buf, &[_]File{file}, .{}, &store);
    var tmp = testing.tmpDir(.{ .no_follow = true });
    defer tmp.cleanup();
    try testing.expectError(expected_error, extract(tmp.dir, fbs.seekableStream(), options));
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
}

test "bad zip files" {
    var tmp = testing.tmpDir(.{ .no_follow = true });
    defer tmp.cleanup();
    var zip_buf: [4096]u8 = undefined;

    const file_a = [_]File{.{ .name = "a", .content = "", .compression = .store }};

    {
        var fbs = try testutil.makeZip(&zip_buf, &.{}, .{ .end = .{ .sig = [_]u8{ 1, 2, 3, 4 } } });
        try testing.expectError(error.ZipNoEndRecord, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &.{}, .{ .end = .{ .comment_len = 1 } });
        try testing.expectError(error.ZipNoEndRecord, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &.{}, .{ .end = .{ .comment = "a", .comment_len = 0 } });
        try testing.expectError(error.ZipNoEndRecord, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &.{}, .{ .end = .{ .disk_number = 1 } });
        try testing.expectError(error.ZipMultiDiskUnsupported, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &.{}, .{ .end = .{ .central_directory_disk_number = 1 } });
        try testing.expectError(error.ZipMultiDiskUnsupported, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &.{}, .{ .end = .{ .record_count_disk = 1 } });
        try testing.expectError(error.ZipDiskRecordCountTooLarge, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &.{}, .{ .end = .{ .central_directory_size = 1 } });
        try testing.expectError(error.ZipCdOversized, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &file_a, .{ .end = .{ .central_directory_size = 0 } });
        try testing.expectError(error.ZipCdUndersized, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &file_a, .{ .end = .{ .central_directory_offset = 0 } });
        try testing.expectError(error.ZipBadCdOffset, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
    {
        var fbs = try testutil.makeZip(&zip_buf, &file_a, .{
            .end = .{
                .zip64 = .{ .locator_sig = [_]u8{ 1, 2, 3, 4 } },
                .central_directory_size = std.math.maxInt(u32), // trigger 64
            },
        });
        try testing.expectError(error.ZipBadLocatorSig, extract(tmp.dir, fbs.seekableStream(), .{}));
    }
}
