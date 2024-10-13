const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

/// Creates tar Writer which will write tar content to the `underlying_writer`.
/// Use setRoot to nest all following entries under single root. If file don't
/// fit into posix header (name+prefix: 100+155 bytes) gnu extented header will
/// be used for long names. Options enables setting file premission mode and
/// mtime. Default is to use current time for mtime and 0o664 for file mode.
pub fn writer(underlying_writer: anytype) Writer(@TypeOf(underlying_writer)) {
    return .{ .underlying_writer = underlying_writer };
}

pub fn Writer(comptime WriterType: type) type {
    return struct {
        const block_size = @sizeOf(Header);
        const empty_block: [block_size]u8 = [_]u8{0} ** block_size;

        /// Options for writing file/dir/link. If left empty 0o664 is used for
        /// file mode and current time for mtime.
        pub const Options = struct {
            /// File system permission mode.
            mode: u32 = 0,
            /// File system modification time.
            mtime: u64 = 0,
        };
        const Self = @This();

        underlying_writer: WriterType,
        prefix: []const u8 = "",
        mtime_now: u64 = 0,

        /// Sets prefix for all other write* method paths.
        pub fn setRoot(self: *Self, root: []const u8) !void {
            if (root.len > 0)
                try self.writeDir(root, .{});

            self.prefix = root;
        }

        /// Writes directory.
        pub fn writeDir(self: *Self, sub_path: []const u8, opt: Options) !void {
            try self.writeHeader(.directory, sub_path, "", 0, opt);
        }

        /// Writes file system file.
        pub fn writeFile(self: *Self, sub_path: []const u8, file: std.fs.File) !void {
            const stat = try file.stat();
            const mtime: u64 = @intCast(@divFloor(stat.mtime, std.time.ns_per_s));

            var header = Header{};
            try self.setPath(&header, sub_path);
            try header.setSize(stat.size);
            try header.setMtime(mtime);
            try header.write(self.underlying_writer);

            try self.underlying_writer.writeFile(file);
            try self.writePadding(stat.size);
        }

        /// Writes file reading file content from `reader`. Number of bytes in
        /// reader must be equal to `size`.
        pub fn writeFileStream(self: *Self, sub_path: []const u8, size: usize, reader: anytype, opt: Options) !void {
            try self.writeHeader(.regular, sub_path, "", @intCast(size), opt);

            var counting_reader = std.io.countingReader(reader);
            var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
            try fifo.pump(counting_reader.reader(), self.underlying_writer);
            if (counting_reader.bytes_read != size) return error.WrongReaderSize;
            try self.writePadding(size);
        }

        /// Writes file using bytes buffer `content` for size and file content.
        pub fn writeFileBytes(self: *Self, sub_path: []const u8, content: []const u8, opt: Options) !void {
            try self.writeHeader(.regular, sub_path, "", @intCast(content.len), opt);
            try self.underlying_writer.writeAll(content);
            try self.writePadding(content.len);
        }

        /// Writes symlink.
        pub fn writeLink(self: *Self, sub_path: []const u8, link_name: []const u8, opt: Options) !void {
            try self.writeHeader(.symbolic_link, sub_path, link_name, 0, opt);
        }

        /// Writes fs.Dir.WalkerEntry. Uses `mtime` from file system entry and
        /// default for entry mode .
        pub fn writeEntry(self: *Self, entry: std.fs.Dir.Walker.Entry) !void {
            switch (entry.kind) {
                .directory => {
                    try self.writeDir(entry.path, .{ .mtime = try entryMtime(entry) });
                },
                .file => {
                    var file = try entry.dir.openFile(entry.basename, .{});
                    defer file.close();
                    try self.writeFile(entry.path, file);
                },
                .sym_link => {
                    var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
                    const link_name = try entry.dir.readLink(entry.basename, &link_name_buffer);
                    try self.writeLink(entry.path, link_name, .{ .mtime = try entryMtime(entry) });
                },
                else => {
                    return error.UnsupportedWalkerEntryKind;
                },
            }
        }

        fn writeHeader(
            self: *Self,
            typeflag: Header.FileType,
            sub_path: []const u8,
            link_name: []const u8,
            size: u64,
            opt: Options,
        ) !void {
            var header = Header.init(typeflag);
            try self.setPath(&header, sub_path);
            try header.setSize(size);
            try header.setMtime(if (opt.mtime != 0) opt.mtime else self.mtimeNow());
            if (opt.mode != 0)
                try header.setMode(opt.mode);
            if (typeflag == .symbolic_link)
                header.setLinkname(link_name) catch |err| switch (err) {
                    error.NameTooLong => try self.writeExtendedHeader(.gnu_long_link, &.{link_name}),
                    else => return err,
                };
            try header.write(self.underlying_writer);
        }

        fn mtimeNow(self: *Self) u64 {
            if (self.mtime_now == 0)
                self.mtime_now = @intCast(std.time.timestamp());
            return self.mtime_now;
        }

        fn entryMtime(entry: std.fs.Dir.Walker.Entry) !u64 {
            const stat = try entry.dir.statFile(entry.basename);
            return @intCast(@divFloor(stat.mtime, std.time.ns_per_s));
        }

        /// Writes path in posix header, if don't fit (in name+prefix; 100+155
        /// bytes) writes it in gnu extended header.
        fn setPath(self: *Self, header: *Header, sub_path: []const u8) !void {
            header.setPath(self.prefix, sub_path) catch |err| switch (err) {
                error.NameTooLong => {
                    // write extended header
                    const buffers: []const []const u8 = if (self.prefix.len == 0)
                        &.{sub_path}
                    else
                        &.{ self.prefix, "/", sub_path };
                    try self.writeExtendedHeader(.gnu_long_name, buffers);
                },
                else => return err,
            };
        }

        /// Writes gnu extended header: gnu_long_name or gnu_long_link.
        fn writeExtendedHeader(self: *Self, typeflag: Header.FileType, buffers: []const []const u8) !void {
            var len: usize = 0;
            for (buffers) |buf|
                len += buf.len;

            var header = Header.init(typeflag);
            try header.setSize(len);
            try header.write(self.underlying_writer);
            for (buffers) |buf|
                try self.underlying_writer.writeAll(buf);
            try self.writePadding(len);
        }

        fn writePadding(self: *Self, bytes: u64) !void {
            const pos: usize = @intCast(bytes % block_size);
            if (pos == 0) return;
            try self.underlying_writer.writeAll(empty_block[pos..]);
        }

        /// Tar should finish with two zero blocks, but 'reasonable system must
        /// not assume that such a block exists when reading an archive' (from
        /// reference). In practice it is safe to skip this finish.
        pub fn finish(self: *Self) !void {
            try self.underlying_writer.writeAll(&empty_block);
            try self.underlying_writer.writeAll(&empty_block);
        }
    };
}

