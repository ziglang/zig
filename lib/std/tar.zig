const std = @import("std.zig");
const assert = std.debug.assert;

pub const Options = struct {
    /// Number of directory levels to skip when extracting files.
    strip_components: u32 = 0,
    /// How to handle the "mode" property of files from within the tar file.
    mode_mode: ModeMode = .executable_bit_only,
    /// Prevents creation of empty directories.
    exclude_empty_directories: bool = false,
    /// Provide this to receive detailed error messages.
    /// When this is provided, some errors which would otherwise be returned immediately
    /// will instead be added to this structure. The API user must check the errors
    /// in diagnostics to know whether the operation succeeded or failed.
    diagnostics: ?*Diagnostics = null,

    pub const ModeMode = enum {
        /// The mode from the tar file is completely ignored. Files are created
        /// with the default mode when creating files.
        ignore,
        /// The mode from the tar file is inspected for the owner executable bit
        /// only. This bit is copied to the group and other executable bits.
        /// Other bits of the mode are left as the default when creating files.
        executable_bit_only,
    };

    pub const Diagnostics = struct {
        allocator: std.mem.Allocator,
        errors: std.ArrayListUnmanaged(Error) = .{},

        pub const Error = union(enum) {
            unable_to_create_sym_link: struct {
                code: anyerror,
                file_name: []const u8,
                link_name: []const u8,
            },
            unable_to_create_file: struct {
                code: anyerror,
                file_name: []const u8,
            },
            unsupported_file_type: struct {
                file_name: []const u8,
                file_type: Header.FileType,
            },
        };

        pub fn deinit(d: *Diagnostics) void {
            for (d.errors.items) |item| {
                switch (item) {
                    .unable_to_create_sym_link => |info| {
                        d.allocator.free(info.file_name);
                        d.allocator.free(info.link_name);
                    },
                    .unable_to_create_file => |info| {
                        d.allocator.free(info.file_name);
                    },
                    .unsupported_file_type => |info| {
                        d.allocator.free(info.file_name);
                    },
                }
            }
            d.errors.deinit(d.allocator);
            d.* = undefined;
        }
    };
};

const BLOCK_SIZE = 512;

