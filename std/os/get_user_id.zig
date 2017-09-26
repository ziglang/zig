const builtin = @import("builtin");
const Os = builtin.Os;
const os = @import("index.zig");
const io = @import("../io.zig");

/// POSIX function which gets a uid from username.
pub fn getUserId(name: []const u8) -> %u32 {
    return switch (builtin.os) {
        Os.linux, Os.darwin, Os.macosx, Os.ios => posixGetUserId(name),
        else => @compileError("Unsupported OS"),
    };
}

const State = enum {
    Start,
    WaitForNextLine,
    SkipPassword,
    ReadId,
};

error UserNotFound;
error CorruptPasswordFile;

pub fn posixGetUserId(name: []const u8) -> %u32 {
    var in_stream = %return io.InStream.open("/etc/passwd", null);
    defer in_stream.close();

    var buf: [os.page_size]u8 = undefined;
    var name_index: usize = 0;
    var state = State.Start;
    var uid: u32 = 0;

    while (true) {
        const amt_read = %return in_stream.read(buf[0..]);
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
                        state = State.ReadId;
                    },
                    else => continue,
                },
                State.ReadId => switch (byte) {
                    '\n', ':' => return uid,
                    else => {
                        const digit = switch (byte) {
                            '0' ... '9' => byte - '0',
                            else => return error.CorruptPasswordFile,
                        };
                        if (@mulWithOverflow(u32, uid, 10, &uid)) return error.CorruptPasswordFile;
                        if (@addWithOverflow(u32, uid, digit, &uid)) return error.CorruptPasswordFile;
                    },
                },
            }
        }
        if (amt_read < buf.len) return error.UserNotFound;
    }
}
