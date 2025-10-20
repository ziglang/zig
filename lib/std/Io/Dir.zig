const Dir = @This();

const builtin = @import("builtin");
const native_os = builtin.os.tag;

const std = @import("../std.zig");
const Io = std.Io;
const File = Io.File;

handle: Handle,

pub const Mode = Io.File.Mode;
pub const default_mode: Mode = 0o755;

/// Returns a handle to the current working directory.
///
/// It is not opened with iteration capability. Iterating over the result is
/// illegal behavior.
///
/// Closing the returned `Dir` is checked illegal behavior.
///
/// On POSIX targets, this function is comptime-callable.
pub fn cwd() Dir {
    return switch (native_os) {
        .windows => .{ .handle = std.os.windows.peb().ProcessParameters.CurrentDirectory.Handle },
        .wasi => .{ .handle = std.options.wasiCwd() },
        else => .{ .handle = std.posix.AT.FDCWD },
    };
}

pub const Handle = std.posix.fd_t;

pub const PathNameError = error{
    NameTooLong,
    /// File system cannot encode the requested file name bytes.
    /// Could be due to invalid WTF-8 on Windows, invalid UTF-8 on WASI,
    /// invalid characters on Windows, etc. Filesystem and operating specific.
    BadPathName,
};

pub const AccessError = error{
    AccessDenied,
    PermissionDenied,
    FileNotFound,
    InputOutput,
    SystemResources,
    FileBusy,
    SymLinkLoop,
    ReadOnlyFileSystem,
} || PathNameError || Io.Cancelable || Io.UnexpectedError;

pub const AccessOptions = packed struct {
    follow_symlinks: bool = true,
    read: bool = false,
    write: bool = false,
    execute: bool = false,
};

/// Test accessing `sub_path`.
///
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
///
/// Be careful of Time-Of-Check-Time-Of-Use race conditions when using this
/// function. For example, instead of testing if a file exists and then opening
/// it, just open it and handle the error for file not found.
pub fn access(dir: Dir, io: Io, sub_path: []const u8, options: AccessOptions) AccessError!void {
    return io.vtable.dirAccess(io.userdata, dir, sub_path, options);
}

pub const OpenError = error{
    FileNotFound,
    NotDir,
    AccessDenied,
    PermissionDenied,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    SystemResources,
    DeviceBusy,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || PathNameError || Io.Cancelable || Io.UnexpectedError;

pub const OpenOptions = struct {
    /// `true` means the opened directory can be used as the `Dir` parameter
    /// for functions which operate based on an open directory handle. When `false`,
    /// such operations are Illegal Behavior.
    access_sub_paths: bool = true,
    /// `true` means the opened directory can be scanned for the files and sub-directories
    /// of the result. It means the `iterate` function can be called.
    iterate: bool = false,
    /// `false` means it won't dereference the symlinks.
    follow_symlinks: bool = true,
};

/// Opens a directory at the given path. The directory is a system resource that remains
/// open until `close` is called on the result.
///
/// The directory cannot be iterated unless the `iterate` option is set to `true`.
///
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn openDir(dir: Dir, io: Io, sub_path: []const u8, options: OpenOptions) OpenError!Dir {
    return io.vtable.dirOpenDir(io.userdata, dir, sub_path, options);
}

pub fn close(dir: Dir, io: Io) void {
    return io.vtable.dirClose(io.userdata, dir);
}

/// Opens a file for reading or writing, without attempting to create a new file.
///
/// To create a new file, see `createFile`.
///
/// Allocates a resource to be released with `File.close`.
///
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn openFile(dir: Dir, io: Io, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    return io.vtable.dirOpenFile(io.userdata, dir, sub_path, flags);
}

/// Creates, opens, or overwrites a file with write access.
///
/// Allocates a resource to be dellocated with `File.close`.
///
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn createFile(dir: Dir, io: Io, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    return io.vtable.dirCreateFile(io.userdata, dir, sub_path, flags);
}

pub const WriteFileOptions = struct {
    /// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
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
/// `dest_path`, creating the parent directory hierarchy as needed. The
/// destination file gains the mtime, atime, and mode of the source file so
/// that the next call to `updateFile` will not need a copy.
///
/// Returns the previous status of the file before updating.
///
/// * On Windows, both paths should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
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
    defer src_file.close(io);

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
            src_stat.mtime.nanoseconds == dest_stat.mtime.nanoseconds and
            actual_mode == dest_stat.mode)
        {
            return .fresh;
        }
    }

    if (std.fs.path.dirname(dest_path)) |dirname| {
        try dest_dir.makePath(io, dirname);
    }

    var buffer: [1000]u8 = undefined; // Used only when direct fd-to-fd is not available.
    var atomic_file = try std.fs.Dir.atomicFile(.adaptFromNewApi(dest_dir), dest_path, .{
        .mode = actual_mode,
        .write_buffer = &buffer,
    });
    defer atomic_file.deinit();

    var src_reader: File.Reader = .initSize(src_file, io, &.{}, src_stat.size);
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

pub const ReadFileError = File.OpenError || File.Reader.Error;

