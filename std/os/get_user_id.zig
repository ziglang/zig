const builtin = @import("builtin");
const Os = builtin.Os;
const os = @import("index.zig");
const io = @import("../io.zig");

pub const UserInfo = struct {
    uid: u32,
    gid: u32,
};

/// POSIX function which gets a uid from username.
pub fn getUserInfo(name: []const u8) !UserInfo {
    return switch (builtin.os) {
        Os.linux, Os.macosx, Os.ios => posixGetUserInfo(name),
        else => @compileError("Unsupported OS"),
    };
}

const State = enum {
    Start,
    WaitForNextLine,
    SkipPassword,
    ReadUserId,
    ReadGroupId,
};

// TODO this reads /etc/passwd. But sometimes the user/id mapping is in something else
// like NIS, AD, etc. See `man nss` or look at an strace for `id myuser`.

pub fn posixGetUserInfo(name: []const u8) !UserInfo {
    var in_stream = try io.InStream.open("/etc/passwd", null);
    defer in_stream.close();

    var buf: [os.page_size]u8 = undefined;
    var name_index: usize = 0;
    var state = State.Start;
    var uid: u32 = 0;
    var gid: u32 = 0;

    while (true) {
        const amt_read = try in_stream.read(buf[0..]);
        for (buf[0..amt_read]) |byte| {
            switch (state) {
                State.Start => switch (byte) {
                    ':' => {
                        state = if (name_index == name.len) State.SkipPassword else State.WaitForNextLine;
                    },
                    '\n' => return error.CorruptPasswordFile,
                    else => {
                        if (name_index == name.len or name[name_index] != byte) {
                            state = State.WaitForNextLine;
                        }
                        name_index += 1;
                    },
                },
                State.WaitForNextLine => switch (byte) {
                    '\n' => {
                        name_index = 0;
                        state = State.Start;
                    },
                    else => continue,
                },
                State.SkipPassword => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => {
                        state = State.ReadUserId;
                    },
                    else => continue,
                },
                State.ReadUserId => switch (byte) {
                    ':' => {
                        state = State.ReadGroupId;
                    },
                    '\n' => return error.CorruptPasswordFile,
                    else => {
                        const digit = switch (byte) {
                            '0'...'9' => byte - '0',
                            else => return error.CorruptPasswordFile,
                        };
                        if (@mulWithOverflow(u32, uid, 10, *uid)) return error.CorruptPasswordFile;
                        if (@addWithOverflow(u32, uid, digit, *uid)) return error.CorruptPasswordFile;
                    },
                },
                State.ReadGroupId => switch (byte) {
                    '\n', ':' => {
                        return UserInfo{
                            .uid = uid,
                            .gid = gid,
                        };
                    },
                    else => {
                        const digit = switch (byte) {
                            '0'...'9' => byte - '0',
                            else => return error.CorruptPasswordFile,
                        };
                        if (@mulWithOverflow(u32, gid, 10, *gid)) return error.CorruptPasswordFile;
                        if (@addWithOverflow(u32, gid, digit, *gid)) return error.CorruptPasswordFile;
                    },
                },
            }
        }
        if (amt_read < buf.len) return error.UserNotFound;
    }
}