/// A struct that is exactly 512 bytes and matches tar file format. This is
/// intended to be used for outputting tar files; for parsing there is
/// `std.tar.Header`.
const Header = extern struct {
    // This struct was originally copied from
    // https://github.com/mattnite/tar/blob/main/src/main.zig which is MIT
    // licensed.
    //
    // The name, linkname, magic, uname, and gname are null-terminated character
    // strings. All other fields are zero-filled octal numbers in ASCII. Each
    // numeric field of width w contains w minus 1 digits, and a null.
    // Reference: https://www.gnu.org/software/tar/manual/html_node/Standard.html
    // POSIX header:                                  byte offset
    name: [100]u8 = [_]u8{0} ** 100, //                         0
    mode: [7:0]u8 = default_mode.file, //                     100
    uid: [7:0]u8 = [_:0]u8{0} ** 7, // unused                 108
    gid: [7:0]u8 = [_:0]u8{0} ** 7, // unused                 116
    size: [11:0]u8 = [_:0]u8{'0'} ** 11, //                   124
    mtime: [11:0]u8 = [_:0]u8{'0'} ** 11, //                  136
    checksum: [7:0]u8 = [_:0]u8{' '} ** 7, //                 148
    typeflag: FileType = .regular, //                         156
    linkname: [100]u8 = [_]u8{0} ** 100, //                   157
    magic: [6]u8 = [_]u8{ 'u', 's', 't', 'a', 'r', 0 }, //    257
    version: [2]u8 = [_]u8{ '0', '0' }, //                    263
    uname: [32]u8 = [_]u8{0} ** 32, // unused                 265
    gname: [32]u8 = [_]u8{0} ** 32, // unused                 297
    devmajor: [7:0]u8 = [_:0]u8{0} ** 7, // unused            329
    devminor: [7:0]u8 = [_:0]u8{0} ** 7, // unused            337
    prefix: [155]u8 = [_]u8{0} ** 155, //                     345
    pad: [12]u8 = [_]u8{0} ** 12, // unused                   500

    pub const FileType = enum(u8) {
        regular = '0',
        symbolic_link = '2',
        directory = '5',
        gnu_long_name = 'L',
        gnu_long_link = 'K',
    };

    const default_mode = struct {
        const file = [_:0]u8{ '0', '0', '0', '0', '6', '6', '4' }; // 0o664
        const dir = [_:0]u8{ '0', '0', '0', '0', '7', '7', '5' }; // 0o775
        const sym_link = [_:0]u8{ '0', '0', '0', '0', '7', '7', '7' }; // 0o777
        const other = [_:0]u8{ '0', '0', '0', '0', '0', '0', '0' }; // 0o000
    };

    pub fn init(typeflag: FileType) Header {
        return .{
            .typeflag = typeflag,
            .mode = switch (typeflag) {
                .directory => default_mode.dir,
                .symbolic_link => default_mode.sym_link,
                .regular => default_mode.file,
                else => default_mode.other,
            },
        };
    }

    pub fn setSize(self: *Header, size: u64) !void {
        try octal(&self.size, size);
    }

    fn octal(buf: []u8, value: u64) !void {
        var remainder: u64 = value;
        var pos: usize = buf.len;
        while (remainder > 0 and pos > 0) {
            pos -= 1;
            const c: u8 = @as(u8, @intCast(remainder % 8)) + '0';
            buf[pos] = c;
            remainder /= 8;
            if (pos == 0 and remainder > 0) return error.OctalOverflow;
        }
    }

    pub fn setMode(self: *Header, mode: u32) !void {
        try octal(&self.mode, mode);
    }

    // Integer number of seconds since January 1, 1970, 00:00 Coordinated Universal Time.
    // mtime == 0 will use current time
    pub fn setMtime(self: *Header, mtime: u64) !void {
        try octal(&self.mtime, mtime);
    }

    pub fn updateChecksum(self: *Header) !void {
        var checksum: usize = ' '; // other 7 self.checksum bytes are initialized to ' '
        for (std.mem.asBytes(self)) |val|
            checksum += val;
        try octal(&self.checksum, checksum);
    }

    pub fn write(self: *Header, output_writer: anytype) !void {
        try self.updateChecksum();
        try output_writer.writeAll(std.mem.asBytes(self));
    }

    pub fn setLinkname(self: *Header, link: []const u8) !void {
        if (link.len > self.linkname.len) return error.NameTooLong;
        @memcpy(self.linkname[0..link.len], link);
    }

    pub fn setPath(self: *Header, prefix: []const u8, sub_path: []const u8) !void {
        const max_prefix = self.prefix.len;
        const max_name = self.name.len;
        const sep = std.fs.path.sep_posix;

        if (prefix.len + sub_path.len > max_name + max_prefix or prefix.len > max_prefix)
            return error.NameTooLong;

        // both fit into name
        if (prefix.len > 0 and prefix.len + sub_path.len < max_name) {
            @memcpy(self.name[0..prefix.len], prefix);
            self.name[prefix.len] = sep;
            @memcpy(self.name[prefix.len + 1 ..][0..sub_path.len], sub_path);
            return;
        }

        // sub_path fits into name
        // there is no prefix or prefix fits into prefix
        if (sub_path.len <= max_name) {
            @memcpy(self.name[0..sub_path.len], sub_path);
            @memcpy(self.prefix[0..prefix.len], prefix);
            return;
        }

        if (prefix.len > 0) {
            @memcpy(self.prefix[0..prefix.len], prefix);
            self.prefix[prefix.len] = sep;
        }
        const prefix_pos = if (prefix.len > 0) prefix.len + 1 else 0;

        // add as much to prefix as you can, must split at /
        const prefix_remaining = max_prefix - prefix_pos;
        if (std.mem.lastIndexOf(u8, sub_path[0..@min(prefix_remaining, sub_path.len)], &.{'/'})) |sep_pos| {
            @memcpy(self.prefix[prefix_pos..][0..sep_pos], sub_path[0..sep_pos]);
            if ((sub_path.len - sep_pos - 1) > max_name) return error.NameTooLong;
            @memcpy(self.name[0..][0 .. sub_path.len - sep_pos - 1], sub_path[sep_pos + 1 ..]);
            return;
        }

        return error.NameTooLong;
    }

    comptime {
        assert(@sizeOf(Header) == 512);
    }

    test setPath {
        const cases = [_]struct {
            in: []const []const u8,
            out: []const []const u8,
        }{
            .{
                .in = &.{ "", "123456789" },
                .out = &.{ "", "123456789" },
            },
            // can fit into name
            .{
                .in = &.{ "prefix", "sub_path" },
                .out = &.{ "", "prefix/sub_path" },
            },
            // no more both fits into name
            .{
                .in = &.{ "prefix", "0123456789/" ** 8 ++ "basename" },
                .out = &.{ "prefix", "0123456789/" ** 8 ++ "basename" },
            },
            // put as much as you can into prefix the rest goes into name
            .{
                .in = &.{ "prefix", "0123456789/" ** 10 ++ "basename" },
                .out = &.{ "prefix/" ++ "0123456789/" ** 9 ++ "0123456789", "basename" },
            },

            .{
                .in = &.{ "prefix", "0123456789/" ** 15 ++ "basename" },
                .out = &.{ "prefix/" ++ "0123456789/" ** 12 ++ "0123456789", "0123456789/0123456789/basename" },
            },
            .{
                .in = &.{ "prefix", "0123456789/" ** 21 ++ "basename" },
                .out = &.{ "prefix/" ++ "0123456789/" ** 12 ++ "0123456789", "0123456789/" ** 8 ++ "basename" },
            },
            .{
                .in = &.{ "", "012345678/" ** 10 ++ "foo" },
                .out = &.{ "012345678/" ** 9 ++ "012345678", "foo" },
            },
        };

        for (cases) |case| {
            var header = Header.init(.regular);
            try header.setPath(case.in[0], case.in[1]);
            try testing.expectEqualStrings(case.out[0], str(&header.prefix));
            try testing.expectEqualStrings(case.out[1], str(&header.name));
        }

        const error_cases = [_]struct {
            in: []const []const u8,
        }{
            // basename can't fit into name (106 characters)
            .{ .in = &.{ "zig", "test/cases/compile_errors/regression_test_2980_base_type_u32_is_not_type_checked_properly_when_assigning_a_value_within_a_struct.zig" } },
            // cant fit into 255 + sep
            .{ .in = &.{ "prefix", "0123456789/" ** 22 ++ "basename" } },
            // can fit but sub_path can't be split (there is no separator)
            .{ .in = &.{ "prefix", "0123456789" ** 10 ++ "a" } },
            .{ .in = &.{ "prefix", "0123456789" ** 14 ++ "basename" } },
        };

        for (error_cases) |case| {
            var header = Header.init(.regular);
            try testing.expectError(
                error.NameTooLong,
                header.setPath(case.in[0], case.in[1]),
            );
        }
    }

    // Breaks string on first null character.
    fn str(s: []const u8) []const u8 {
        for (s, 0..) |c, i| {
            if (c == 0) return s[0..i];
        }
        return s;
    }
};