pub const Header = struct {
    bytes: *const [BLOCK_SIZE]u8,

    pub const FileType = enum(u8) {
        normal_alias = 0,
        normal = '0',
        hard_link = '1',
        symbolic_link = '2',
        character_special = '3',
        block_special = '4',
        directory = '5',
        fifo = '6',
        contiguous = '7',
        global_extended_header = 'g',
        extended_header = 'x',
        // Types 'L' and 'K' are used by the GNU format for a meta file
        // used to store the path or link name for the next file.
        gnu_long_name = 'L',
        gnu_long_link = 'K',
        _,
    };

    /// Includes prefix concatenated, if any.
    /// Return value may point into Header buffer, or might point into the
    /// argument buffer.
    /// TODO: check against "../" and other nefarious things
    pub fn fullFileName(header: Header, buffer: *[std.fs.MAX_PATH_BYTES]u8) ![]const u8 {
        const n = name(header);
        if (!is_ustar(header))
            return n;
        const p = prefix(header);
        if (p.len == 0)
            return n;
        @memcpy(buffer[0..p.len], p);
        buffer[p.len] = '/';
        @memcpy(buffer[p.len + 1 ..][0..n.len], n);
        return buffer[0 .. p.len + 1 + n.len];
    }

    pub fn name(header: Header) []const u8 {
        return header.str(0, 100);
    }

    pub fn fileSize(header: Header) !u64 {
        return header.numeric(124, 12);
    }

    pub fn chksum(header: Header) !u64 {
        return header.octal(148, 8);
    }

    pub fn linkName(header: Header) []const u8 {
        return header.str(157, 100);
    }

    pub fn is_ustar(header: Header) bool {
        const magic = header.bytes[257..][0..6];
        return std.mem.eql(u8, magic[0..5], "ustar") and (magic[5] == 0 or magic[5] == ' ');
    }

    pub fn prefix(header: Header) []const u8 {
        return header.str(345, 155);
    }

    pub fn fileType(header: Header) FileType {
        const result: FileType = @enumFromInt(header.bytes[156]);
        if (result == .normal_alias) return .normal;
        return result;
    }

    fn str(header: Header, start: usize, len: usize) []const u8 {
        return nullStr(header.bytes[start .. start + len]);
    }

    fn numeric(header: Header, start: usize, len: usize) !u64 {
        const raw = header.bytes[start..][0..len];
        //  If the leading byte is 0xff (255), all the bytes of the field
        //  (including the leading byte) are concatenated in big-endian order,
        //  with the result being a negative number expressed in two’s
        //  complement form.
        if (raw[0] == 0xff) return error.TarNumericValueNegative;
        // If the leading byte is 0x80 (128), the non-leading bytes of the
        // field are concatenated in big-endian order.
        if (raw[0] == 0x80) {
            if (raw[1] + raw[2] + raw[3] != 0) return error.TarNumericValueTooBig;
            return std.mem.readInt(u64, raw[4..12], .big);
        }
        return try header.octal(start, len);
    }

    fn octal(header: Header, start: usize, len: usize) !u64 {
        const raw = header.bytes[start..][0..len];
        // Zero-filled octal number in ASCII. Each numeric field of width w
        // contains w minus 1 digits, and a null
        const ltrimmed = std.mem.trimLeft(u8, raw, "0 ");
        const rtrimmed = std.mem.trimRight(u8, ltrimmed, " \x00");
        if (rtrimmed.len == 0) return 0;
        return std.fmt.parseInt(u64, rtrimmed, 8) catch return error.TarHeader;
    }

    // Sum of all bytes in the header block. The chksum field is treated as if
    // it were filled with spaces (ASCII 32).
    fn computeChksum(header: Header) u64 {
        var sum: u64 = 0;
        for (header.bytes, 0..) |b, i| {
            if (148 <= i and i < 156) continue; // skip chksum field bytes
            sum += b;
        }
        // Treating chksum bytes as spaces. 256 = 8 * 32, 8 spaces.
        return if (sum > 0) sum + 256 else 0;
    }

    // Checks calculated chksum with value of chksum field.
    // Returns error or chksum value.
    // Zero value indicates empty block.
    pub fn checkChksum(header: Header) !u64 {
        const field = try header.chksum();
        const computed = header.computeChksum();
        if (field != computed) return error.TarHeaderChksum;
        return field;
    }
};

// break string on first null char
fn nullStr(str: []const u8) []const u8 {
    for (str, 0..) |c, i| {
        if (c == 0) return str[0..i];
    }
    return str;
}

