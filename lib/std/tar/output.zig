/// A struct that is exactly 512 bytes and matches tar file format. This is
/// intended to be used for outputting tar files; for parsing there is
/// `std.tar.Header`.
pub const Header = extern struct {
    // This struct was originally copied from
    // https://github.com/mattnite/tar/blob/main/src/main.zig which is MIT
    // licensed.

    name: [100]u8,
    mode: [7:0]u8,
    uid: [7:0]u8,
    gid: [7:0]u8,
    size: [11:0]u8,
    mtime: [11:0]u8,
    checksum: [7:0]u8,
    typeflag: FileType,
    linkname: [100]u8,
    magic: [5:0]u8,
    version: [2]u8,
    uname: [31:0]u8,
    gname: [31:0]u8,
    devmajor: [7:0]u8,
    devminor: [7:0]u8,
    prefix: [155]u8,
    pad: [12]u8,

    pub const FileType = enum(u8) {
        regular = '0',
        hard_link = '1',
        symbolic_link = '2',
        character = '3',
        block = '4',
        directory = '5',
        fifo = '6',
        reserved = '7',
        pax_global = 'g',
        extended = 'x',
        gnu_long_name = 'L',
        gnu_long_link = 'K',
        _,
    };

    pub fn init() Header {
        var ret = std.mem.zeroes(Header);
        ret.magic = [_:0]u8{ 'u', 's', 't', 'a', 'r' };
        ret.version = [_:0]u8{ '0', '0' };
        return ret;
    }

    pub fn setPath(self: *Header, prefix: []const u8, path: []const u8) !void {
        if (prefix.len + 1 + path.len > 100) {
            var i: usize = 0;
            while (i < path.len and path.len - i > 100) {
                while (path[i] != '/') : (i += 1) {}
            }

            _ = try std.fmt.bufPrint(&self.prefix, "{s}/{s}", .{ prefix, path[0..i] });
            _ = try std.fmt.bufPrint(&self.name, "{s}", .{path[i + 1 ..]});
        } else {
            _ = try std.fmt.bufPrint(&self.name, "{s}/{s}", .{ prefix, path });
        }
    }

    pub fn setSize(self: *Header, size: u64) !void {
        _ = try std.fmt.bufPrint(&self.size, "{o:0>11}", .{size});
    }

    pub fn setMode(self: *Header, mode: u32) !void {
        _ = try std.fmt.bufPrint(&self.mode, "{o:0>7}", .{mode});
    }

    // Integer number of seconds since January 1, 1970, 00:00 Coordinated Universal Time.
    pub fn setMtime(self: *Header, mtime: u64) !void {
        _ = try std.fmt.bufPrint(&self.mtime, "{o:0>11}", .{mtime});
    }

    pub fn updateChecksum(self: *Header) !void {
        const offset = @offsetOf(Header, "checksum");
        var checksum: usize = 0;
        for (std.mem.asBytes(self), 0..) |val, i| {
            checksum += if (i >= offset and i < offset + @sizeOf(@TypeOf(self.checksum)))
                ' '
            else
                val;
        }

        _ = try std.fmt.bufPrint(&self.checksum, "{o:0>7}", .{checksum});
    }

    pub fn write(self: *Header, writer: anytype) !void {
        try self.updateChecksum();
        try writer.writeAll(std.mem.asBytes(self));
    }

    pub fn setLinkname(self: *Header, link: []const u8) !void {
        if (link.len > self.linkname.len) return error.NameTooLong;
        @memcpy(self.linkname[0..link.len], link);
    }

    pub fn setName(self: *Header, prefix: []const u8, sub_path: []const u8) !void {
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

        @memcpy(self.prefix[0..prefix.len], prefix);
        self.prefix[prefix.len] = sep;
        const prefix_pos = prefix.len + 1;

        // add as much to prefix as you can, must split at /
        const prefix_remaining = max_prefix - prefix_pos;
        if (std.mem.lastIndexOf(u8, sub_path[0..@min(prefix_remaining, sub_path.len)], &.{'/'})) |sep_pos| {
            @memcpy(self.prefix[prefix_pos..][0..sep_pos], sub_path[0..sep_pos]);
            if ((sub_path.len - sep_pos - 1) > max_name) return error.NameTooLong;
            @memcpy(self.name[0..][0 .. sub_path.len - sep_pos - 1], sub_path[sep_pos + 1 ..]);
            return;
        }

        if (prefix_remaining > sub_path.len) {
            @memcpy(self.prefix[prefix_pos..][0..sub_path.len], sub_path);
            return;
        }

        return error.NameTooLong;
    }

    comptime {
        assert(@sizeOf(Header) == 512);
    }

    test setName {
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
            // not separtaor is sub_path, but still all fits into prefix
            .{
                .in = &.{ "prefix", "0123456789" ** 13 ++ "basename" },
                .out = &.{ "prefix/" ++ "0123456789" ** 13 ++ "basename", "" },
            },
        };

        for (cases) |case| {
            var header = Header.init();
            try header.setName(case.in[0], case.in[1]);
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
            .{ .in = &.{ "prefix", "0123456789" ** 14 ++ "basename" } },
        };

        for (error_cases) |case| {
            var header = Header.init();
            try testing.expectError(
                error.NameTooLong,
                header.setName(case.in[0], case.in[1]),
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

pub const zero_header: [@sizeOf(Header)]u8 = .{0} ** @sizeOf(Header);

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

test {
    _ = Header;
}
