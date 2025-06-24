const AtomicFile = @This();
const std = @import("../std.zig");
const File = std.fs.File;
const Dir = std.fs.Dir;
const fs = std.fs;
const assert = std.debug.assert;
const posix = std.posix;

file_writer: File.Writer,
random_integer: u64,
dest_basename: []const u8,
file_open: bool,
file_exists: bool,
close_dir_on_deinit: bool,
dir: Dir,

pub const InitError = File.OpenError;

/// Note that the `Dir.atomicFile` API may be more handy than this lower-level function.
pub fn init(
    dest_basename: []const u8,
    mode: File.Mode,
    dir: Dir,
    close_dir_on_deinit: bool,
    write_buffer: []u8,
) InitError!AtomicFile {
    while (true) {
        const random_integer = std.crypto.random.int(u64);
        const tmp_sub_path = std.fmt.hex(random_integer);
        const file = dir.createFile(&tmp_sub_path, .{ .mode = mode, .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => |e| return e,
        };
        return .{
            .file_writer = file.writer(write_buffer),
            .random_integer = random_integer,
            .dest_basename = dest_basename,
            .file_open = true,
            .file_exists = true,
            .close_dir_on_deinit = close_dir_on_deinit,
            .dir = dir,
        };
    }
}

/// Always call deinit, even after a successful finish().
pub fn deinit(af: *AtomicFile) void {
    if (af.file_open) {
        af.file_writer.file.close();
        af.file_open = false;
    }
    if (af.file_exists) {
        const tmp_sub_path = std.fmt.hex(af.random_integer);
        af.dir.deleteFile(&tmp_sub_path) catch {};
        af.file_exists = false;
    }
    if (af.close_dir_on_deinit) {
        af.dir.close();
    }
    af.* = undefined;
}

pub const FlushError = File.WriteError;

pub fn flush(af: *AtomicFile) FlushError!void {
    af.file_writer.interface.flush() catch |err| switch (err) {
        error.WriteFailed => return af.file_writer.err.?,
    };
}

pub const RenameIntoPlaceError = posix.RenameError;

/// On Windows, this function introduces a period of time where some file
/// system operations on the destination file will result in
/// `error.AccessDenied`, including rename operations (such as the one used in
/// this function).
pub fn renameIntoPlace(af: *AtomicFile) RenameIntoPlaceError!void {
    assert(af.file_exists);
    if (af.file_open) {
        af.file_writer.file.close();
        af.file_open = false;
    }
    const tmp_sub_path = std.fmt.hex(af.random_integer);
    try posix.renameat(af.dir.fd, &tmp_sub_path, af.dir.fd, af.dest_basename);
    af.file_exists = false;
}

pub const FinishError = FlushError || RenameIntoPlaceError;

/// Combination of `flush` followed by `renameIntoPlace`.
pub fn finish(af: *AtomicFile) FinishError!void {
    try af.flush();
    try af.renameIntoPlace();
}
