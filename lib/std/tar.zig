const std = @import("std.zig");
/// Tar archive is single ordinary file which can contain many files (or
/// directories, symlinks, ...). It's build by series of blocks each size of 512
/// bytes. First block of each entry is header which defines type, name, size
/// permissions and other attributes. Header is followed by series of blocks of
/// file content, if any that entry has content. Content is padded to the block
/// size, so next header always starts at block boundary.
///
/// This simple format is extended by GNU and POSIX pax extensions to support
/// file names longer than 256 bytes and additional attributes.
///
/// This is not comprehensive tar parser. Here we are only file types needed to
/// support Zig package manager; normal file, directory, symbolic link. And
/// subset of attributes: name, size, permissions.
///
/// GNU tar reference: https://www.gnu.org/software/tar/manual/html_node/Standard.html
/// pax reference: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13

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
const MAX_HEADER_NAME_SIZE = 100 + 1 + 155; // name(100) + separator(1) + prefix(155)

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
    /// TODO: check against "../" and other nefarious things
    pub fn fullName(header: Header, buffer: *[MAX_HEADER_NAME_SIZE]u8) ![]const u8 {
        const n = name(header);
        const p = prefix(header);
        if (!is_ustar(header) or p.len == 0) {
            @memcpy(buffer[0..n.len], n);
            return buffer[0..n.len];
        }
        @memcpy(buffer[0..p.len], p);
        buffer[p.len] = '/';
        @memcpy(buffer[p.len + 1 ..][0..n.len], n);
        return buffer[0 .. p.len + 1 + n.len];
    }

    pub fn name(header: Header) []const u8 {
        return header.str(0, 100);
    }

    pub fn mode(header: Header) !u32 {
        return @intCast(try header.numeric(100, 8));
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
    // Returns error or valid chksum value.
    // Zero value indicates empty block.
    pub fn checkChksum(header: Header) !u64 {
        const field = try header.chksum();
        const computed = header.computeChksum();
        if (field != computed) return error.TarHeaderChksum;
        return field;
    }
};

// Breaks string on first null character.
fn nullStr(str: []const u8) []const u8 {
    for (str, 0..) |c, i| {
        if (c == 0) return str[0..i];
    }
    return str;
}

// Number of padding bytes in the last file block.
inline fn blockPadding(size: usize) usize {
    const block_rounded = std.mem.alignForward(usize, size, BLOCK_SIZE); // size rounded to te block boundary
    return block_rounded - size;
}