fn BufferedReader(comptime ReaderType: type) type {
    return struct {
        unbuffered_reader: ReaderType,
        buffer: [BLOCK_SIZE * 8]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        const Self = @This();

        pub fn readChunk(self: *Self, count: usize) ![]const u8 {
            self.ensureCapacity(1024);

            const ask = @min(self.buffer.len - self.end, count -| (self.end - self.start));
            self.end += try self.unbuffered_reader.readAtLeast(self.buffer[self.end..], ask);

            return self.buffer[self.start..self.end];
        }

        pub fn readBlock(self: *Self) !?[]const u8 {
            const block_bytes = try self.readChunk(BLOCK_SIZE * 2);
            switch (block_bytes.len) {
                0 => return null,
                1...(BLOCK_SIZE - 1) => return error.UnexpectedEndOfStream,
                else => {},
            }
            self.advance(BLOCK_SIZE);
            return block_bytes[0..BLOCK_SIZE];
        }

        pub fn advance(self: *Self, count: usize) void {
            self.start += count;
            assert(self.start <= self.end);
        }

        pub fn skip(self: *Self, count: usize) !void {
            if (self.start + count > self.end) {
                try self.unbuffered_reader.skipBytes(self.start + count - self.end, .{});
                self.start = self.end;
            } else {
                self.advance(count);
            }
        }

        pub fn skipPadding(self: *Self, file_size: usize) !void {
            return self.skip(filePadding(file_size));
        }

        pub fn skipFile(self: *Self, file_size: usize) !void {
            return self.skip(roundedFileSize(file_size));
        }

        inline fn ensureCapacity(self: *Self, count: usize) void {
            if (self.buffer.len - self.start < count) {
                const dest_end = self.end - self.start;
                @memcpy(self.buffer[0..dest_end], self.buffer[self.start..self.end]);
                self.end = dest_end;
                self.start = 0;
            }
        }

        pub fn write(self: *Self, writer: anytype, size: usize) !void {
            var rdr = self.sliceReader(size, true);
            while (try rdr.next()) |slice| {
                try writer.writeAll(slice);
            }
        }

        // copy dst.len bytes into dst
        pub fn copy(self: *Self, dst: []u8) ![]const u8 {
            var rdr = self.sliceReader(dst.len, true);
            var pos: usize = 0;
            while (try rdr.next()) |slice| : (pos += slice.len) {
                @memcpy(dst[pos .. pos + slice.len], slice);
            }
            return dst;
        }

        const SliceReader = struct {
            size: usize,
            chunk_size: usize,
            offset: usize,
            reader: *Self,
            auto_advance: bool,

            pub fn next(self: *@This()) !?[]const u8 {
                if (self.offset >= self.size) return null;

                const temp = try self.reader.readChunk(self.chunk_size - self.offset);
                if (temp.len == 0) return error.UnexpectedEndOfStream;
                const slice = temp[0..@min(self.remainingSize(), temp.len)];
                if (self.auto_advance) try self.advance(slice.len);
                return slice;
            }

            pub fn advance(self: *@This(), len: usize) !void {
                self.offset += len;
                try self.reader.skip(len);
            }

            pub fn byte(self: *@This()) u8 {
                return self.reader.buffer[self.reader.start];
            }

            pub fn copy(self: *@This(), dst: []u8) ![]const u8 {
                _ = try self.reader.copy(dst);
                self.offset += dst.len;
                return dst;
            }

            pub fn remainingSize(self: *@This()) usize {
                return self.size - self.offset;
            }
        };

        pub fn sliceReader(self: *Self, size: usize, auto_advance: bool) Self.SliceReader {
            return .{
                .size = size,
                .chunk_size = roundedFileSize(size) + BLOCK_SIZE,
                .offset = 0,
                .reader = self,
                .auto_advance = auto_advance,
            };
        }
    };
}

// File size rounded to te block boundary.
inline fn roundedFileSize(file_size: usize) usize {
    return std.mem.alignForward(usize, file_size, BLOCK_SIZE);
}

// Number of padding bytes in the last file block.
inline fn filePadding(file_size: usize) usize {
    return roundedFileSize(file_size) - file_size;
}

