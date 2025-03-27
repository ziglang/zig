const std = @import("../std.zig");
const builtin = @import("builtin");
const unicode = std.unicode;
const mem = std.mem;
const fs = std.fs;
const native_os = builtin.os.tag;
const posix = std.posix;

pub const GetAppDataDirError = error{
    OutOfMemory,
    AppDataDirUnavailable,
};

/// Caller owns returned memory.
/// TODO determine if we can remove the allocator requirement
pub fn getAppDataDir(allocator: mem.Allocator, appname: []const u8) GetAppDataDirError![]u8 {
    switch (native_os) {
        .windows => {
            const local_app_data_dir = std.process.getEnvVarOwned(allocator, "LOCALAPPDATA") catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                else => return error.AppDataDirUnavailable,
            };
            defer allocator.free(local_app_data_dir);
            return fs.path.join(allocator, &[_][]const u8{ local_app_data_dir, appname });
        },
        .macos => {
            const home_dir = posix.getenv("HOME") orelse (getHomeDirFromPasswd() catch return error.AppDataDirUnavailable);
            return fs.path.join(allocator, &[_][]const u8{ home_dir, "Library", "Application Support", appname });
        },
        .linux, .freebsd, .netbsd, .dragonfly, .openbsd, .solaris, .illumos, .serenity => {
            if (posix.getenv("XDG_DATA_HOME")) |xdg| {
                if (xdg.len > 0) {
                    return fs.path.join(allocator, &[_][]const u8{ xdg, appname });
                }
            }

            const home_dir = posix.getenv("HOME") orelse (getHomeDirFromPasswd() catch return error.AppDataDirUnavailable);
            return fs.path.join(allocator, &[_][]const u8{ home_dir, ".local", "share", appname });
        },
        .haiku => {
            var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const rc = std.c.find_directory(.B_USER_SETTINGS_DIRECTORY, -1, true, &dir_path_buf, dir_path_buf.len);
            const settings_dir = try allocator.dupeZ(u8, mem.sliceTo(&dir_path_buf, 0));
            defer allocator.free(settings_dir);
            switch (rc) {
                0 => return fs.path.join(allocator, &[_][]const u8{ settings_dir, appname }),
                else => return error.AppDataDirUnavailable,
            }
        },
        else => @compileError("Unsupported OS"),
    }
}

/// Parses home directory from /etc/passwd.
fn getHomeDirFromPasswd() ![]u8 {
    const ReaderState = enum {
        start,
        wait_for_next_line,
        skip_username,
        skip_password,
        read_user_id,
        skip_group_id,
        skip_gecos,
        read_home_directory,
    };

    const file = try fs.openFileAbsolute("/etc/passwd", .{});
    defer file.close();

    const reader = file.reader();

    var buf: [std.heap.page_size_min]u8 = undefined;
    var state = ReaderState.start;
    const currentUid = std.posix.getuid();
    var uid: posix.uid_t = 0;
    var home_dir_start: usize = 0;
    var home_dir_len: usize = 0;

    while (true) {
        const bytes_read = try reader.read(buf[0..]);
        for (0.., buf[0..bytes_read]) |i, byte| {
            switch (state) {
                .start => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => state = .skip_password,
                    else => continue,
                },
                .wait_for_next_line => switch (byte) {
                    '\n' => {
                        uid = 0;
                        home_dir_len = 0;
                        state = .start;
                    },
                    else => continue,
                },
                .skip_username => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => std.debug.print("*", .{}),
                    else => continue,
                },
                .skip_password => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => state = .read_user_id,
                    else => continue,
                },
                .read_user_id => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => state = if (uid == currentUid) .skip_group_id else .wait_for_next_line,
                    else => {
                        const digit = switch (byte) {
                            '0'...'9' => byte - '0',
                            else => return error.CorruptPasswordFile,
                        };
                        {
                            const ov = @mulWithOverflow(uid, 10);
                            if (ov[1] != 0) return error.CorruptPasswordFile;
                            uid = ov[0];
                        }
                        {
                            const ov = @addWithOverflow(uid, digit);
                            if (ov[1] != 0) return error.CorruptPasswordFile;
                            uid = ov[0];
                        }
                    },
                },
                .skip_group_id => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => state = .skip_gecos,
                    else => continue,
                },
                .skip_gecos => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => {
                        home_dir_start = i + 1;
                        state = .read_home_directory;
                    },
                    else => continue,
                },
                .read_home_directory => switch (byte) {
                    '\n', ':' => return buf[home_dir_start .. home_dir_start + home_dir_len],
                    else => {
                        home_dir_len += 1;
                    },
                },
            }
        }
    }
}

test getAppDataDir {
    if (native_os == .wasi) return error.SkipZigTest;

    // We can't actually validate the result
    const dir = getAppDataDir(std.testing.allocator, "zig") catch return;
    defer std.testing.allocator.free(dir);
}
