pub const Options = struct {
    /// Number of directory levels to skip when extracting files.
    strip_components: u32 = 0,
    /// How to handle the "mode" property of files from within the tar file.
    mode_mode: ModeMode = .executable_bit_only,

    const ModeMode = enum {
        /// The mode from the tar file is completely ignored. Files are created
        /// with the default mode when creating files.
        ignore,
        /// The mode from the tar file is inspected for the owner executable bit
        /// only. This bit is copied to the group and other executable bits.
        /// Other bits of the mode are left as the default when creating files.
        executable_bit_only,
    };
};

pub const Header = struct {
    bytes: *const [512]u8,

    pub const FileType = enum(u8) {
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
        const ltrimmed = std.mem.trimLeft(u8, raw, "0");
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

    pub fn prefix(header: Header) []const u8 {
        return str(header, 345, 345 + 155);
    }

    pub fn fileType(header: Header) FileType {
        const result = @as(FileType, @enumFromInt(header.bytes[156]));
        return if (result == @as(FileType, @enumFromInt(0))) .normal else result;
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
    var file_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var file_name_override_len: usize = 0;
    var buffer: Buffer = .{};
    header: while (true) {
        const chunk = try buffer.readChunk(reader, 1024);
        switch (chunk.len) {
            0 => return,
            1...511 => return error.UnexpectedEndOfStream,
            else => {},
        }
        buffer.advance(512);

        const header: Header = .{ .bytes = chunk[0..512] };
        const file_size = try header.fileSize();
        const rounded_file_size = std.mem.alignForward(u64, file_size, 512);
        const pad_len = @as(usize, @intCast(rounded_file_size - file_size));
        const unstripped_file_name = if (file_name_override_len > 0)
            file_name_buffer[0..file_name_override_len]
        else
            try header.fullFileName(&file_name_buffer);
        file_name_override_len = 0;
        switch (header.fileType()) {
            .directory => {
                const file_name = try stripComponents(unstripped_file_name, options.strip_components);
                if (file_name.len != 0) {
                    try dir.makePath(file_name);
                }
            },
            .normal => {
                if (file_size == 0 and unstripped_file_name.len == 0) return;
                const file_name = try stripComponents(unstripped_file_name, options.strip_components);

                if (std.fs.path.dirname(file_name)) |dir_name| {
                    try dir.makePath(dir_name);
                }
                var file = try dir.createFile(file_name, .{});
                defer file.close();

                var file_off: usize = 0;
                while (true) {
                    const temp = try buffer.readChunk(reader, @intCast(rounded_file_size + 512 - file_off));
                    if (temp.len == 0) return error.UnexpectedEndOfStream;
                    const slice = temp[0..@as(usize, @intCast(@min(file_size - file_off, temp.len)))];
                    try file.writeAll(slice);

                    file_off += slice.len;
                    buffer.advance(slice.len);
                    if (file_off >= file_size) {
                        buffer.advance(pad_len);
                        continue :header;
                    }
                }
            },
            .extended_header => {
                if (file_size == 0) {
                    buffer.advance(@intCast(rounded_file_size));
                    continue;
                }

                const chunk_size: usize = @intCast(rounded_file_size + 512);
                var data_off: usize = 0;
                file_name_override_len = while (data_off < file_size) {
                    const slice = try buffer.readChunk(reader, chunk_size - data_off);
                    if (slice.len == 0) return error.UnexpectedEndOfStream;
                    const remaining_size: usize = @intCast(file_size - data_off);
                    const attr_info = try parsePaxAttribute(slice[0..@min(remaining_size, slice.len)], remaining_size);

                    if (std.mem.eql(u8, attr_info.key, "path")) {
                        if (attr_info.value_len > file_name_buffer.len) return error.NameTooLong;
                        buffer.advance(attr_info.value_off);
                        data_off += attr_info.value_off;
                        break attr_info.value_len;
                    }

                    try buffer.skip(reader, attr_info.size);
                    data_off += attr_info.size;
                } else 0;

                var i: usize = 0;
                while (i < file_name_override_len) {
                    const slice = try buffer.readChunk(reader, chunk_size - data_off - i);
                    if (slice.len == 0) return error.UnexpectedEndOfStream;
                    const copy_size: usize = @intCast(@min(file_name_override_len - i, slice.len));
                    @memcpy(file_name_buffer[i .. i + copy_size], slice[0..copy_size]);
                    buffer.advance(copy_size);
                    i += copy_size;
                }

                try buffer.skip(reader, @intCast(rounded_file_size - data_off - file_name_override_len));
                continue :header;
            },
            .global_extended_header => {
                buffer.skip(reader, @intCast(rounded_file_size)) catch return error.TarHeadersTooBig;
            },
            .hard_link => return error.TarUnsupportedFileType,
            .symbolic_link => return error.TarUnsupportedFileType,
            else => return error.TarUnsupportedFileType,
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
