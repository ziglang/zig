//! SOCKS5 Username and Password Authentication.
const std = @import("std");

pub const Authenticate = struct {
    ver: u8 = 5,
    id: []const u8,
    password: []const u8,

    pub fn serialize(self: Authenticate, writer: anytype) !usize {
        var sz: usize = 0;
        sz += try writer.write(&.{ self.ver, @intCast(self.id.len) });
        sz += try writer.write(self.id);
        sz += try writer.write(&.{@intCast(self.password.len)});
        sz += try writer.write(self.password);

        return sz;
    }
};

pub const Response = struct {
    ver: u8 = 5,
    status: u8,

    pub fn isSuccess(self: Response) bool {
        return self.status == 0;
    }

    pub fn deserialize(reader: anytype) !Response {
        const ver = try reader.readByte();
        if (ver != 5) {
            return .{ .ver = ver, .status = 1 };
        }
        const status = try reader.readByte();
        return .{ .ver = ver, .status = status };
    }
};
