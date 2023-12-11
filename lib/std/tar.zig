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
///
//const std = @import("std.zig");
const std = @import("std");
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
                file_type: Header.Kind,
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

pub const Header = struct {
    const SIZE = 512;
    const MAX_NAME_SIZE = 100 + 1 + 155; // name(100) + separator(1) + prefix(155)
    const LINK_NAME_SIZE = 100;

    bytes: *const [SIZE]u8,

    pub const Kind = enum(u8) {
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
    pub fn fullName(header: Header, buffer: *[MAX_NAME_SIZE]u8) ![]const u8 {
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

    pub fn linkName(header: Header, buffer: *[LINK_NAME_SIZE]u8) []const u8 {
        const link_name = header.str(157, 100);
        if (link_name.len == 0) {
            return buffer[0..0];
        }
        const buf = buffer[0..link_name.len];
        @memcpy(buf, link_name);
        return buf;
    }

    pub fn name(header: Header) []const u8 {
        return header.str(0, 100);
    }

    pub fn mode(header: Header) !u32 {
        return @intCast(try header.numeric(100, 8));
    }

    pub fn size(header: Header) !u64 {
        return header.numeric(124, 12);
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

    var iter = tarReader(reader, options.diagnostics);

    while (try iter.next()) |file| {
        switch (file.kind) {
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

test "tar run Go test cases" {
    const Case = struct {
        const File = struct {
            name: []const u8,
            size: usize = 0,
            mode: u32 = 0,
            link_name: []const u8 = &[0]u8{},
            kind: Header.Kind = .normal,
            truncated: bool = false, // when there is no file body, just header, usefull for huge files
        };

        path: []const u8, // path to the tar archive file on dis
        files: []const File = &[_]@This().File{}, // expected files to found in archive
        chksums: []const []const u8 = &[_][]const u8{}, // chksums of files content
        err: ?anyerror = null, // parsing should fail with this error
    };

    const test_dir = if (std.os.getenv("GO_TAR_TESTDATA_PATH")) |path|
        try std.fs.openDirAbsolute(path, .{})
    else
        return error.SkipZigTest;

    const cases = [_]Case{
        .{
            .path = "gnu.tar",
            .files = &[_]Case.File{
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
            .err = error.TarUnsupportedHeader,
        },
        .{
            .path = "star.tar",
            .files = &[_]Case.File{
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
            .files = &[_]Case.File{
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
            .files = &[_]Case.File{
                .{
                    .name = "a/123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                    .size = 7,
                    .mode = 0o664,
                },
                .{
                    .name = "a/b",
                    .size = 0,
                    .kind = .symbolic_link,
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
            .err = error.PaxInvalidAttributeEnd,
        },
        .{
            // size is in pax attribute
            .path = "pax-pos-size-file.tar",
            .files = &[_]Case.File{
                .{
                    .name = "foo",
                    .size = 999,
                    .kind = .normal,
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
            .files = &[_]Case.File{
                .{
                    .name = "file",
                },
            },
        },
        .{
            // has global records which we are ignoring
            .path = "pax-global-records.tar",
            .files = &[_]Case.File{
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
            .files = &[_]Case.File{
                .{
                    .name = "P1050238.JPG.log",
                    .size = 14,
                    .kind = .normal,
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
            .files = &[_]Case.File{
                .{
                    .name = "small.txt",
                    .size = 5,
                    .kind = .normal,
                    .mode = 0o644,
                },
                .{
                    .name = "small2.txt",
                    .size = 11,
                    .kind = .normal,
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
            .files = &[_]Case.File{
                .{
                    .name = "GNU2/GNU2/long-path-name",
                    .link_name = "GNU4/GNU4/long-linkpath-name",
                    .kind = .symbolic_link,
                },
            },
        },
        .{
            // has gnu type D (directory) and S (sparse) blocks
            .path = "gnu-incremental.tar",
            .err = error.TarUnsupportedHeader,
        },
        .{
            // should use values only from last pax header
            .path = "pax-multi-hdrs.tar",
            .files = &[_]Case.File{
                .{
                    .name = "bar",
                    .link_name = "PAX4/PAX4/long-linkpath-name",
                    .kind = .symbolic_link,
                },
            },
        },
        .{
            .path = "gnu-long-nul.tar",
            .files = &[_]Case.File{
                .{
                    .name = "0123456789",
                    .mode = 0o644,
                },
            },
        },
        .{
            .path = "gnu-utf8.tar",
            .files = &[_]Case.File{
                .{
                    .name = "☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹",
                    .mode = 0o644,
                },
            },
        },
        .{
            .path = "gnu-not-utf8.tar",
            .files = &[_]Case.File{
                .{
                    .name = "hi\x80\x81\x82\x83bye",
                    .mode = 0o644,
                },
            },
        },
        .{
            // null in pax key
            .path = "pax-nul-xattrs.tar",
            .err = error.PaxNullInKeyword,
        },
        .{
            .path = "pax-nul-path.tar",
            .err = error.PaxNullInValue,
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
            .files = &[_]Case.File{
                .{
                    .name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/foo",
                },
            },
        },
        .{
            .path = "ustar-file-devs.tar",
            .files = &[_]Case.File{
                .{
                    .name = "file",
                    .mode = 0o644,
                },
            },
        },
        .{
            .path = "trailing-slash.tar",
            .files = &[_]Case.File{
                .{
                    .name = "123456789/" ** 30,
                    .kind = .directory,
                },
            },
        },
        .{
            // Has size in gnu extended format. To represent size bigger than 8 GB.
            .path = "writer-big.tar",
            .files = &[_]Case.File{
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
            .files = &[_]Case.File{
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

        //var iter = iterator(fs_file.reader(), null);
        var iter = tarReader(fs_file.reader(), null);
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
            try std.testing.expectEqual(expected.kind, actual.kind);
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

    pub fn writeByte(self: *Md5Writer, byte: u8) !void {
        self.h.update(&[_]u8{byte});
    }

    pub fn chksum(self: *Md5Writer) [32]u8 {
        var s = [_]u8{0} ** 16;
        self.h.final(&s);
        return std.fmt.bytesToHex(s, .lower);
    }
};

fn paxReader(reader: anytype, size: usize) PaxReader(@TypeOf(reader)) {
    return PaxReader(@TypeOf(reader)){
        .reader = reader,
        .size = size,
    };
}

const PaxAttributeKind = enum {
    path,
    linkpath,
    size,
};

fn PaxReader(comptime ReaderType: type) type {
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
                assert(self.len <= dst.len);
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
                return Attribute{
                    .kind = kind,
                    .len = value_len,
                    .reader = self.reader,
                };
            }

            return null;
        }

        inline fn readUntil(self: *Self, delimiter: u8) ![]const u8 {
            var fbs = std.io.fixedBufferStream(&self.scratch);
            try self.reader.streamUntilDelimiter(fbs.writer(), delimiter, null);
            return fbs.getWritten();
        }

        inline fn eql(a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }

        inline fn hasNull(str: []const u8) bool {
            return (std.mem.indexOfScalar(u8, str, 0)) != null;
        }

        // Checks that each record ends with new line.
        inline fn validateAttributeEnding(reader: ReaderType) !void {
            if (try reader.readByte() != '\n') return error.PaxInvalidAttributeEnd;
        }
    };
}

test "tar PaxReader" {
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
        var rdr = paxReader(stream.reader(), case.data.len);

        var i: usize = 0;
        while (rdr.next() catch |err| {
            if (case.err) |e| {
                try std.testing.expectEqual(e, err);
                continue;
            }
            return err;
        }) |attr| : (i += 1) {
            const exp = case.attrs[i];
            try std.testing.expectEqual(exp.kind, attr.kind);
            const value = attr.value(&buffer) catch |err| {
                if (exp.err) |e| {
                    try std.testing.expectEqual(e, err);
                    break :outer;
                }
                return err;
            };
            try std.testing.expectEqualStrings(exp.value, value);
        }
        try std.testing.expectEqual(case.attrs.len, i);
        try std.testing.expect(case.err == null);
    }
}

pub fn tarReader(reader: anytype, diagnostics: ?*Options.Diagnostics) TarReader(@TypeOf(reader)) {
    return .{
        .reader = reader,
        .diagnostics = diagnostics,
    };
}

fn TarReader(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        diagnostics: ?*Options.Diagnostics,

        // buffers for heeader and file attributes
        header_buffer: [Header.SIZE]u8 = undefined,
        file_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined,
        link_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined,

        // bytes of padding to the end of the block
        padding: usize = 0,
        // current tar file
        file: File = undefined,

        pub const File = struct {
            name: []const u8, // name of file, symlink or directory
            link_name: []const u8, // target name of symlink
            size: usize, // size of the file in bytes
            mode: u32,
            kind: Header.Kind,

            reader: ReaderType,

            // Writes file content to writer.
            pub fn write(self: File, writer: anytype) !void {
                var buffer: [4096]u8 = undefined;

                var n: usize = 0;
                while (n < self.size) {
                    const buf = buffer[0..@min(buffer.len, self.size - n)];
                    try self.reader.readNoEof(buf);
                    try writer.writeAll(buf);
                    n += buf.len;
                }
            }

            // Skips file content. Advances reader.
            pub fn skip(self: File) !void {
                try self.reader.skipBytes(self.size, .{});
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

        inline fn readString(self: *Self, size: usize, buffer: []u8) ![]const u8 {
            assert(buffer.len >= size);
            const buf = buffer[0..size];
            try self.reader.readNoEof(buf);
            return nullStr(buf);
        }

        inline fn initFile(self: *Self) void {
            self.file = File{
                .name = self.file_name_buffer[0..0],
                .link_name = self.link_name_buffer[0..0],
                .size = 0,
                .kind = .normal,
                .mode = 0,
                .reader = self.reader,
            };
        }

        // Number of padding bytes in the last file block.
        inline fn blockPadding(size: usize) usize {
            const block_rounded = std.mem.alignForward(usize, size, Header.SIZE); // size rounded to te block boundary
            return block_rounded - size;
        }

        // Externally, `next` iterates through the tar archive as if it is a
        // series of files. Internally, the tar format often uses fake "files"
        // to add meta data that describes the next file. These meta data
        // "files" should not normally be visible to the outside. As such, this
        // loop iterates through one or more "header files" until it finds a
        // "normal file".
        pub fn next(self: *Self) !?File {
            self.initFile();

            while (try self.readHeader()) |header| {
                const kind = header.kind();
                const size: usize = @intCast(try header.size());
                self.padding = blockPadding(size);

                switch (kind) {
                    // File types to retrun upstream
                    .directory, .normal, .symbolic_link => {
                        self.file.kind = kind;
                        self.file.mode = try header.mode();

                        // set file attributes if not already set by prefix/extended headers
                        if (self.file.size == 0) {
                            self.file.size = size;
                        }
                        if (self.file.link_name.len == 0) {
                            self.file.link_name = header.linkName(self.link_name_buffer[0..Header.LINK_NAME_SIZE]);
                        }
                        if (self.file.name.len == 0) {
                            self.file.name = try header.fullName(self.file_name_buffer[0..Header.MAX_NAME_SIZE]);
                        }

                        self.padding = blockPadding(self.file.size);
                        return self.file;
                    },
                    // Prefix header types
                    .gnu_long_name => {
                        self.file.name = try self.readString(size, &self.file_name_buffer);
                    },
                    .gnu_long_link => {
                        self.file.link_name = try self.readString(size, &self.link_name_buffer);
                    },
                    .extended_header => {
                        // Use just attributes from last extended header.
                        self.initFile();

                        var rdr = paxReader(self.reader, size);
                        while (try rdr.next()) |attr| {
                            switch (attr.kind) {
                                .path => {
                                    self.file.name = try attr.value(&self.file_name_buffer);
                                },
                                .linkpath => {
                                    self.file.link_name = try attr.value(&self.link_name_buffer);
                                },
                                .size => {
                                    var buf: [64]u8 = undefined;
                                    self.file.size = try std.fmt.parseInt(usize, try attr.value(&buf), 10);
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
                    },
                }
            }
            return null;
        }
    };
}