fn BufferedReader(comptime ReaderType: type) type {
    return struct {
        underlying_reader: ReaderType,
        buffer: [BLOCK_SIZE * 8]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        const Self = @This();

        // Fills buffer from underlying unbuffered reader.
        fn fillBuffer(self: *Self) !void {
            self.removeUsed();
            self.end += try self.underlying_reader.read(self.buffer[self.end..]);
        }

        // Returns slice of size count or how much fits into buffer.
        pub fn readSlice(self: *Self, count: usize) ![]const u8 {
            if (count <= self.end - self.start) {
                return self.buffer[self.start .. self.start + count];
            }
            try self.fillBuffer();
            const buf = self.buffer[self.start..self.end];
            if (buf.len == 0) return error.UnexpectedEndOfStream;
            return buf[0..@min(count, buf.len)];
        }

        // Returns tar header block, 512 bytes, or null if eof. Before reading
        // advances buffer for padding of the previous block, to position reader
        // at the start of new block. After reading advances for block size, to
        // position reader at the start of the file content.
        pub fn readHeader(self: *Self, padding: usize) !?[]const u8 {
            try self.skip(padding);
            const buf = self.readSlice(BLOCK_SIZE) catch return null;
            if (buf.len < BLOCK_SIZE) return error.UnexpectedEndOfStream;
            self.advance(BLOCK_SIZE);
            return buf[0..BLOCK_SIZE];
        }

        // Returns byte at current position in buffer.
        pub fn readByte(self: *@This()) u8 {
            assert(self.start < self.end);
            return self.buffer[self.start];
        }

        // Advances reader for count bytes, assumes that we have that number of
        // bytes in buffer.
        pub fn advance(self: *Self, count: usize) void {
            self.start += count;
            assert(self.start <= self.end);
        }

        // Advances reader without assuming that count bytes are in the buffer.
        pub fn skip(self: *Self, count: usize) !void {
            if (self.start + count > self.end) {
                try self.underlying_reader.skipBytes(self.start + count - self.end, .{});
                self.start = self.end;
            } else {
                self.advance(count);
            }
        }

        // Removes used part of the buffer.
        inline fn removeUsed(self: *Self) void {
            const dest_end = self.end - self.start;
            if (self.start == 0 or dest_end > self.start) return;
            @memcpy(self.buffer[0..dest_end], self.buffer[self.start..self.end]);
            self.end = dest_end;
            self.start = 0;
        }

        // Writes count bytes to the writer. Advances reader.
        pub fn write(self: *Self, writer: anytype, count: usize) !void {
            var pos: usize = 0;
            while (pos < count) {
                const slice = try self.readSlice(count - pos);
                try writer.writeAll(slice);
                self.advance(slice.len);
                pos += slice.len;
            }
        }

        // Copies dst.len bytes into dst buffer. Advances reader.
        pub fn copy(self: *Self, dst: []u8) ![]const u8 {
            var pos: usize = 0;
            while (pos < dst.len) {
                const slice = try self.readSlice(dst.len - pos);
                @memcpy(dst[pos .. pos + slice.len], slice);
                self.advance(slice.len);
                pos += slice.len;
            }
            return dst;
        }

        pub fn paxFileReader(self: *Self, size: usize) PaxFileReader {
            return .{
                .size = size,
                .reader = self,
                .offset = 0,
            };
        }

        const PaxFileReader = struct {
            size: usize,
            offset: usize = 0,
            reader: *Self,

            const PaxKeyKind = enum {
                path,
                linkpath,
                size,
            };

            const PaxAttribute = struct {
                key: PaxKeyKind,
                value_len: usize,
                parent: *PaxFileReader,

                // Copies pax attribute value into destination buffer.
                // Must be called with destination buffer of size at least value_len.
                pub fn value(self: PaxAttribute, dst: []u8) ![]u8 {
                    assert(dst.len >= self.value_len);
                    const buf = dst[0..self.value_len];
                    _ = try self.parent.reader.copy(buf);
                    self.parent.offset += buf.len;
                    try self.parent.checkAttributeEnding();
                    return buf;
                }
            };

            // Caller of the next has to call value in PaxAttribute, to advance
            // reader across value.
            pub fn next(self: *PaxFileReader) !?PaxAttribute {
                while (true) {
                    const remaining_size = self.size - self.offset;
                    if (remaining_size == 0) return null;

                    const inf = try parsePaxAttribute(
                        try self.reader.readSlice(remaining_size),
                        remaining_size,
                    );
                    const key: PaxKeyKind = if (inf.is("path"))
                        .path
                    else if (inf.is("linkpath"))
                        .linkpath
                    else if (inf.is("size"))
                        .size
                    else {
                        try self.advance(inf.value_off + inf.value_len);
                        try self.checkAttributeEnding();
                        continue;
                    };
                    try self.advance(inf.value_off); // position reader at the start of the value
                    return PaxAttribute{ .key = key, .value_len = inf.value_len, .parent = self };
                }
            }

            fn checkAttributeEnding(self: *PaxFileReader) !void {
                if (self.reader.readByte() != '\n') return error.InvalidPaxAttribute;
                try self.advance(1);
            }

            fn advance(self: *PaxFileReader, len: usize) !void {
                self.offset += len;
                try self.reader.skip(len);
            }
        };
    };
}