/// Read all of file contents using a preallocated buffer.
///
/// The returned slice has the same pointer as `buffer`. If the length matches `buffer.len`
/// the situation is ambiguous. It could either mean that the entire file was read, and
/// it exactly fits the buffer, or it could mean the buffer was not big enough for the
/// entire file.
///
/// * On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On WASI, `file_path` should be encoded as valid UTF-8.
/// * On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
pub fn readFile(dir: Dir, io: Io, file_path: []const u8, buffer: []u8) ReadFileError![]u8 {
    var file = try dir.openFile(io, file_path, .{});
    defer file.close(io);

    var reader = file.reader(io, &.{});
    const n = reader.interface.readSliceShort(buffer) catch |err| switch (err) {
        error.ReadFailed => return reader.err.?,
    };

    return buffer[0..n];
}

pub const MakeError = error{
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to create a new directory relative to it.
    AccessDenied,
    PermissionDenied,
    DiskQuota,
    PathAlreadyExists,
    SymLinkLoop,
    LinkQuotaExceeded,
    FileNotFound,
    SystemResources,
    NoSpaceLeft,
    NotDir,
    ReadOnlyFileSystem,
    NoDevice,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || PathNameError || Io.Cancelable || Io.UnexpectedError;

/// Creates a single directory with a relative or absolute path.
///
/// * On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On WASI, `sub_path` should be encoded as valid UTF-8.
/// * On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
///
/// Related:
/// * `makePath`
/// * `makeDirAbsolute`
pub fn makeDir(dir: Dir, io: Io, sub_path: []const u8) MakeError!void {
    return io.vtable.dirMake(io.userdata, dir, sub_path, default_mode);
}

pub const MakePathError = MakeError || StatPathError;

/// Calls makeDir iteratively to make an entire path, creating any parent
/// directories that do not exist.
///
/// Returns success if the path already exists and is a directory.
///
/// This function is not atomic, and if it returns an error, the file system
/// may have been modified regardless.
///
/// Fails on an empty path with `error.BadPathName` as that is not a path that
/// can be created.
///
/// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
///
/// Paths containing `..` components are handled differently depending on the platform:
/// - On Windows, `..` are resolved before the path is passed to NtCreateFile, meaning
///   a `sub_path` like "first/../second" will resolve to "second" and only a
///   `./second` directory will be created.
/// - On other platforms, `..` are not resolved before the path is passed to `mkdirat`,
///   meaning a `sub_path` like "first/../second" will create both a `./first`
///   and a `./second` directory.
pub fn makePath(dir: Dir, io: Io, sub_path: []const u8) MakePathError!void {
    _ = try makePathStatus(dir, io, sub_path);
}

pub const MakePathStatus = enum { existed, created };

/// Same as `makePath` except returns whether the path already existed or was
/// successfully created.
pub fn makePathStatus(dir: Dir, io: Io, sub_path: []const u8) MakePathError!MakePathStatus {
    var it = try std.fs.path.componentIterator(sub_path);
    var status: MakePathStatus = .existed;
    var component = it.last() orelse return error.BadPathName;
    while (true) {
        if (makeDir(dir, io, component.path)) |_| {
            status = .created;
        } else |err| switch (err) {
            error.PathAlreadyExists => {
                // stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                check_dir: {
                    // workaround for windows, see https://github.com/ziglang/zig/issues/16738
                    const fstat = statPath(dir, io, component.path, .{}) catch |stat_err| switch (stat_err) {
                        error.IsDir => break :check_dir,
                        else => |e| return e,
                    };
                    if (fstat.kind != .directory) return error.NotDir;
                }
            },
            error.FileNotFound => |e| {
                component = it.previous() orelse return e;
                continue;
            },
            else => |e| return e,
        }
        component = it.next() orelse return status;
    }
}

pub const MakeOpenPathError = MakeError || OpenError || StatPathError;

/// Performs the equivalent of `makePath` followed by `openDir`, atomically if possible.
///
/// When this operation is canceled, it may leave the file system in a
/// partially modified state.
///
/// On Windows, `sub_path` should be encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On WASI, `sub_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn makeOpenPath(dir: Dir, io: Io, sub_path: []const u8, options: OpenOptions) MakeOpenPathError!Dir {
    return io.vtable.dirMakeOpenPath(io.userdata, dir, sub_path, options);
}

pub const Stat = File.Stat;
pub const StatError = File.StatError;

pub fn stat(dir: Dir, io: Io) StatError!Stat {
    return io.vtable.dirStat(io.userdata, dir);
}

pub const StatPathError = File.OpenError || File.StatError;

pub const StatPathOptions = struct {
    follow_symlinks: bool = true,
};

/// Returns metadata for a file inside the directory.
///
/// On Windows, this requires three syscalls. On other operating systems, it
/// only takes one.
///
/// Symlinks are followed.
///
/// `sub_path` may be absolute, in which case `self` is ignored.
///
/// * On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On WASI, `sub_path` should be encoded as valid UTF-8.
/// * On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
pub fn statPath(dir: Dir, io: Io, sub_path: []const u8, options: StatPathOptions) StatPathError!Stat {
    return io.vtable.dirStatPath(io.userdata, dir, sub_path, options);
}
