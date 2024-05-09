//! Tar archive is single ordinary file which can contain many files (or
//! directories, symlinks, ...). It's build by series of blocks each size of 512
//! bytes. First block of each entry is header which defines type, name, size
//! permissions and other attributes. Header is followed by series of blocks of
//! file content, if any that entry has content. Content is padded to the block
//! size, so next header always starts at block boundary.
//!
//! This simple format is extended by GNU and POSIX pax extensions to support
//! file names longer than 256 bytes and additional attributes.
//!
//! This is not comprehensive tar parser. Here we are only file types needed to
//! support Zig package manager; normal file, directory, symbolic link. And
//! subset of attributes: name, size, permissions.
//!
//! GNU tar reference: https://www.gnu.org/software/tar/manual/html_node/Standard.html
//! pax reference: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

pub const output = @import("tar/output.zig");

/// Provide this to receive detailed error messages.
/// When this is provided, some errors which would otherwise be returned
/// immediately will instead be added to this structure. The API user must check
/// the errors in diagnostics to know whether the operation succeeded or failed.
pub const Diagnostics = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayListUnmanaged(Error) = .{},

    entries: usize = 0,
    root_dir: []const u8 = "",

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
            file_type: Header.Kind,
        },
    };

    fn findRoot(d: *Diagnostics, path: []const u8) !void {
        if (path.len == 0) return;

        d.entries += 1;
        const root_dir = rootDir(path);
        if (d.entries == 1) {
            d.root_dir = try d.allocator.dupe(u8, root_dir);
            return;
        }
        if (d.root_dir.len == 0 or std.mem.eql(u8, root_dir, d.root_dir))
            return;
        d.allocator.free(d.root_dir);
        d.root_dir = "";
    }

    // Returns root dir of the path, assumes non empty path.
    fn rootDir(path: []const u8) []const u8 {
        const start_index: usize = if (path[0] == '/') 1 else 0;
        const end_index: usize = if (path[path.len - 1] == '/') path.len - 1 else path.len;
        const buf = path[start_index..end_index];
        if (std.mem.indexOfScalarPos(u8, buf, 0, '/')) |idx| {
            return buf[0..idx];
        }
        return buf;
    }

    test rootDir {
        const expectEqualStrings = testing.expectEqualStrings;
        try expectEqualStrings("a", rootDir("a"));
        try expectEqualStrings("b", rootDir("b"));
        try expectEqualStrings("c", rootDir("/c"));
        try expectEqualStrings("d", rootDir("/d/"));
        try expectEqualStrings("a", rootDir("a/b"));
        try expectEqualStrings("a", rootDir("a/b/c"));
    }

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
        d.allocator.free(d.root_dir);
        d.* = undefined;
    }
};

/// pipeToFileSystem options
pub const PipeOptions = struct {
    /// Number of directory levels to skip when extracting files.
    strip_components: u32 = 0,
    /// How to handle the "mode" property of files from within the tar file.
    mode_mode: ModeMode = .executable_bit_only,
    /// Prevents creation of empty directories.
    exclude_empty_directories: bool = false,
    /// Collects error messages during unpacking
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
};

