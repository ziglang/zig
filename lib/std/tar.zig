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

pub const Header = struct {
    bytes: *const [512]u8,

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
        _,
    };

    pub fn fileSize(header: Header) !u64 {
        const raw = header.bytes[124..][0..12];
        const ltrimmed = std.mem.trimLeft(u8, raw, "0 ");
        const rtrimmed = std.mem.trimRight(u8, ltrimmed, " \x00");
        if (rtrimmed.len == 0) return 0;
        return std.fmt.parseInt(u64, rtrimmed, 8);
    }

    pub fn is_ustar(header: Header) bool {
        return std.mem.eql(u8, header.bytes[257..][0..6], "ustar\x00");
    }

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
        return str(header, 0, 0 + 100);
    }

    pub fn linkName(header: Header) []const u8 {
        return str(header, 157, 157 + 100);
    }

    pub fn prefix(header: Header) []const u8 {
        return str(header, 345, 345 + 155);
    }

    pub fn fileType(header: Header) FileType {
        const result: FileType = @enumFromInt(header.bytes[156]);
        if (result == .normal_alias) return .normal;
        return result;
    }

    fn str(header: Header, start: usize, end: usize) []const u8 {
        var i: usize = start;
        while (i < end) : (i += 1) {
            if (header.bytes[i] == 0) break;
        }
        return header.bytes[start..i];
    }

    pub fn isZeroBlock(header: Header) bool {
        for (header.bytes) |b| {
            if (b != 0) return false;
        }
        return true;
    }
};