fn Iterator(comptime ReaderType: type) type {
    const BufferedReaderType = BufferedReader(ReaderType);
    return struct {
        attrs: struct {
            buffer: [std.fs.MAX_PATH_BYTES * 2]u8 = undefined,
            tail: usize = 0,

            fn alloc(self: *@This(), size: usize) ![]u8 {
                if (size > self.len()) return error.NameTooLong;
                const head = self.tail;
                self.tail += size;
                assert(self.tail <= self.buffer.len);
                return self.buffer[head..self.tail];
            }

            fn free(self: *@This()) void {
                self.tail = 0;
            }

            fn len(self: *@This()) usize {
                return self.buffer.len - self.tail;
            }
        } = .{},

        reader: BufferedReaderType,
        diagnostics: ?*Options.Diagnostics,

        const Self = @This();

        const File = struct {
            name: []const u8 = &[_]u8{},
            link_name: []const u8 = &[_]u8{},
            size: usize = 0,
            file_type: Header.FileType = .normal,
            reader: *BufferedReaderType,

            pub fn write(self: File, writer: anytype) !void {
                try self.reader.write(writer, self.size);
                try self.skipPadding();
            }

            pub fn skip(self: File) !void {
                try self.reader.skip(roundedFileSize(self.size));
            }

            fn skipPadding(self: File) !void {
                try self.reader.skip(filePadding(self.size));
            }

            fn chksum(self: File) ![16]u8 {
                var sum = [_]u8{0} ** 16;
                if (self.size == 0) return sum;

                var rdr = self.reader.sliceReader(self.size, true);
                var h = std.crypto.hash.Md5.init(.{});
                while (try rdr.next()) |slice| {
                    h.update(slice);
                }
                h.final(&sum);
                try self.skipPadding();
                return sum;
            }
        };

        // Externally, `next` iterates through the tar archive as if it is a
        // series of files. Internally, the tar format often uses fake "files"
        // to add meta data that describes the next file. These meta data
        // "files" should not normally be visible to the outside. As such, this
        // loop iterates through one or more "header files" until it finds a
        // "normal file".
        pub fn next(self: *Self) !?File {
            var file: File = .{ .reader = &self.reader };
            self.attrs.free();

            while (try self.reader.readBlock()) |block_bytes| {
                const block = Header{ .bytes = block_bytes[0..BLOCK_SIZE] };
                if (try block.checkChksum() == 0) return null; // zero block found
                const file_type = block.fileType();
                const file_size = try block.fileSize();

                switch (file_type) {
                    .directory, .normal, .symbolic_link => {
                        if (file.size == 0) file.size = file_size;
                        if (file.name.len == 0)
                            file.name = try block.fullFileName((try self.attrs.alloc(std.fs.MAX_PATH_BYTES))[0..std.fs.MAX_PATH_BYTES]);
                        if (file.link_name.len == 0) file.link_name = block.linkName();
                        file.file_type = file_type;
                        return file;
                    },
                    .global_extended_header => {
                        self.reader.skipFile(file_size) catch return error.TarHeadersTooBig;
                    },
                    .extended_header => {
                        if (file_size == 0) continue;
                        // TODO: ovo resetiranje je nezgodno
                        self.attrs.free();
                        file = File{ .reader = &self.reader };

                        var rdr = self.reader.sliceReader(file_size, false);
                        while (try rdr.next()) |slice| {
                            const attr = try parsePaxAttribute(slice, rdr.remainingSize());
                            try rdr.advance(attr.value_off);
                            if (attr.is("path")) {
                                file.name = try noNull(try rdr.copy(try self.attrs.alloc(attr.value_len)));
                            } else if (attr.is("linkpath")) {
                                file.link_name = try noNull(try rdr.copy(try self.attrs.alloc(attr.value_len)));
                            } else if (attr.is("size")) {
                                var buf = [_]u8{'0'} ** 32;
                                file.size = try std.fmt.parseInt(usize, try rdr.copy(buf[0..attr.value_len]), 10);
                            } else {
                                try rdr.advance(attr.value_len);
                            }
                            if (rdr.byte() != '\n') return error.InvalidPaxAttribute;
                            try rdr.advance(1);
                        }
                        try self.reader.skipPadding(file_size);
                    },
                    .gnu_long_name => {
                        file.name = nullStr(try self.reader.copy(try self.attrs.alloc(file_size)));
                        try self.reader.skipPadding(file_size);
                    },
                    .gnu_long_link => {
                        file.link_name = nullStr(try self.reader.copy(try self.attrs.alloc(file_size)));
                        try self.reader.skipPadding(file_size);
                    },
                    .hard_link => return error.TarUnsupportedFileType,
                    else => {
                        const d = self.diagnostics orelse return error.TarUnsupportedFileType;
                        try d.errors.append(d.allocator, .{ .unsupported_file_type = .{
                            .file_name = try d.allocator.dupe(u8, block.name()),
                            .file_type = file_type,
                        } });
                    },
                }
            }
            return null;
        }
    };
}

pub fn iterator(reader: anytype, diagnostics: ?*Options.Diagnostics) Iterator(@TypeOf(reader)) {
    const ReaderType = @TypeOf(reader);
    return .{
        .reader = BufferedReader(ReaderType){ .unbuffered_reader = reader },
        .diagnostics = diagnostics,
    };
}