test {
    _ = Header;
}

test "write files" {
    const files = [_]struct {
        path: []const u8,
        content: []const u8,
    }{
        .{ .path = "foo", .content = "bar" },
        .{ .path = "a12345678/" ** 10 ++ "foo", .content = "a" ** 511 },
        .{ .path = "b12345678/" ** 24 ++ "foo", .content = "b" ** 512 },
        .{ .path = "c12345678/" ** 25 ++ "foo", .content = "c" ** 513 },
        .{ .path = "d12345678/" ** 51 ++ "foo", .content = "d" ** 1025 },
        .{ .path = "e123456789" ** 11, .content = "e" },
    };

    var file_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;

    // with root
    {
        const root = "root";

        var output = std.ArrayList(u8).init(testing.allocator);
        defer output.deinit();
        var wrt = writer(output.writer());
        try wrt.setRoot(root);
        for (files) |file|
            try wrt.writeFileBytes(file.path, file.content, .{});

        var input = std.io.fixedBufferStream(output.items);
        var iter = std.tar.iterator(
            input.reader(),
            .{ .file_name_buffer = &file_name_buffer, .link_name_buffer = &link_name_buffer },
        );

        // first entry is directory with prefix
        {
            const actual = (try iter.next()).?;
            try testing.expectEqualStrings(root, actual.name);
            try testing.expectEqual(std.tar.FileKind.directory, actual.kind);
        }

        var i: usize = 0;
        while (try iter.next()) |actual| {
            defer i += 1;
            const expected = files[i];
            try testing.expectEqualStrings(root, actual.name[0..root.len]);
            try testing.expectEqual('/', actual.name[root.len..][0]);
            try testing.expectEqualStrings(expected.path, actual.name[root.len + 1 ..]);

            var content = std.ArrayList(u8).init(testing.allocator);
            defer content.deinit();
            try actual.writeAll(content.writer());
            try testing.expectEqualSlices(u8, expected.content, content.items);
        }
    }
    // without root
    {
        var output = std.ArrayList(u8).init(testing.allocator);
        defer output.deinit();
        var wrt = writer(output.writer());
        for (files) |file| {
            var content = std.io.fixedBufferStream(file.content);
            try wrt.writeFileStream(file.path, file.content.len, content.reader(), .{});
        }

        var input = std.io.fixedBufferStream(output.items);
        var iter = std.tar.iterator(
            input.reader(),
            .{ .file_name_buffer = &file_name_buffer, .link_name_buffer = &link_name_buffer },
        );

        var i: usize = 0;
        while (try iter.next()) |actual| {
            defer i += 1;
            const expected = files[i];
            try testing.expectEqualStrings(expected.path, actual.name);

            var content = std.ArrayList(u8).init(testing.allocator);
            defer content.deinit();
            try actual.writeAll(content.writer());
            try testing.expectEqualSlices(u8, expected.content, content.items);
        }
        try wrt.finish();
    }
}