fn Iterator(comptime BufferedReaderType: type) type {
    return struct {
        // scratch buffer for file attributes
        scratch: struct {
            // size: two paths (name and link_name) and files size bytes (24 in pax attribute)
            buffer: [std.fs.MAX_PATH_BYTES * 2 + 24]u8 = undefined,
            tail: usize = 0,

            name: []const u8 = undefined,
            link_name: []const u8 = undefined,
            size: usize = 0,

            // Allocate size of the buffer for some attribute.
            fn alloc(self: *@This(), size: usize) ![]u8 {
                const free_size = self.buffer.len - self.tail;
                if (size > free_size) return error.TarScratchBufferOverflow;
                const head = self.tail;
                self.tail += size;
                assert(self.tail <= self.buffer.len);
                return self.buffer[head..self.tail];
            }

            // Reset buffer and all fields.
            fn reset(self: *@This()) void {
                self.tail = 0;
                self.name = self.buffer[0..0];
                self.link_name = self.buffer[0..0];
                self.size = 0;
            }

            fn append(self: *@This(), header: Header) !void {
                if (self.size == 0) self.size = try header.fileSize();
                if (self.link_name.len == 0) {
                    const link_name = header.linkName();
                    if (link_name.len > 0) {
                        const buf = try self.alloc(link_name.len);
                        @memcpy(buf, link_name);
                        self.link_name = buf;
                    }
                }
                if (self.name.len == 0) {
                    self.name = try header.fullName((try self.alloc(MAX_HEADER_NAME_SIZE))[0..MAX_HEADER_NAME_SIZE]);
                }
            }
        } = .{},

        reader: BufferedReaderType,
        diagnostics: ?*Options.Diagnostics,
        padding: usize = 0, // bytes of padding to the end of the block

        const Self = @This();

        pub const File = struct {
            name: []const u8, // name of file, symlink or directory
            link_name: []const u8, // target name of symlink
            size: usize, // size of the file in bytes
            mode: u32,
            file_type: Header.FileType,

            reader: *BufferedReaderType,

            // Writes file content to writer.
            pub fn write(self: File, writer: anytype) !void {
                try self.reader.write(writer, self.size);
            }

            // Skips file content. Advances reader.
            pub fn skip(self: File) !void {
                try self.reader.skip(self.size);
            }
        };

        // Externally, `next` iterates through the tar archive as if it is a
        // series of files. Internally, the tar format often uses fake "files"
        // to add meta data that describes the next file. These meta data
        // "files" should not normally be visible to the outside. As such, this
        // loop iterates through one or more "header files" until it finds a
        // "normal file".
        pub fn next(self: *Self) !?File {
            self.scratch.reset();

            while (try self.reader.readHeader(self.padding)) |block_bytes| {
                const header = Header{ .bytes = block_bytes[0..BLOCK_SIZE] };
                if (try header.checkChksum() == 0) return null; // zero block found

                const file_type = header.fileType();
                const size: usize = @intCast(try header.fileSize());
                self.padding = blockPadding(size);

                switch (file_type) {
                    // File types to retrun upstream
                    .directory, .normal, .symbolic_link => {
                        try self.scratch.append(header);
                        const file = File{
                            .file_type = file_type,
                            .name = self.scratch.name,
                            .link_name = self.scratch.link_name,
                            .size = self.scratch.size,
                            .reader = &self.reader,
                            .mode = try header.mode(),
                        };
                        self.padding = blockPadding(file.size);
                        return file;
                    },
                    // Prefix header types
                    .gnu_long_name => {
                        self.scratch.name = nullStr(try self.reader.copy(try self.scratch.alloc(size)));
                    },
                    .gnu_long_link => {
                        self.scratch.link_name = nullStr(try self.reader.copy(try self.scratch.alloc(size)));
                    },
                    .extended_header => {
                        if (size == 0) continue;
                        // Use just attributes from last extended header.
                        self.scratch.reset();

                        var rdr = self.reader.paxFileReader(size);
                        while (try rdr.next()) |attr| {
                            switch (attr.key) {
                                .path => {
                                    self.scratch.name = try noNull(try attr.value(try self.scratch.alloc(attr.value_len)));
                                },
                                .linkpath => {
                                    self.scratch.link_name = try noNull(try attr.value(try self.scratch.alloc(attr.value_len)));
                                },
                                .size => {
                                    self.scratch.size = try std.fmt.parseInt(usize, try attr.value(try self.scratch.alloc(attr.value_len)), 10);
                                },
                            }
                        }
                    },
                    // Ignored header type
                    .global_extended_header => {
                        self.reader.skip(size) catch return error.TarHeadersTooBig;
                    },
                    // All other are unsupported header types
                    else => {
                        const d = self.diagnostics orelse return error.TarUnsupportedFileType;
                        try d.errors.append(d.allocator, .{ .unsupported_file_type = .{
                            .file_name = try d.allocator.dupe(u8, header.name()),
                            .file_type = file_type,
                        } });
                    },
                }
            }
            return null;
        }
    };
}

pub fn iterator(underlying_reader: anytype, diagnostics: ?*Options.Diagnostics) Iterator(BufferedReader(@TypeOf(underlying_reader))) {
    return .{
        .reader = bufferedReader(underlying_reader),
        .diagnostics = diagnostics,
    };
}