pub fn pipeToFileSystem(dir: std.fs.Dir, reader: anytype, options: Options) !void {
    switch (options.mode_mode) {
        .ignore => {},
        .executable_bit_only => {
            // This code does not look at the mode bits yet. To implement this feature,
            // the implementation must be adjusted to look at the mode, and check the
            // user executable bit, then call fchmod on newly created files when
            // the executable bit is supposed to be set.
            // It also needs to properly deal with ACLs on Windows.
            @panic("TODO: unimplemented: tar ModeMode.executable_bit_only");
        },
    }

    var iter = iterator(reader, options.diagnostics);

    while (try iter.next()) |file| {
        switch (file.file_type) {
            .directory => {
                const file_name = try stripComponents(file.name, options.strip_components);
                if (file_name.len != 0 and !options.exclude_empty_directories) {
                    try dir.makePath(file_name);
                }
            },
            .normal => {
                if (file.size == 0 and file.name.len == 0) return;
                const file_name = try stripComponents(file.name, options.strip_components);

                const fs_file = dir.createFile(file_name, .{}) catch |err| switch (err) {
                    error.FileNotFound => again: {
                        const code = code: {
                            if (std.fs.path.dirname(file_name)) |dir_name| {
                                dir.makePath(dir_name) catch |code| break :code code;
                                break :again dir.createFile(file_name, .{}) catch |code| {
                                    break :code code;
                                };
                            }
                            break :code err;
                        };
                        const d = options.diagnostics orelse return error.UnableToCreateFile;
                        try d.errors.append(d.allocator, .{ .unable_to_create_file = .{
                            .code = code,
                            .file_name = try d.allocator.dupe(u8, file_name),
                        } });
                        break :again null;
                    },
                    else => |e| return e,
                };
                defer if (fs_file) |f| f.close();

                if (fs_file) |f| {
                    try file.write(f);
                } else {
                    try file.skip();
                }
            },
            .symbolic_link => {
                // The file system path of the symbolic link.
                const file_name = try stripComponents(file.name, options.strip_components);
                // The data inside the symbolic link.
                const link_name = file.link_name;

                dir.symLink(link_name, file_name, .{}) catch |err| again: {
                    const code = code: {
                        if (err == error.FileNotFound) {
                            if (std.fs.path.dirname(file_name)) |dir_name| {
                                dir.makePath(dir_name) catch |code| break :code code;
                                break :again dir.symLink(link_name, file_name, .{}) catch |code| {
                                    break :code code;
                                };
                            }
                        }
                        break :code err;
                    };
                    const d = options.diagnostics orelse return error.UnableToCreateSymLink;
                    try d.errors.append(d.allocator, .{ .unable_to_create_sym_link = .{
                        .code = code,
                        .file_name = try d.allocator.dupe(u8, file_name),
                        .link_name = try d.allocator.dupe(u8, link_name),
                    } });
                };
            },
            else => unreachable,
        }
    }
}

fn stripComponents(path: []const u8, count: u32) ![]const u8 {
    var i: usize = 0;
    var c = count;
    while (c > 0) : (c -= 1) {
        if (std.mem.indexOfScalarPos(u8, path, i, '/')) |pos| {
            i = pos + 1;
        } else {
            return error.TarComponentsOutsideStrippedPrefix;
        }
    }
    return path[i..];
}

test stripComponents {
    const expectEqualStrings = std.testing.expectEqualStrings;
    try expectEqualStrings("a/b/c", try stripComponents("a/b/c", 0));
    try expectEqualStrings("b/c", try stripComponents("a/b/c", 1));
    try expectEqualStrings("c", try stripComponents("a/b/c", 2));
}

const PaxAttributeInfo = struct {
    size: usize,
    key: []const u8,
    value_off: usize,
    value_len: usize,

    inline fn is(self: @This(), key: []const u8) bool {
        return (std.mem.eql(u8, self.key, key));
    }
};

fn parsePaxAttribute(data: []const u8, max_size: usize) !PaxAttributeInfo {
    const pos_space = std.mem.indexOfScalar(u8, data, ' ') orelse return error.InvalidPaxAttribute;
    const pos_equals = std.mem.indexOfScalarPos(u8, data, pos_space, '=') orelse return error.InvalidPaxAttribute;
    const kv_size = try std.fmt.parseInt(usize, data[0..pos_space], 10);
    if (kv_size > max_size) {
        return error.InvalidPaxAttribute;
    }
    const key = data[pos_space + 1 .. pos_equals];
    return .{
        .size = kv_size,
        .key = try noNull(key),
        .value_off = pos_equals + 1,
        .value_len = kv_size - pos_equals - 2,
    };
}

fn noNull(str: []const u8) ![]const u8 {
    if (std.mem.indexOfScalar(u8, str, 0)) |_| return error.InvalidPaxAttribute;
    return str;
}

