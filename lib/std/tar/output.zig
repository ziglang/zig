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

    comptime {
        assert(@sizeOf(Header) == 512);
    }
};

const std = @import("../std.zig");
const assert = std.debug.assert;
