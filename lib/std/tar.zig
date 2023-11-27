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
};

const Buffer = struct {
    buffer: [512 * 8]u8 = undefined,
    start: usize = 0,
    end: usize = 0,

    pub fn readChunk(b: *Buffer, reader: anytype, count: usize) ![]const u8 {
        b.ensureCapacity(1024);

        const ask = @min(b.buffer.len - b.end, count -| (b.end - b.start));
        b.end += try reader.readAtLeast(b.buffer[b.end..], ask);

        return b.buffer[b.start..b.end];
    }

    pub fn advance(b: *Buffer, count: usize) void {
        b.start += count;
        assert(b.start <= b.end);
    }

    pub fn skip(b: *Buffer, reader: anytype, count: usize) !void {
        if (b.start + count > b.end) {
            try reader.skipBytes(b.start + count - b.end, .{});
            b.start = b.end;
        } else {
            b.advance(count);
        }
    }

    inline fn ensureCapacity(b: *Buffer, count: usize) void {
        if (b.buffer.len - b.start < count) {
            const dest_end = b.end - b.start;
            @memcpy(b.buffer[0..dest_end], b.buffer[b.start..b.end]);
            b.end = dest_end;
            b.start = 0;
        }
    }
};

fn Iterator(comptime ReaderType: type) type {
    return struct {
        file_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined,
        file_name_len: usize = 0,
        buffer: Buffer = .{},
        reader: ReaderType,
        pad_len: usize = 0,
        diagnostics: ?*Options.Diagnostics,

        const Self = @This();

        const File = struct {
            file_name: []const u8,
            link_name: []const u8,
            size: usize,
            file_type: Header.FileType,
            iter: *Self,

            pub fn write(self: File, writer: anytype) !void {
                const rounded_file_size = std.mem.alignForward(u64, self.size, 512);
                var file_off: usize = 0;
                while (true) {
                    const temp = try self.iter.buffer.readChunk(self.iter.reader, @intCast(rounded_file_size + 512 - file_off));
                    if (temp.len == 0) return error.UnexpectedEndOfStream;
                    const slice = temp[0..@intCast(@min(self.size - file_off, temp.len))];
                    try writer.writeAll(slice);

                    file_off += slice.len;
                    self.iter.buffer.advance(slice.len);
                    if (file_off >= self.size) {
                        return;
                        //     self.iter.buffer.advance(pad_len);
                        //     continue :header;
                    }
                }
            }

            pub fn skip(self: File) void {
                _ = self;
                unreachable;
            }
        };

        pub fn next(self: *Self) !?File {
            self.buffer.advance(self.pad_len);
            self.pad_len = 0;
            self.file_name_len = 0;

            while (true) {
                const chunk = try self.buffer.readChunk(self.reader, 1024);
                switch (chunk.len) {
                    0 => return null,
                    1...511 => return error.UnexpectedEndOfStream,
                    else => {},
                }
                self.buffer.advance(512);

                const header: Header = .{ .bytes = chunk[0..512] };
                const file_size = try header.fileSize();
                const file_type = header.fileType();
                const link_name = header.linkName();
                const rounded_file_size = std.mem.alignForward(u64, file_size, 512);
                self.pad_len = @intCast(rounded_file_size - file_size);
                const file_name = if (self.file_name_len == 0)
                    try header.fullFileName(&self.file_name_buffer)
                else
                    self.file_name_buffer[0..self.file_name_len];

                switch (file_type) {
                    .directory, .normal, .symbolic_link => {
                        return File{
                            .file_name = file_name,
                            .link_name = link_name,
                            .size = file_size,
                            .file_type = file_type,
                            .iter = self,
                        };
                    },
                    .global_extended_header => {
                        self.buffer.skip(self.reader, @intCast(rounded_file_size)) catch return error.TarHeadersTooBig;
                    },
                    .extended_header => {
                        if (file_size == 0) {
                            self.buffer.advance(@intCast(rounded_file_size));
                            continue;
                        }

                        const chunk_size: usize = @intCast(rounded_file_size + 512);
                        var data_off: usize = 0;
                        const file_name_override_len = while (data_off < file_size) {
                            const slice = try self.buffer.readChunk(self.reader, chunk_size - data_off);
                            if (slice.len == 0) return error.UnexpectedEndOfStream;
                            const remaining_size: usize = @intCast(file_size - data_off);
                            const attr_info = try parsePaxAttribute(slice[0..@min(remaining_size, slice.len)], remaining_size);

                            if (std.mem.eql(u8, attr_info.key, "path")) {
                                if (attr_info.value_len > self.file_name_buffer.len) return error.NameTooLong;
                                self.buffer.advance(attr_info.value_off);
                                data_off += attr_info.value_off;
                                break attr_info.value_len;
                            }

                            try self.buffer.skip(self.reader, attr_info.size);
                            data_off += attr_info.size;
                        } else 0;

                        var i: usize = 0;
                        while (i < file_name_override_len) {
                            const slice = try self.buffer.readChunk(self.reader, chunk_size - data_off - i);
                            if (slice.len == 0) return error.UnexpectedEndOfStream;
                            const copy_size: usize = @intCast(@min(file_name_override_len - i, slice.len));
                            @memcpy(self.file_name_buffer[i .. i + copy_size], slice[0..copy_size]);
                            self.buffer.advance(copy_size);
                            i += copy_size;
                        }

                        try self.buffer.skip(self.reader, @intCast(rounded_file_size - data_off - file_name_override_len));
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
    return .{ .reader = reader, .diagnostics = diagnostics };
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

    while (try iter.next()) |iter_file| {
        switch (iter_file.file_type) {
            .directory => {
                const file_name = try stripComponents(iter_file.file_name, options.strip_components);
                if (file_name.len != 0 and !options.exclude_empty_directories) {
                    try dir.makePath(file_name);
                }
            },
            .normal => {
                if (iter_file.size == 0 and iter_file.file_name.len == 0) return;
                const file_name = try stripComponents(iter_file.file_name, options.strip_components);

                const file = dir.createFile(file_name, .{}) catch |err| switch (err) {
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
                defer if (file) |f| f.close();

                if (file) |f| {
                    try iter_file.write(f);
                } else {
                    iter_file.skip();
                }
            },
            .symbolic_link => {
                // The file system path of the symbolic link.
                const file_name = try stripComponents(iter_file.file_name, options.strip_components);
                // The data inside the symbolic link.
                const link_name = iter_file.link_name;

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