test "parsePaxAttribute" {
    const expectEqual = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;
    const expectError = std.testing.expectError;
    const prefix = "1011 path=";
    const file_name = "0123456789" ** 100;
    const header = prefix ++ file_name ++ "\n";
    const attr_info = try parsePaxAttribute(header, 1011);
    try expectEqual(@as(usize, 1011), attr_info.size);
    try expectEqualStrings("path", attr_info.key);
    try expectEqual(prefix.len, attr_info.value_off);
    try expectEqual(file_name.len, attr_info.value_len);
    try expectEqual(attr_info, try parsePaxAttribute(header, 1012));
    try expectError(error.InvalidPaxAttribute, parsePaxAttribute(header, 1010));
    try expectError(error.InvalidPaxAttribute, parsePaxAttribute("", 0));
    try expectError(error.InvalidPaxAttribute, parsePaxAttribute("13 pa\x00th=abc\n", 1024)); // null in key
}

const TestCase = struct {
    const File = struct {
        name: []const u8,
        size: usize = 0,
        link_name: []const u8 = &[0]u8{},
        file_type: Header.FileType = .normal,
        truncated: bool = false, // when there is no file body, just header, usefull for huge files
    };

    path: []const u8, // path to the tar archive file on dis
    files: []const File = &[_]TestCase.File{}, // expected files to found in archive
    chksums: []const []const u8 = &[_][]const u8{}, // chksums of files content
    err: ?anyerror = null, // parsing should fail with this error
};

