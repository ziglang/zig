file: File,
// TODO either replace this with rand_buf or use []u16 on Windows
tmp_path_buf: [tmp_path_len:0]u8,
dest_basename: []const u8,
file_open: bool,
file_exists: bool,
close_dir_on_deinit: bool,
dir: Dir,

pub const InitError = File.OpenError;

pub const random_bytes_len = 12;
const tmp_path_len = fs.base64_encoder.calcSize(random_bytes_len);

/// Note that the `Dir.atomicFile` API may be more handy than this lower-level function.
pub fn init(
    dest_basename: []const u8,
    mode: File.Mode,
    dir: Dir,
    close_dir_on_deinit: bool,
) InitError!AtomicFile {
    var rand_buf: [random_bytes_len]u8 = undefined;
    var tmp_path_buf: [tmp_path_len:0]u8 = undefined;

    while (true) {
        std.crypto.random.bytes(rand_buf[0..]);
        const tmp_path = fs.base64_encoder.encode(&tmp_path_buf, &rand_buf);
        tmp_path_buf[tmp_path.len] = 0;

        const file = dir.createFile(
            tmp_path,
            .{ .mode = mode, .exclusive = true },
        ) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => |e| return e,
        };

        return AtomicFile{
            .file = file,
            .tmp_path_buf = tmp_path_buf,
            .dest_basename = dest_basename,
            .file_open = true,
            .file_exists = true,
            .close_dir_on_deinit = close_dir_on_deinit,
            .dir = dir,
        };
    }
}

/// Always call deinit, even after a successful finish().
pub fn deinit(self: *AtomicFile) void {
    if (self.file_open) {
        self.file.close();
        self.file_open = false;
    }
    if (self.file_exists) {
        self.dir.deleteFile(&self.tmp_path_buf) catch {};
        self.file_exists = false;
    }
    if (self.close_dir_on_deinit) {
        self.dir.close();
    }
    self.* = undefined;
}

pub const FinishError = posix.RenameError;

/// On Windows, this function introduces a period of time where some file
/// system operations on the destination file will result in
/// `error.AccessDenied`, including rename operations (such as the one used in
/// this function).
pub fn finish(self: *AtomicFile) FinishError!void {
    assert(self.file_exists);
    if (self.file_open) {
        self.file.close();
        self.file_open = false;
    }
    try posix.renameat(self.dir.fd, self.tmp_path_buf[0..], self.dir.fd, self.dest_basename);
    self.file_exists = false;
}

const AtomicFile = @This();
const std = @import("../std.zig");
const File = std.fs.File;
const Dir = std.fs.Dir;
const fs = std.fs;
const assert = std.debug.assert;
const posix = std.posix;