fn bufferedReader(underlying_reader: anytype) BufferedReader(@TypeOf(underlying_reader)) {
    return BufferedReader(@TypeOf(underlying_reader)){
        .underlying_reader = underlying_reader,
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

test "tar stripComponents" {
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
    if (kv_size > max_size or kv_size < pos_equals + 2) {
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

test "tar parsePaxAttribute" {
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
        mode: u32 = 0,
        link_name: []const u8 = &[0]u8{},
        file_type: Header.FileType = .normal,
        truncated: bool = false, // when there is no file body, just header, usefull for huge files
    };

    path: []const u8, // path to the tar archive file on dis
    files: []const File = &[_]TestCase.File{}, // expected files to found in archive
    chksums: []const []const u8 = &[_][]const u8{}, // chksums of files content
    err: ?anyerror = null, // parsing should fail with this error
};

test "tar run Go test cases" {
    const test_dir = if (std.os.getenv("GO_TAR_TESTDATA_PATH")) |path|
        try std.fs.openDirAbsolute(path, .{})
    else
        return error.SkipZigTest;

    const cases = [_]TestCase{
        .{
            .path = "gnu.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "small.txt",
                    .size = 5,
                    .mode = 0o640,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                    .mode = 0o640,
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
                    .mode = 0o640,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                    .mode = 0o640,
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
                    .mode = 0o444,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                    .mode = 0o444,
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
                    .mode = 0o664,
                },
                .{
                    .name = "a/b",
                    .size = 0,
                    .file_type = .symbolic_link,
                    .mode = 0o777,
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
        .{
            // size is in pax attribute
            .path = "pax-pos-size-file.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "foo",
                    .size = 999,
                    .file_type = .normal,
                    .mode = 0o640,
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
                    .mode = 0o664,
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
                    .mode = 0o644,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                    .file_type = .normal,
                    .mode = 0o644,
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
                    .mode = 0o644,
                },
            },
        },
        .{
            .path = "gnu-utf8.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹",
                    .mode = 0o644,
                },
            },
        },
        .{
            .path = "gnu-not-utf8.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "hi\x80\x81\x82\x83bye",
                    .mode = 0o644,
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
                    .mode = 0o644,
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
                    .mode = 0o640,
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
                    .mode = 0o644,
                    .truncated = true,
                },
            },
        },
    };

    for (cases) |case| {
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
        }) |actual| : (i += 1) {
            const expected = case.files[i];
            try std.testing.expectEqualStrings(expected.name, actual.name);
            try std.testing.expectEqual(expected.size, actual.size);
            try std.testing.expectEqual(expected.file_type, actual.file_type);
            try std.testing.expectEqual(expected.mode, actual.mode);
            try std.testing.expectEqualStrings(expected.link_name, actual.link_name);

            if (case.chksums.len > i) {
                var md5writer = Md5Writer{};
                try actual.write(&md5writer);
                const chksum = md5writer.chksum();
                try std.testing.expectEqualStrings(case.chksums[i], &chksum);
            } else {
                if (!expected.truncated) try actual.skip(); // skip file content
            }
        }
        try std.testing.expectEqual(case.files.len, i);
    }
}

// used in test to calculate file chksum
const Md5Writer = struct {
    h: std.crypto.hash.Md5 = std.crypto.hash.Md5.init(.{}),

    pub fn writeAll(self: *Md5Writer, buf: []const u8) !void {
        self.h.update(buf);
    }

    pub fn chksum(self: *Md5Writer) [32]u8 {
        var s = [_]u8{0} ** 16;
        self.h.final(&s);
        return std.fmt.bytesToHex(s, .lower);
    }
};

test "tar PaxFileReader" {
    const Attribute = struct {
        const PaxKeyKind = enum {
            path,
            linkpath,
            size,
        };
        key: PaxKeyKind,
        value: []const u8,
    };
    const cases = [_]struct {
        data: []const u8,
        attrs: []const Attribute,
        err: ?anyerror = null,
    }{
        .{ // valid but unknown keys
            .data =
            \\30 mtime=1350244992.023960108
            \\6 k=1
            \\13 key1=val1
            \\10 a=name
            \\9 a=name
            \\
            ,
            .attrs = &[_]Attribute{},
        },
        .{ // mix of known and unknown keys
            .data =
            \\6 k=1
            \\13 path=name
            \\17 linkpath=link
            \\13 key1=val1
            \\12 size=123
            \\13 key2=val2
            \\
            ,
            .attrs = &[_]Attribute{
                .{ .key = .path, .value = "name" },
                .{ .key = .linkpath, .value = "link" },
                .{ .key = .size, .value = "123" },
            },
        },
        .{ // too short size of the second key-value pair
            .data =
            \\13 path=name
            \\10 linkpath=value
            \\
            ,
            .attrs = &[_]Attribute{
                .{ .key = .path, .value = "name" },
            },
            .err = error.InvalidPaxAttribute,
        },
        .{ // too long size of the second key-value pair
            .data =
            \\13 path=name
            \\19 linkpath=value
            \\
            ,
            .attrs = &[_]Attribute{
                .{ .key = .path, .value = "name" },
            },
            .err = error.InvalidPaxAttribute,
        },
    };
    var buffer: [1024]u8 = undefined;

    for (cases) |case| {
        var stream = std.io.fixedBufferStream(case.data);
        var brdr = bufferedReader(stream.reader());

        var rdr = brdr.paxFileReader(case.data.len);
        var i: usize = 0;
        while (rdr.next() catch |err| {
            if (case.err) |e| {
                try std.testing.expectEqual(e, err);
                continue;
            } else {
                return err;
            }
        }) |attr| : (i += 1) {
            try std.testing.expectEqualStrings(
                case.attrs[i].value,
                try attr.value(&buffer),
            );
        }
        try std.testing.expectEqual(case.attrs.len, i);
        try std.testing.expect(case.err == null);
    }
}