fn BufferedReader(comptime ReaderType: type) type {
    return struct {
        unbuffered_reader: ReaderType,
        buffer: [512 * 8]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        const Self = @This();

        pub fn readChunk(self: *Self, count: usize) ![]const u8 {
            self.ensureCapacity(1024);

            const ask = @min(self.buffer.len - self.end, count -| (self.end - self.start));
            self.end += try self.unbuffered_reader.readAtLeast(self.buffer[self.end..], ask);

            return self.buffer[self.start..self.end];
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

        inline fn ensureCapacity(self: *Self, count: usize) void {
            if (self.buffer.len - self.start < count) {
                const dest_end = self.end - self.start;
                @memcpy(self.buffer[0..dest_end], self.buffer[self.start..self.end]);
                self.end = dest_end;
                self.start = 0;
            }
        }

        pub fn write(self: *Self, writer: anytype, size: usize) !void {
            const rounded_file_size = std.mem.alignForward(usize, size, 512);
            const chunk_size = rounded_file_size + 512;
            const pad_len: usize = rounded_file_size - size;

            var file_off: usize = 0;
            while (true) {
                const temp = try self.readChunk(chunk_size - file_off);
                if (temp.len == 0) return error.UnexpectedEndOfStream;
                const slice = temp[0..@min(size - file_off, temp.len)];
                try writer.writeAll(slice);

                file_off += slice.len;
                self.advance(slice.len);
                if (file_off >= size) {
                    self.advance(pad_len);
                    return;
                }
            }
        }

        pub fn copy(self: *Self, dst_buffer: []u8, size: usize) !void {
            const rounded_file_size = std.mem.alignForward(usize, size, 512);
            const chunk_size = rounded_file_size + 512;

            var i: usize = 0;
            while (i < size) {
                const slice = try self.readChunk(chunk_size - i);
                if (slice.len == 0) return error.UnexpectedEndOfStream;
                const copy_size: usize = @min(size - i, slice.len);
                @memcpy(dst_buffer[i .. i + copy_size], slice[0..copy_size]);
                self.advance(copy_size);
                i += copy_size;
            }
        }
    };
}

fn Iterator(comptime ReaderType: type) type {
    return struct {
        file_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined,
        file_name_len: usize = 0,
        reader: BufferedReader(ReaderType),
        diagnostics: ?*Options.Diagnostics,

        const Self = @This();

        const File = struct {
            name: []const u8,
            link_name: []const u8,
            size: usize,
            file_type: Header.FileType,
            iter: *Self,

            pub fn write(self: File, writer: anytype) !void {
                try self.iter.reader.write(writer, self.size);
            }

            pub fn skip(self: File) !void {
                const rounded_file_size = std.mem.alignForward(usize, self.size, 512);
                try self.iter.reader.skip(rounded_file_size);
            }

            fn chksum(self: File) ![16]u8 {
                var cs = [_]u8{0} ** 16;
                if (self.size == 0) return cs;

                var buffer: [512]u8 = undefined;
                var h = std.crypto.hash.Md5.init(.{});

                var remaining_bytes: usize = self.size;
                while (remaining_bytes > 0) {
                    const copy_size = @min(buffer.len, remaining_bytes);
                    try self.iter.reader.copy(&buffer, copy_size);
                    h.update(buffer[0..copy_size]);
                    remaining_bytes -= copy_size;
                }
                h.final(&cs);
                try self.skipPadding();
                return cs;
            }

            fn skipPadding(self: File) !void {
                const rounded_file_size = std.mem.alignForward(usize, self.size, 512);
                const pad_len: usize = rounded_file_size - self.size;
                self.iter.reader.advance(pad_len);
            }
        };

        pub fn next(self: *Self) !?File {
            self.file_name_len = 0;
            while (true) {
                const chunk = try self.reader.readChunk(1024);
                switch (chunk.len) {
                    0 => return null,
                    1...511 => return error.UnexpectedEndOfStream,
                    else => {},
                }
                self.reader.advance(512);

                const header: Header = .{ .bytes = chunk[0..512] };
                if (header.isZeroBlock()) return null;
                const file_size = try header.fileSize();
                const file_type = header.fileType();
                const link_name = header.linkName();
                const rounded_file_size: usize = std.mem.alignForward(usize, file_size, 512);

                const file_name = if (self.file_name_len == 0)
                    try header.fullFileName(&self.file_name_buffer)
                else
                    self.file_name_buffer[0..self.file_name_len];

                switch (file_type) {
                    .directory, .normal, .symbolic_link => {
                        return File{
                            .name = file_name,
                            .size = file_size,
                            .file_type = file_type,
                            .link_name = link_name,
                            .iter = self,
                        };
                    },
                    .global_extended_header => {
                        self.reader.skip(rounded_file_size) catch return error.TarHeadersTooBig;
                    },
                    .extended_header => {
                        if (file_size == 0) continue;

                        const chunk_size: usize = rounded_file_size + 512;
                        var data_off: usize = 0;
                        const file_name_override_len = while (data_off < file_size) {
                            const slice = try self.reader.readChunk(chunk_size - data_off);
                            if (slice.len == 0) return error.UnexpectedEndOfStream;
                            const remaining_size: usize = file_size - data_off;
                            const attr_info = try parsePaxAttribute(slice[0..@min(remaining_size, slice.len)], remaining_size);

                            if (std.mem.eql(u8, attr_info.key, "path")) {
                                if (attr_info.value_len > self.file_name_buffer.len) return error.NameTooLong;
                                self.reader.advance(attr_info.value_off);
                                data_off += attr_info.value_off;
                                break attr_info.value_len;
                            }

                            try self.reader.skip(attr_info.size);
                            data_off += attr_info.size;
                        } else 0;

                        try self.reader.copy(&self.file_name_buffer, file_name_override_len);

                        try self.reader.skip(rounded_file_size - data_off - file_name_override_len);
                        self.file_name_len = file_name_override_len;
                        continue;
                    },
                    .hard_link => return error.TarUnsupportedFileType,
                    else => {
                        const d = self.diagnostics orelse return error.TarUnsupportedFileType;
                        try d.errors.append(d.allocator, .{ .unsupported_file_type = .{
                            .file_name = try d.allocator.dupe(u8, file_name),
                            .file_type = file_type,
                        } });
                    },
                }
            }
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
};

fn parsePaxAttribute(data: []const u8, max_size: usize) !PaxAttributeInfo {
    const pos_space = std.mem.indexOfScalar(u8, data, ' ') orelse return error.InvalidPaxAttribute;
    const pos_equals = std.mem.indexOfScalarPos(u8, data, pos_space, '=') orelse return error.InvalidPaxAttribute;
    const kv_size = try std.fmt.parseInt(usize, data[0..pos_space], 10);
    if (kv_size > max_size) {
        return error.InvalidPaxAttribute;
    }
    return .{
        .size = kv_size,
        .key = data[pos_space + 1 .. pos_equals],
        .value_off = pos_equals + 1,
        .value_len = kv_size - pos_equals - 2,
    };
}

test parsePaxAttribute {
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
}

const std = @import("std.zig");
const assert = std.debug.assert;

const TestCase = struct {
    const File = struct {
        const empty_string = &[0]u8{};

        name: []const u8,
        size: usize = 0,
        link_name: []const u8 = empty_string,
        file_type: Header.FileType = .normal,
    };

    path: []const u8,
    files: []const File = &[_]TestCase.File{},
    chksums: []const []const u8 = &[_][]const u8{},
    err: ?anyerror = null,
};

test "Go test cases" {
    const test_dir = try std.fs.openDirAbsolute("/usr/local/go/src/archive/tar/testdata", .{});
    const cases = [_]TestCase{
        .{
            .path = "gnu.tar",
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
            .path = "sparse-formats.tar",
            .err = error.TarUnsupportedFileType,
        },
        .{
            .path = "star.tar",
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
            .path = "v7.tar",
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
            .path = "pax.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "a/123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                    .size = 7,
                    .file_type = .normal,
                },
                .{
                    .name = "a/b",
                    .size = 0,
                    .file_type = .symbolic_link,
                    .link_name = "1234567891011121314151617181920212223242526272829303132333435363738394041424344454647484950515253545",
                    // TODO fix reading link name from pax header
                    // .link_name = "123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                },
            },
            .chksums = &[_][]const u8{
                "3c382e8f5b6631aa2db52643912ffd4a",
            },
        },
        // TODO: this should fail
        // .{
        //     .path = "pax-bad-hdr-file.tar",
        //     .err = error.TarBadHeader,
        // },
        // .{
        //     .path = "pax-bad-mtime-file.tar",
        //     .err = error.TarBadHeader,
        // },
        //
        // TODO: giving wrong result because we are not reading pax size header
        // .{
        //     .path = "pax-pos-size-file.tar",
        //     .files = &[_]TestCase.File{
        //         .{
        //             .name = "foo",
        //             .size = 999,
        //             .file_type = .normal,
        //         },
        //     },
        //     .chksums = &[_][]const u8{
        //         "0afb597b283fe61b5d4879669a350556",
        //     },
        // },
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
            .err = error.TarUnsupportedFileType,
        },
        .{
            .path = "gnu-incremental.tar",
            .err = error.TarUnsupportedFileType,
        },
        // .{
        //     .path = "pax-multi-hdrs.tar",
        // },
        // .{
        //     .path = "gnu-long-nul.tar",
        //     .files = &[_]TestCase.File{
        //         .{
        //             .name = "012233456789",
        //         },
        //     },
        // },
        // .{
        //     .path = "gnu-utf8.tar",
        //     .files = &[_]TestCase.File{
        //         .{
        //             .name = "012233456789",
        //         },
        //     },
        // },
        //
        .{
            .path = "gnu-not-utf8.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "hi\x80\x81\x82\x83bye",
                },
            },
        },
        // TODO some files with errors:
        // pax-nul-xattrs.tar, pax-nul-path.tar, neg-size.tar, issue10968.tar, issue11169.tar, issue12435.tar
        .{
            .path = "trailing-slash.tar",
            .files = &[_]TestCase.File{
                .{
                    .name = "123456789/" ** 30,
                    .file_type = .directory,
                },
            },
        },
    };

    for (cases) |case| {
        // if (!std.mem.eql(u8, case.path, "pax.tar")) continue;

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
                try actual.skip(); // skip file content
            }
            i += 1;
        }
        try std.testing.expectEqual(case.files.len, i);
    }
}
