const Dir = @This();

const std = @import("../std.zig");
const Io = std.Io;
const File = Io.File;

handle: Handle,

pub fn cwd() Dir {
    return .{ .handle = std.fs.cwd().fd };
}

pub const Handle = std.posix.fd_t;

pub fn openFile(dir: Dir, io: Io, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    return io.vtable.fileOpen(io.userdata, dir, sub_path, flags);
}

pub fn createFile(dir: Dir, io: Io, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    return io.vtable.createFile(io.userdata, dir, sub_path, flags);
}

pub const WriteFileOptions = struct {
    /// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
    /// On WASI, `sub_path` should be encoded as valid UTF-8.
    /// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
    sub_path: []const u8,
    data: []const u8,
    flags: File.CreateFlags = .{},
};

pub const WriteFileError = File.WriteError || File.OpenError || Io.Cancelable;

/// Writes content to the file system, using the file creation flags provided.
pub fn writeFile(dir: Dir, io: Io, options: WriteFileOptions) WriteFileError!void {
    var file = try dir.createFile(io, options.sub_path, options.flags);
    defer file.close(io);
    try file.writeAll(io, options.data);
}

pub const PrevStatus = enum {
    stale,
    fresh,
};

pub const UpdateFileError = File.OpenError;

/// Check the file size, mtime, and mode of `source_path` and `dest_path`. If
/// they are equal, does nothing. Otherwise, atomically copies `source_path` to
/// `dest_path`. The destination file gains the mtime, atime, and mode of the
/// source file so that the next call to `updateFile` will not need a copy.
///
/// Returns the previous status of the file before updating.
///
/// * On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On WASI, both paths should be encoded as valid UTF-8.
/// * On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn updateFile(
    source_dir: Dir,
    io: Io,
    source_path: []const u8,
    dest_dir: Dir,
    /// If directories in this path do not exist, they are created.
    dest_path: []const u8,
    options: std.fs.Dir.CopyFileOptions,
) !PrevStatus {
    var src_file = try source_dir.openFile(io, source_path, .{});
    defer src_file.close();

    const src_stat = try src_file.stat(io);
    const actual_mode = options.override_mode orelse src_stat.mode;
    check_dest_stat: {
        const dest_stat = blk: {
            var dest_file = dest_dir.openFile(io, dest_path, .{}) catch |err| switch (err) {
                error.FileNotFound => break :check_dest_stat,
                else => |e| return e,
            };
            defer dest_file.close(io);

            break :blk try dest_file.stat(io);
        };

        if (src_stat.size == dest_stat.size and
            src_stat.mtime == dest_stat.mtime and
            actual_mode == dest_stat.mode)
        {
            return .fresh;
        }
    }

    if (std.fs.path.dirname(dest_path)) |dirname| {
        try dest_dir.makePath(io, dirname);
    }

    var buffer: [1000]u8 = undefined; // Used only when direct fd-to-fd is not available.
    var atomic_file = try dest_dir.atomicFile(io, dest_path, .{
        .mode = actual_mode,
        .write_buffer = &buffer,
    });
    defer atomic_file.deinit();

    var src_reader: File.Reader = .initSize(io, src_file, &.{}, src_stat.size);
    const dest_writer = &atomic_file.file_writer.interface;

    _ = dest_writer.sendFileAll(&src_reader, .unlimited) catch |err| switch (err) {
        error.ReadFailed => return src_reader.err.?,
        error.WriteFailed => return atomic_file.file_writer.err.?,
    };
    try atomic_file.flush();
    try atomic_file.file_writer.file.updateTimes(src_stat.atime, src_stat.mtime);
    try atomic_file.renameIntoPlace();
    return .stale;
}