test "tar: Go test cases" {
    const test_dir = try std.fs.openDirAbsolute("/usr/local/go/src/archive/tar/testdata", .{});
    const cases = [_]TestCase{
        .{
            .path = "gnu.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "small.txt",
                    .size = 5,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                },
            },
            .chksums = &[_][]const u8{
                "e38b27eaccb4391bdec553a7f3ae6b2f",
                "c65bd2e50a56a2138bf1716f2fd56fe9",
            },
        },
        .{
            .path = "sparse-formats.tar",
            .err = error.TarUnsupportedFileType,
        },
        .{
            .path = "star.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "small.txt",
                    .size = 5,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                },
            },
            .chksums = &[_][]const u8{
                "e38b27eaccb4391bdec553a7f3ae6b2f",
                "c65bd2e50a56a2138bf1716f2fd56fe9",
            },
        },
        .{
            .path = "v7.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "small.txt",
                    .size = 5,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                },
            },
            .chksums = &[_][]const u8{
                "e38b27eaccb4391bdec553a7f3ae6b2f",
                "c65bd2e50a56a2138bf1716f2fd56fe9",
            },
        },
        .{
            .path = "pax.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "a/123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                    .size = 7,
                },
                .{
                    .name = "a/b",
                    .size = 0,
                    .file_type = .symbolic_link,
                    .link_name = "123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                },
            },
            .chksums = &[_][]const u8{
                "3c382e8f5b6631aa2db52643912ffd4a",
            },
        },
        .{
            // pax attribute don't end with \n
            .path = "pax-bad-hdr-file.tar",
            .err = error.InvalidPaxAttribute,
        },
        //
        // .{
        //     .path = "pax-bad-mtime-file.tar",
        //     .err = error.TarBadHeader,
        // },
        //
        .{
            // size is in pax attribute
            .path = "pax-pos-size-file.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "foo",
                    .size = 999,
                    .file_type = .normal,
                },
            },
            .chksums = &[_][]const u8{
                "0afb597b283fe61b5d4879669a350556",
            },
        },
        .{
            // has pax records which we are not interested in
            .path = "pax-records.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "file",
                },
            },
        },
        .{
            // has global records which we are ignoring
            .path = "pax-global-records.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "file1",
                },
                .{
                    .name = "file2",
                },
                .{
                    .name = "file3",
                },
                .{
                    .name = "file4",
                },
            },
        },
        .{
            .path = "nil-uid.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "P1050238.JPG.log",
                    .size = 14,
                    .file_type = .normal,
                },
            },
            .chksums = &[_][]const u8{
                "08d504674115e77a67244beac19668f5",
            },
        },
        .{
            // has xattrs and pax records which we are ignoring
            .path = "xattrs.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "small.txt",
                    .size = 5,
                    .file_type = .normal,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                    .file_type = .normal,
                },
            },
            .chksums = &[_][]const u8{
                "e38b27eaccb4391bdec553a7f3ae6b2f",
                "c65bd2e50a56a2138bf1716f2fd56fe9",
            },
        },
        .{
            .path = "gnu-multi-hdrs.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "GNU2/GNU2/long-path-name",
                    .link_name = "GNU4/GNU4/long-linkpath-name",
                    .file_type = .symbolic_link,
                },
            },
        },
        .{
            // has gnu type D (directory) and S (sparse) blocks
            .path = "gnu-incremental.tar",
            .err = error.TarUnsupportedFileType,
        },
        .{
            // should use values only from last pax header
            .path = "pax-multi-hdrs.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "bar",
                    .link_name = "PAX4/PAX4/long-linkpath-name",
                    .file_type = .symbolic_link,
                },
            },
        },
        .{
            .path = "gnu-long-nul.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "0123456789",
                },
            },
        },
        .{
            .path = "gnu-utf8.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹",
                },
            },
        },
        .{
            .path = "gnu-not-utf8.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "hi\x80\x81\x82\x83bye",
                },
            },
        },
        .{
            // null in pax key
            .path = "pax-nul-xattrs.tar",
            .err = error.InvalidPaxAttribute,
        },
        .{
            .path = "pax-nul-path.tar",
            .err = error.InvalidPaxAttribute,
        },
        .{
            .path = "neg-size.tar",
            .err = error.TarHeader,
        },
        .{
            .path = "issue10968.tar",
            .err = error.TarHeader,
        },
        .{
            .path = "issue11169.tar",
            .err = error.TarHeader,
        },
        .{
            .path = "issue12435.tar",
            .err = error.TarHeaderChksum,
        },
        .{
            // has magic with space at end instead of null
            .path = "invalid-go17.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/foo",
                },
            },
        },
        .{
            .path = "ustar-file-devs.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "file",
                },
            },
        },
        .{
            .path = "trailing-slash.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "123456789/" ** 30,
                    .file_type = .directory,
                },
            },
        },
        .{
            // Has size in gnu extended format. To represent size bigger than 8 GB.
            .path = "writer-big.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "tmp/16gig.txt",
                    .size = 16 * 1024 * 1024 * 1024,
                    .truncated = true,
                },
            },
        },
        .{
            // Size in gnu extended format, and name in pax attribute.
            .path = "writer-big-long.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "longname/" ** 15 ++ "16gig.txt",
                    .size = 16 * 1024 * 1024 * 1024,
                    .truncated = true,
                },
            },
        },
    };

    for (cases) |case| {
        //if (!std.mem.eql(u8, case.path, "pax-pos-size-file.tar")) continue;

        var fs_file = try test_dir.openFile(case.path, .{});
        defer fs_file.close();

        var iter = iterator(fs_file.reader(), null);
        var i: usize = 0;
        while (iter.next() catch |err| {
            if (case.err) |e| {
                try std.testing.expectEqual(e, err);
                continue;
            } else {
                return err;
            }
        }) |actual| {
            const expected = case.files[i];
            try std.testing.expectEqualStrings(expected.name, actual.name);
            try std.testing.expectEqual(expected.size, actual.size);
            try std.testing.expectEqual(expected.file_type, actual.file_type);
            try std.testing.expectEqualStrings(expected.link_name, actual.link_name);

            if (case.chksums.len > i) {
                var actual_chksum = try actual.chksum();
                var hex_to_bytes_buffer: [16]u8 = undefined;
                const expected_chksum = try std.fmt.hexToBytes(&hex_to_bytes_buffer, case.chksums[i]);
                // std.debug.print("actual chksum: {s}\n", .{std.fmt.fmtSliceHexLower(&actual_chksum)});
                try std.testing.expectEqualStrings(expected_chksum, &actual_chksum);
            } else {
                if (!expected.truncated) try actual.skip(); // skip file content
            }
            i += 1;
        }
        try std.testing.expectEqual(case.files.len, i);
    }
}