const Header = struct {
    const SIZE = 512;
    const MAX_NAME_SIZE = 100 + 1 + 155; // name(100) + separator(1) + prefix(155)
    const LINK_NAME_SIZE = 100;

    bytes: *const [SIZE]u8,

    const Kind = enum(u8) {
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
        gnu_sparse = 'S',
        solaris_extended_header = 'X',
        _,
    };

    /// Includes prefix concatenated, if any.
    /// TODO: check against "../" and other nefarious things
    pub fn fullName(header: Header, buffer: []u8) ![]const u8 {
        const n = name(header);
        const p = prefix(header);
        if (buffer.len < n.len + p.len + 1) return error.TarInsufficientBuffer;
        if (!is_ustar(header) or p.len == 0) {
            @memcpy(buffer[0..n.len], n);
            return buffer[0..n.len];
        }
        @memcpy(buffer[0..p.len], p);
        buffer[p.len] = '/';
        @memcpy(buffer[p.len + 1 ..][0..n.len], n);
        return buffer[0 .. p.len + 1 + n.len];
    }

    /// When kind is symbolic_link linked-to name (target_path) is specified in
    /// the linkname field.
    pub fn linkName(header: Header, buffer: []u8) ![]const u8 {
        const link_name = header.str(157, 100);
        if (link_name.len == 0) {
            return buffer[0..0];
        }
        if (buffer.len < link_name.len) return error.TarInsufficientBuffer;
        const buf = buffer[0..link_name.len];
        @memcpy(buf, link_name);
        return buf;
    }

    pub fn name(header: Header) []const u8 {
        return header.str(0, 100);
    }

    pub fn mode(header: Header) !u32 {
        return @intCast(try header.octal(100, 8));
    }

    pub fn size(header: Header) !u64 {
        const start = 124;
        const len = 12;
        const raw = header.bytes[start..][0..len];
        //  If the leading byte is 0xff (255), all the bytes of the field
        //  (including the leading byte) are concatenated in big-endian order,
        //  with the result being a negative number expressed in two’s
        //  complement form.
        if (raw[0] == 0xff) return error.TarNumericValueNegative;
        // If the leading byte is 0x80 (128), the non-leading bytes of the
        // field are concatenated in big-endian order.
        if (raw[0] == 0x80) {
            if (raw[1] != 0 or raw[2] != 0 or raw[3] != 0) return error.TarNumericValueTooBig;
            return std.mem.readInt(u64, raw[4..12], .big);
        }
        return try header.octal(start, len);
    }

    pub fn chksum(header: Header) !u64 {
        return header.octal(148, 8);
    }

    pub fn is_ustar(header: Header) bool {
        const magic = header.bytes[257..][0..6];
        return std.mem.eql(u8, magic[0..5], "ustar") and (magic[5] == 0 or magic[5] == ' ');
    }

    pub fn prefix(header: Header) []const u8 {
        return header.str(345, 155);
    }

    pub fn kind(header: Header) Kind {
        const result: Kind = @enumFromInt(header.bytes[156]);
        if (result == .normal_alias) return .normal;
        return result;
    }

    fn str(header: Header, start: usize, len: usize) []const u8 {
        return nullStr(header.bytes[start .. start + len]);
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

    const Chksums = struct {
        unsigned: u64,
        signed: i64,
    };

    // Sum of all bytes in the header block. The chksum field is treated as if
    // it were filled with spaces (ASCII 32).
    fn computeChksum(header: Header) Chksums {
        var cs: Chksums = .{ .signed = 0, .unsigned = 0 };
        for (header.bytes, 0..) |v, i| {
            const b = if (148 <= i and i < 156) 32 else v; // Treating chksum bytes as spaces.
            cs.unsigned += b;
            cs.signed += @as(i8, @bitCast(b));
        }
        return cs;
    }

    // Checks calculated chksum with value of chksum field.
    // Returns error or valid chksum value.
    // Zero value indicates empty block.
    pub fn checkChksum(header: Header) !u64 {
        const field = try header.chksum();
        const cs = header.computeChksum();
        if (field == 0 and cs.unsigned == 256) return 0;
        if (field != cs.unsigned and field != cs.signed) return error.TarHeaderChksum;
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

/// Options for iterator.
/// Buffers should be provided by the caller.
pub const IteratorOptions = struct {
    /// Use a buffer with length `std.fs.MAX_PATH_BYTES` to match file system capabilities.
    file_name_buffer: []u8,
    /// Use a buffer with length `std.fs.MAX_PATH_BYTES` to match file system capabilities.
    link_name_buffer: []u8,
    /// Collects error messages during unpacking
    diagnostics: ?*Diagnostics = null,
};

/// Iterates over files in tar archive.
/// `next` returns each file in tar archive.
pub fn iterator(reader: anytype, options: IteratorOptions) Iterator(@TypeOf(reader)) {
    return .{
        .reader = reader,
        .diagnostics = options.diagnostics,
        .file_name_buffer = options.file_name_buffer,
        .link_name_buffer = options.link_name_buffer,
    };
}

/// Type of the file returned by iterator `next` method.
pub const FileKind = enum {
    directory,
    sym_link,
    file,
};

/// Iteartor over entries in the tar file represented by reader.
pub fn Iterator(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        diagnostics: ?*Diagnostics = null,

        // buffers for heeader and file attributes
        header_buffer: [Header.SIZE]u8 = undefined,
        file_name_buffer: []u8,
        link_name_buffer: []u8,

        // bytes of padding to the end of the block
        padding: usize = 0,
        // not consumed bytes of file from last next iteration
        unread_file_bytes: u64 = 0,

        pub const File = struct {
            name: []const u8, // name of file, symlink or directory
            link_name: []const u8, // target name of symlink
            size: u64 = 0, // size of the file in bytes
            mode: u32 = 0,
            kind: FileKind = .file,

            unread_bytes: *u64,
            parent_reader: ReaderType,

            pub const Reader = std.io.Reader(File, ReaderType.Error, File.read);

            pub fn reader(self: File) Reader {
                return .{ .context = self };
            }

            pub fn read(self: File, dest: []u8) ReaderType.Error!usize {
                const buf = dest[0..@min(dest.len, self.unread_bytes.*)];
                const n = try self.parent_reader.read(buf);
                self.unread_bytes.* -= n;
                return n;
            }

            // Writes file content to writer.
            pub fn writeAll(self: File, writer: anytype) !void {
                var buffer: [4096]u8 = undefined;

                while (self.unread_bytes.* > 0) {
                    const buf = buffer[0..@min(buffer.len, self.unread_bytes.*)];
                    try self.parent_reader.readNoEof(buf);
                    try writer.writeAll(buf);
                    self.unread_bytes.* -= buf.len;
                }
            }
        };

        const Self = @This();

        fn readHeader(self: *Self) !?Header {
            if (self.padding > 0) {
                try self.reader.skipBytes(self.padding, .{});
            }
            const n = try self.reader.readAll(&self.header_buffer);
            if (n == 0) return null;
            if (n < Header.SIZE) return error.UnexpectedEndOfStream;
            const header = Header{ .bytes = self.header_buffer[0..Header.SIZE] };
            if (try header.checkChksum() == 0) return null;
            return header;
        }

        fn readString(self: *Self, size: usize, buffer: []u8) ![]const u8 {
            if (size > buffer.len) return error.TarInsufficientBuffer;
            const buf = buffer[0..size];
            try self.reader.readNoEof(buf);
            return nullStr(buf);
        }

        fn newFile(self: *Self) File {
            return .{
                .name = self.file_name_buffer[0..0],
                .link_name = self.link_name_buffer[0..0],
                .parent_reader = self.reader,
                .unread_bytes = &self.unread_file_bytes,
            };
        }

        // Number of padding bytes in the last file block.
        fn blockPadding(size: u64) usize {
            const block_rounded = std.mem.alignForward(u64, size, Header.SIZE); // size rounded to te block boundary
            return @intCast(block_rounded - size);
        }

        /// Iterates through the tar archive as if it is a series of files.
        /// Internally, the tar format often uses entries (header with optional
        /// content) to add meta data that describes the next file. These
        /// entries should not normally be visible to the outside. As such, this
        /// loop iterates through one or more entries until it collects a all
        /// file attributes.
        pub fn next(self: *Self) !?File {
            if (self.unread_file_bytes > 0) {
                // If file content was not consumed by caller
                try self.reader.skipBytes(self.unread_file_bytes, .{});
                self.unread_file_bytes = 0;
            }
            var file: File = self.newFile();

            while (try self.readHeader()) |header| {
                const kind = header.kind();
                const size: u64 = try header.size();
                self.padding = blockPadding(size);

                switch (kind) {
                    // File types to retrun upstream
                    .directory, .normal, .symbolic_link => {
                        file.kind = switch (kind) {
                            .directory => .directory,
                            .normal => .file,
                            .symbolic_link => .sym_link,
                            else => unreachable,
                        };
                        file.mode = try header.mode();

                        // set file attributes if not already set by prefix/extended headers
                        if (file.size == 0) {
                            file.size = size;
                        }
                        if (file.link_name.len == 0) {
                            file.link_name = try header.linkName(self.link_name_buffer);
                        }
                        if (file.name.len == 0) {
                            file.name = try header.fullName(self.file_name_buffer);
                        }

                        self.padding = blockPadding(file.size);
                        self.unread_file_bytes = file.size;
                        return file;
                    },
                    // Prefix header types
                    .gnu_long_name => {
                        file.name = try self.readString(@intCast(size), self.file_name_buffer);
                    },
                    .gnu_long_link => {
                        file.link_name = try self.readString(@intCast(size), self.link_name_buffer);
                    },
                    .extended_header => {
                        // Use just attributes from last extended header.
                        file = self.newFile();

                        var rdr = paxIterator(self.reader, @intCast(size));
                        while (try rdr.next()) |attr| {
                            switch (attr.kind) {
                                .path => {
                                    file.name = try attr.value(self.file_name_buffer);
                                },
                                .linkpath => {
                                    file.link_name = try attr.value(self.link_name_buffer);
                                },
                                .size => {
                                    var buf: [pax_max_size_attr_len]u8 = undefined;
                                    file.size = try std.fmt.parseInt(u64, try attr.value(&buf), 10);
                                },
                            }
                        }
                    },
                    // Ignored header type
                    .global_extended_header => {
                        self.reader.skipBytes(size, .{}) catch return error.TarHeadersTooBig;
                    },
                    // All other are unsupported header types
                    else => {
                        const d = self.diagnostics orelse return error.TarUnsupportedHeader;
                        try d.errors.append(d.allocator, .{ .unsupported_file_type = .{
                            .file_name = try d.allocator.dupe(u8, header.name()),
                            .file_type = kind,
                        } });
                        if (kind == .gnu_sparse) {
                            try self.skipGnuSparseExtendedHeaders(header);
                        }
                        self.reader.skipBytes(size, .{}) catch return error.TarHeadersTooBig;
                    },
                }
            }
            return null;
        }

        fn skipGnuSparseExtendedHeaders(self: *Self, header: Header) !void {
            var is_extended = header.bytes[482] > 0;
            while (is_extended) {
                var buf: [Header.SIZE]u8 = undefined;
                const n = try self.reader.readAll(&buf);
                if (n < Header.SIZE) return error.UnexpectedEndOfStream;
                is_extended = buf[504] > 0;
            }
        }
    };
}

/// Pax attributes iterator.
/// Size is length of pax extended header in reader.
fn paxIterator(reader: anytype, size: usize) PaxIterator(@TypeOf(reader)) {
    return PaxIterator(@TypeOf(reader)){
        .reader = reader,
        .size = size,
    };
}

const PaxAttributeKind = enum {
    path,
    linkpath,
    size,
};

// maxInt(u64) has 20 chars, base 10 in practice we got 24 chars
const pax_max_size_attr_len = 64;

fn PaxIterator(comptime ReaderType: type) type {
    return struct {
        size: usize, // cumulative size of all pax attributes
        reader: ReaderType,
        // scratch buffer used for reading attribute length and keyword
        scratch: [128]u8 = undefined,

        const Self = @This();

        const Attribute = struct {
            kind: PaxAttributeKind,
            len: usize, // length of the attribute value
            reader: ReaderType, // reader positioned at value start

            // Copies pax attribute value into destination buffer.
            // Must be called with destination buffer of size at least Attribute.len.
            pub fn value(self: Attribute, dst: []u8) ![]const u8 {
                if (self.len > dst.len) return error.TarInsufficientBuffer;
                // assert(self.len <= dst.len);
                const buf = dst[0..self.len];
                const n = try self.reader.readAll(buf);
                if (n < self.len) return error.UnexpectedEndOfStream;
                try validateAttributeEnding(self.reader);
                if (hasNull(buf)) return error.PaxNullInValue;
                return buf;
            }
        };

        // Iterates over pax attributes. Returns known only known attributes.
        // Caller has to call value in Attribute, to advance reader across value.
        pub fn next(self: *Self) !?Attribute {
            // Pax extended header consists of one or more attributes, each constructed as follows:
            // "%d %s=%s\n", <length>, <keyword>, <value>
            while (self.size > 0) {
                const length_buf = try self.readUntil(' ');
                const length = try std.fmt.parseInt(usize, length_buf, 10); // record length in bytes

                const keyword = try self.readUntil('=');
                if (hasNull(keyword)) return error.PaxNullInKeyword;

                // calculate value_len
                const value_start = length_buf.len + keyword.len + 2; // 2 separators
                if (length < value_start + 1 or self.size < length) return error.UnexpectedEndOfStream;
                const value_len = length - value_start - 1; // \n separator at end
                self.size -= length;

                const kind: PaxAttributeKind = if (eql(keyword, "path"))
                    .path
                else if (eql(keyword, "linkpath"))
                    .linkpath
                else if (eql(keyword, "size"))
                    .size
                else {
                    try self.reader.skipBytes(value_len, .{});
                    try validateAttributeEnding(self.reader);
                    continue;
                };
                if (kind == .size and value_len > pax_max_size_attr_len) {
                    return error.PaxSizeAttrOverflow;
                }
                return Attribute{
                    .kind = kind,
                    .len = value_len,
                    .reader = self.reader,
                };
            }

            return null;
        }

        fn readUntil(self: *Self, delimiter: u8) ![]const u8 {
            var fbs = std.io.fixedBufferStream(&self.scratch);
            try self.reader.streamUntilDelimiter(fbs.writer(), delimiter, null);
            return fbs.getWritten();
        }

        fn eql(a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }

        fn hasNull(str: []const u8) bool {
            return (std.mem.indexOfScalar(u8, str, 0)) != null;
        }

        // Checks that each record ends with new line.
        fn validateAttributeEnding(reader: ReaderType) !void {
            if (try reader.readByte() != '\n') return error.PaxInvalidAttributeEnd;
        }
    };
}

/// Saves tar file content to the file systems.
pub fn pipeToFileSystem(dir: std.fs.Dir, reader: anytype, options: PipeOptions) !void {
    var file_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var link_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var iter = iterator(reader, .{
        .file_name_buffer = &file_name_buffer,
        .link_name_buffer = &link_name_buffer,
        .diagnostics = options.diagnostics,
    });

    while (try iter.next()) |file| {
        const file_name = stripComponents(file.name, options.strip_components);
        if (options.diagnostics) |d| {
            try d.findRoot(file_name);
        }

        switch (file.kind) {
            .directory => {
                if (file_name.len != 0 and !options.exclude_empty_directories) {
                    try dir.makePath(file_name);
                }
            },
            .file => {
                if (file_name.len == 0) return error.BadFileName;
                if (createDirAndFile(dir, file_name, fileMode(file.mode, options))) |fs_file| {
                    defer fs_file.close();
                    try file.writeAll(fs_file);
                } else |err| {
                    const d = options.diagnostics orelse return err;
                    try d.errors.append(d.allocator, .{ .unable_to_create_file = .{
                        .code = err,
                        .file_name = try d.allocator.dupe(u8, file_name),
                    } });
                }
            },
            .sym_link => {
                if (file_name.len == 0) return error.BadFileName;
                const link_name = file.link_name;
                createDirAndSymlink(dir, link_name, file_name) catch |err| {
                    const d = options.diagnostics orelse return error.UnableToCreateSymLink;
                    try d.errors.append(d.allocator, .{ .unable_to_create_sym_link = .{
                        .code = err,
                        .file_name = try d.allocator.dupe(u8, file_name),
                        .link_name = try d.allocator.dupe(u8, link_name),
                    } });
                };
            },
        }
    }
}

fn createDirAndFile(dir: std.fs.Dir, file_name: []const u8, mode: std.fs.File.Mode) !std.fs.File {
    const fs_file = dir.createFile(file_name, .{ .exclusive = true, .mode = mode }) catch |err| {
        if (err == error.FileNotFound) {
            if (std.fs.path.dirname(file_name)) |dir_name| {
                try dir.makePath(dir_name);
                return try dir.createFile(file_name, .{ .exclusive = true, .mode = mode });
            }
        }
        return err;
    };
    return fs_file;
}

// Creates a symbolic link at path `file_name` which points to `link_name`.
fn createDirAndSymlink(dir: std.fs.Dir, link_name: []const u8, file_name: []const u8) !void {
    dir.symLink(link_name, file_name, .{}) catch |err| {
        if (err == error.FileNotFound) {
            if (std.fs.path.dirname(file_name)) |dir_name| {
                try dir.makePath(dir_name);
                return try dir.symLink(link_name, file_name, .{});
            }
        }
        return err;
    };
}

fn stripComponents(path: []const u8, count: u32) []const u8 {
    var i: usize = 0;
    var c = count;
    while (c > 0) : (c -= 1) {
        if (std.mem.indexOfScalarPos(u8, path, i, '/')) |pos| {
            i = pos + 1;
        } else {
            i = path.len;
            break;
        }
    }
    return path[i..];
}

test stripComponents {
    const expectEqualStrings = testing.expectEqualStrings;
    try expectEqualStrings("a/b/c", stripComponents("a/b/c", 0));
    try expectEqualStrings("b/c", stripComponents("a/b/c", 1));
    try expectEqualStrings("c", stripComponents("a/b/c", 2));
    try expectEqualStrings("", stripComponents("a/b/c", 3));
    try expectEqualStrings("", stripComponents("a/b/c", 4));
}

test PaxIterator {
    const Attr = struct {
        kind: PaxAttributeKind,
        value: []const u8 = undefined,
        err: ?anyerror = null,
    };
    const cases = [_]struct {
        data: []const u8,
        attrs: []const Attr,
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
            .attrs = &[_]Attr{},
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
            .attrs = &[_]Attr{
                .{ .kind = .path, .value = "name" },
                .{ .kind = .linkpath, .value = "link" },
                .{ .kind = .size, .value = "123" },
            },
        },
        .{ // too short size of the second key-value pair
            .data =
            \\13 path=name
            \\10 linkpath=value
            \\
            ,
            .attrs = &[_]Attr{
                .{ .kind = .path, .value = "name" },
            },
            .err = error.UnexpectedEndOfStream,
        },
        .{ // too long size of the second key-value pair
            .data =
            \\13 path=name
            \\6 k=1
            \\19 linkpath=value
            \\
            ,
            .attrs = &[_]Attr{
                .{ .kind = .path, .value = "name" },
            },
            .err = error.UnexpectedEndOfStream,
        },

        .{ // too long size of the second key-value pair
            .data =
            \\13 path=name
            \\19 linkpath=value
            \\6 k=1
            \\
            ,
            .attrs = &[_]Attr{
                .{ .kind = .path, .value = "name" },
                .{ .kind = .linkpath, .err = error.PaxInvalidAttributeEnd },
            },
        },
        .{ // null in keyword is not valid
            .data = "13 path=name\n" ++ "7 k\x00b=1\n",
            .attrs = &[_]Attr{
                .{ .kind = .path, .value = "name" },
            },
            .err = error.PaxNullInKeyword,
        },
        .{ // null in value is not valid
            .data = "23 path=name\x00with null\n",
            .attrs = &[_]Attr{
                .{ .kind = .path, .err = error.PaxNullInValue },
            },
        },
        .{ // 1000 characters path
            .data = "1011 path=" ++ "0123456789" ** 100 ++ "\n",
            .attrs = &[_]Attr{
                .{ .kind = .path, .value = "0123456789" ** 100 },
            },
        },
    };
    var buffer: [1024]u8 = undefined;

    outer: for (cases) |case| {
        var stream = std.io.fixedBufferStream(case.data);
        var iter = paxIterator(stream.reader(), case.data.len);

        var i: usize = 0;
        while (iter.next() catch |err| {
            if (case.err) |e| {
                try testing.expectEqual(e, err);
                continue;
            }
            return err;
        }) |attr| : (i += 1) {
            const exp = case.attrs[i];
            try testing.expectEqual(exp.kind, attr.kind);
            const value = attr.value(&buffer) catch |err| {
                if (exp.err) |e| {
                    try testing.expectEqual(e, err);
                    break :outer;
                }
                return err;
            };
            try testing.expectEqualStrings(exp.value, value);
        }
        try testing.expectEqual(case.attrs.len, i);
        try testing.expect(case.err == null);
    }
}

test {
    _ = @import("tar/test.zig");
    _ = Diagnostics;
}

test "header parse size" {
    const cases = [_]struct {
        in: []const u8,
        want: u64 = 0,
        err: ?anyerror = null,
    }{
        // Test base-256 (binary) encoded values.
        .{ .in = "", .want = 0 },
        .{ .in = "\x80", .want = 0 },
        .{ .in = "\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01", .want = 1 },
        .{ .in = "\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02", .want = 0x0102 },
        .{ .in = "\x80\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08", .want = 0x0102030405060708 },
        .{ .in = "\x80\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09", .err = error.TarNumericValueTooBig },
        .{ .in = "\x80\x00\x00\x00\x07\x76\xa2\x22\xeb\x8a\x72\x61", .want = 537795476381659745 },
        .{ .in = "\x80\x80\x80\x00\x01\x02\x03\x04\x05\x06\x07\x08", .err = error.TarNumericValueTooBig },

        // // Test base-8 (octal) encoded values.
        .{ .in = "00000000227\x00", .want = 0o227 },
        .{ .in = "  000000227\x00", .want = 0o227 },
        .{ .in = "00000000228\x00", .err = error.TarHeader },
        .{ .in = "11111111111\x00", .want = 0o11111111111 },
    };

    for (cases) |case| {
        var bytes = [_]u8{0} ** Header.SIZE;
        @memcpy(bytes[124 .. 124 + case.in.len], case.in);
        var header = Header{ .bytes = &bytes };
        if (case.err) |err| {
            try testing.expectError(err, header.size());
        } else {
            try testing.expectEqual(case.want, try header.size());
        }
    }
}

test "header parse mode" {
    const cases = [_]struct {
        in: []const u8,
        want: u64 = 0,
        err: ?anyerror = null,
    }{
        .{ .in = "0000644\x00", .want = 0o644 },
        .{ .in = "0000777\x00", .want = 0o777 },
        .{ .in = "7777777\x00", .want = 0o7777777 },
        .{ .in = "7777778\x00", .err = error.TarHeader },
        .{ .in = "77777777", .want = 0o77777777 },
        .{ .in = "777777777777", .want = 0o77777777 },
    };
    for (cases) |case| {
        var bytes = [_]u8{0} ** Header.SIZE;
        @memcpy(bytes[100 .. 100 + case.in.len], case.in);
        var header = Header{ .bytes = &bytes };
        if (case.err) |err| {
            try testing.expectError(err, header.mode());
        } else {
            try testing.expectEqual(case.want, try header.mode());
        }
    }
}

test "create file and symlink" {
    var root = testing.tmpDir(.{});
    defer root.cleanup();

    var file = try createDirAndFile(root.dir, "file1", default_mode);
    file.close();
    file = try createDirAndFile(root.dir, "a/b/c/file2", default_mode);
    file.close();

    createDirAndSymlink(root.dir, "a/b/c/file2", "symlink1") catch |err| {
        // On Windows when developer mode is not enabled
        if (err == error.AccessDenied) return error.SkipZigTest;
        return err;
    };
    try createDirAndSymlink(root.dir, "../../../file1", "d/e/f/symlink2");

    // Danglink symlnik, file created later
    try createDirAndSymlink(root.dir, "../../../g/h/i/file4", "j/k/l/symlink3");
    file = try createDirAndFile(root.dir, "g/h/i/file4", default_mode);
    file.close();
}

test iterator {
    // Example tar file is created from this tree structure:
    // $ tree example
    //    example
    //    ├── a
    //    │   └── file
    //    ├── b
    //    │   └── symlink -> ../a/file
    //    └── empty
    // $ cat example/a/file
    //   content
    // $ tar -cf example.tar example
    // $ tar -tvf example.tar
    //    example/
    //    example/b/
    //    example/b/symlink -> ../a/file
    //    example/a/
    //    example/a/file
    //    example/empty/

    const data = @embedFile("tar/testdata/example.tar");
    var fbs = std.io.fixedBufferStream(data);

    // User provided buffers to the iterator
    var file_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var link_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    // Create iterator
    var iter = iterator(fbs.reader(), .{
        .file_name_buffer = &file_name_buffer,
        .link_name_buffer = &link_name_buffer,
    });
    // Iterate over files in example.tar
    var file_no: usize = 0;
    while (try iter.next()) |file| : (file_no += 1) {
        switch (file.kind) {
            .directory => {
                switch (file_no) {
                    0 => try testing.expectEqualStrings("example/", file.name),
                    1 => try testing.expectEqualStrings("example/b/", file.name),
                    3 => try testing.expectEqualStrings("example/a/", file.name),
                    5 => try testing.expectEqualStrings("example/empty/", file.name),
                    else => unreachable,
                }
            },
            .file => {
                try testing.expectEqualStrings("example/a/file", file.name);
                // Read file content
                var buf: [16]u8 = undefined;
                const n = try file.reader().readAll(&buf);
                try testing.expectEqualStrings("content\n", buf[0..n]);
            },
            .sym_link => {
                try testing.expectEqualStrings("example/b/symlink", file.name);
                try testing.expectEqualStrings("../a/file", file.link_name);
            },
        }
    }
}

test pipeToFileSystem {
    // Example tar file is created from this tree structure:
    // $ tree example
    //    example
    //    ├── a
    //    │   └── file
    //    ├── b
    //    │   └── symlink -> ../a/file
    //    └── empty
    // $ cat example/a/file
    //   content
    // $ tar -cf example.tar example
    // $ tar -tvf example.tar
    //    example/
    //    example/b/
    //    example/b/symlink -> ../a/file
    //    example/a/
    //    example/a/file
    //    example/empty/

    const data = @embedFile("tar/testdata/example.tar");
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    var tmp = testing.tmpDir(.{ .no_follow = true });
    defer tmp.cleanup();
    const dir = tmp.dir;

    // Save tar from `reader` to the file system `dir`
    pipeToFileSystem(dir, reader, .{
        .mode_mode = .ignore,
        .strip_components = 1,
        .exclude_empty_directories = true,
    }) catch |err| {
        // Skip on platform which don't support symlinks
        if (err == error.UnableToCreateSymLink) return error.SkipZigTest;
        return err;
    };

    try testing.expectError(error.FileNotFound, dir.statFile("empty"));
    try testing.expect((try dir.statFile("a/file")).kind == .file);
    try testing.expect((try dir.statFile("b/symlink")).kind == .file); // statFile follows symlink

    var buf: [32]u8 = undefined;
    try testing.expectEqualSlices(
        u8,
        "../a/file",
        normalizePath(try dir.readLink("b/symlink", &buf)),
    );
}

test "pipeToFileSystem root_dir" {
    const data = @embedFile("tar/testdata/example.tar");
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    // with strip_components = 1
    {
        var tmp = testing.tmpDir(.{ .no_follow = true });
        defer tmp.cleanup();
        var diagnostics: Diagnostics = .{ .allocator = testing.allocator };
        defer diagnostics.deinit();

        pipeToFileSystem(tmp.dir, reader, .{
            .strip_components = 1,
            .diagnostics = &diagnostics,
        }) catch |err| {
            // Skip on platform which don't support symlinks
            if (err == error.UnableToCreateSymLink) return error.SkipZigTest;
            return err;
        };

        // there is no root_dir
        try testing.expectEqual(0, diagnostics.root_dir.len);
        try testing.expectEqual(5, diagnostics.entries);
    }

    // with strip_components = 0
    {
        fbs.reset();
        var tmp = testing.tmpDir(.{ .no_follow = true });
        defer tmp.cleanup();
        var diagnostics: Diagnostics = .{ .allocator = testing.allocator };
        defer diagnostics.deinit();

        pipeToFileSystem(tmp.dir, reader, .{
            .strip_components = 0,
            .diagnostics = &diagnostics,
        }) catch |err| {
            // Skip on platform which don't support symlinks
            if (err == error.UnableToCreateSymLink) return error.SkipZigTest;
            return err;
        };

        // root_dir found
        try testing.expectEqualStrings("example", diagnostics.root_dir);
        try testing.expectEqual(6, diagnostics.entries);
    }
}

test "findRoot without explicit root dir" {
    const data = @embedFile("tar/testdata/19820.tar");
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var diagnostics: Diagnostics = .{ .allocator = testing.allocator };
    defer diagnostics.deinit();
    try pipeToFileSystem(tmp.dir, reader, .{ .diagnostics = &diagnostics });

    try testing.expectEqualStrings("root", diagnostics.root_dir);
}

fn normalizePath(bytes: []u8) []u8 {
    const canonical_sep = std.fs.path.sep_posix;
    if (std.fs.path.sep == canonical_sep) return bytes;
    std.mem.replaceScalar(u8, bytes, std.fs.path.sep, canonical_sep);
    return bytes;
}

const default_mode = std.fs.File.default_mode;

// File system mode based on tar header mode and mode_mode options.
fn fileMode(mode: u32, options: PipeOptions) std.fs.File.Mode {
    if (!std.fs.has_executable_bit or options.mode_mode == .ignore)
        return default_mode;

    const S = std.posix.S;

    // The mode from the tar file is inspected for the owner executable bit.
    if (mode & S.IXUSR == 0)
        return default_mode;

    // This bit is copied to the group and other executable bits.
    // Other bits of the mode are left as the default when creating files.
    return default_mode | S.IXUSR | S.IXGRP | S.IXOTH;
}

test fileMode {
    if (!std.fs.has_executable_bit) return error.SkipZigTest;
    try testing.expectEqual(default_mode, fileMode(0o744, PipeOptions{ .mode_mode = .ignore }));
    try testing.expectEqual(0o777, fileMode(0o744, PipeOptions{}));
    try testing.expectEqual(0o666, fileMode(0o644, PipeOptions{}));
    try testing.expectEqual(0o666, fileMode(0o655, PipeOptions{}));
}

test "executable bit" {
    if (!std.fs.has_executable_bit) return error.SkipZigTest;

    const S = std.posix.S;
    const data = @embedFile("tar/testdata/example.tar");

    for ([_]PipeOptions.ModeMode{ .ignore, .executable_bit_only }) |opt| {
        var fbs = std.io.fixedBufferStream(data);
        const reader = fbs.reader();

        var tmp = testing.tmpDir(.{ .no_follow = true });
        //defer tmp.cleanup();

        pipeToFileSystem(tmp.dir, reader, .{
            .strip_components = 1,
            .exclude_empty_directories = true,
            .mode_mode = opt,
        }) catch |err| {
            // Skip on platform which don't support symlinks
            if (err == error.UnableToCreateSymLink) return error.SkipZigTest;
            return err;
        };

        const fs = try tmp.dir.statFile("a/file");
        try testing.expect(fs.kind == .file);

        if (opt == .executable_bit_only) {
            // Executable bit is set for user, group and others
            try testing.expect(fs.mode & S.IXUSR > 0);
            try testing.expect(fs.mode & S.IXGRP > 0);
            try testing.expect(fs.mode & S.IXOTH > 0);
        }
        if (opt == .ignore) {
            try testing.expect(fs.mode & S.IXUSR == 0);
            try testing.expect(fs.mode & S.IXGRP == 0);
            try testing.expect(fs.mode & S.IXOTH == 0);
        }
    }
}
