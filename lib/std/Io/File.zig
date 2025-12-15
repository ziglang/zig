const File = @This();

const builtin = @import("builtin");
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;

const std = @import("../std.zig");
const Io = std.Io;
const assert = std.debug.assert;

handle: Handle,

pub const Handle = std.posix.fd_t;
pub const Mode = std.posix.mode_t;
pub const INode = std.posix.ino_t;

pub const Kind = enum {
    block_device,
    character_device,
    directory,
    named_pipe,
    sym_link,
    file,
    unix_domain_socket,
    whiteout,
    door,
    event_port,
    unknown,
};

pub const Stat = struct {
    /// A number that the system uses to point to the file metadata. This
    /// number is not guaranteed to be unique across time, as some file
    /// systems may reuse an inode after its file has been deleted. Some
    /// systems may change the inode of a file over time.
    ///
    /// On Linux, the inode is a structure that stores the metadata, and
    /// the inode _number_ is what you see here: the index number of the
    /// inode.
    ///
    /// The FileIndex on Windows is similar. It is a number for a file that
    /// is unique to each filesystem.
    inode: INode,
    size: u64,
    /// This is available on POSIX systems and is always 0 otherwise.
    mode: Mode,
    kind: Kind,
    /// Last access time in nanoseconds, relative to UTC 1970-01-01.
    atime: Io.Timestamp,
    /// Last modification time in nanoseconds, relative to UTC 1970-01-01.
    mtime: Io.Timestamp,
    /// Last status/metadata change time in nanoseconds, relative to UTC 1970-01-01.
    ctime: Io.Timestamp,
};

pub fn stdout() File {
    return .{ .handle = if (is_windows) std.os.windows.peb().ProcessParameters.hStdOutput else std.posix.STDOUT_FILENO };
}

pub fn stderr() File {
    return .{ .handle = if (is_windows) std.os.windows.peb().ProcessParameters.hStdError else std.posix.STDERR_FILENO };
}

pub fn stdin() File {
    return .{ .handle = if (is_windows) std.os.windows.peb().ProcessParameters.hStdInput else std.posix.STDIN_FILENO };
}

pub const StatError = error{
    SystemResources,
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to get its filestat information.
    AccessDenied,
    PermissionDenied,
    /// Attempted to stat a non-file stream.
    Streaming,
} || Io.Cancelable || Io.UnexpectedError;

/// Returns `Stat` containing basic information about the `File`.
pub fn stat(file: File, io: Io) StatError!Stat {
    return io.vtable.fileStat(io.userdata, file);
}

pub const OpenMode = enum {
    read_only,
    write_only,
    read_write,
};

pub const Lock = enum {
    none,
    shared,
    exclusive,
};

pub const OpenFlags = struct {
    mode: OpenMode = .read_only,

    /// Open the file with an advisory lock to coordinate with other processes
    /// accessing it at the same time. An exclusive lock will prevent other
    /// processes from acquiring a lock. A shared lock will prevent other
    /// processes from acquiring a exclusive lock, but does not prevent
    /// other process from getting their own shared locks.
    ///
    /// The lock is advisory, except on Linux in very specific circumstances[1].
    /// This means that a process that does not respect the locking API can still get access
    /// to the file, despite the lock.
    ///
    /// On these operating systems, the lock is acquired atomically with
    /// opening the file:
    /// * Darwin
    /// * DragonFlyBSD
    /// * FreeBSD
    /// * Haiku
    /// * NetBSD
    /// * OpenBSD
    /// On these operating systems, the lock is acquired via a separate syscall
    /// after opening the file:
    /// * Linux
    /// * Windows
    ///
    /// [1]: https://www.kernel.org/doc/Documentation/filesystems/mandatory-locking.txt
    lock: Lock = .none,

    /// Sets whether or not to wait until the file is locked to return. If set to true,
    /// `error.WouldBlock` will be returned. Otherwise, the file will wait until the file
    /// is available to proceed.
    lock_nonblocking: bool = false,

    /// Set this to allow the opened file to automatically become the
    /// controlling TTY for the current process.
    allow_ctty: bool = false,

    follow_symlinks: bool = true,

    pub fn isRead(self: OpenFlags) bool {
        return self.mode != .write_only;
    }

    pub fn isWrite(self: OpenFlags) bool {
        return self.mode != .read_only;
    }
};

pub const CreateFlags = std.fs.File.CreateFlags;

pub const OpenError = error{
    SharingViolation,
    PipeBusy,
    NoDevice,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
    ProcessNotFound,
    /// On Windows, antivirus software is enabled by default. It can be
    /// disabled, but Windows Update sometimes ignores the user's preference
    /// and re-enables it. When enabled, antivirus software on Windows
    /// intercepts file system operations and makes them significantly slower
    /// in addition to possibly failing with this error code.
    AntivirusInterference,
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to open a new resource relative to it.
    AccessDenied,
    PermissionDenied,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    /// Either:
    /// * One of the path components does not exist.
    /// * Cwd was used, but cwd has been deleted.
    /// * The path associated with the open directory handle has been deleted.
    /// * On macOS, multiple processes or threads raced to create the same file
    ///   with `O.EXCL` set to `false`.
    FileNotFound,
    /// The path exceeded `max_path_bytes` bytes.
    /// Insufficient kernel memory was available, or
    /// the named file is a FIFO and per-user hard limit on
    /// memory allocation for pipes has been reached.
    SystemResources,
    /// The file is too large to be opened. This error is unreachable
    /// for 64-bit targets, as well as when opening directories.
    FileTooBig,
    /// The path refers to directory but the `DIRECTORY` flag was not provided.
    IsDir,
    /// A new path cannot be created because the device has no room for the new file.
    /// This error is only reachable when the `CREAT` flag is provided.
    NoSpaceLeft,
    /// A component used as a directory in the path was not, in fact, a directory, or
    /// `DIRECTORY` was specified and the path was not a directory.
    NotDir,
    /// The path already exists and the `CREAT` and `EXCL` flags were provided.
    PathAlreadyExists,
    DeviceBusy,
    FileLocksNotSupported,
    /// One of these three things:
    /// * pathname  refers to an executable image which is currently being
    ///   executed and write access was requested.
    /// * pathname refers to a file that is currently in  use  as  a  swap
    ///   file, and the O_TRUNC flag was specified.
    /// * pathname  refers  to  a file that is currently being read by the
    ///   kernel (e.g., for module/firmware loading), and write access was
    ///   requested.
    FileBusy,
    /// Non-blocking was requested and the operation cannot return immediately.
    WouldBlock,
} || Io.Dir.PathNameError || Io.Cancelable || Io.UnexpectedError;

pub fn close(file: File, io: Io) void {
    return io.vtable.fileClose(io.userdata, file);
}

pub const OpenSelfExeError = OpenError || std.fs.SelfExePathError || std.posix.FlockError;

pub fn openSelfExe(io: Io, flags: OpenFlags) OpenSelfExeError!File {
    return io.vtable.openSelfExe(io.userdata, flags);
}

pub const ReadPositionalError = Reader.Error || error{Unseekable};

pub fn readPositional(file: File, io: Io, buffer: [][]u8, offset: u64) ReadPositionalError!usize {
    return io.vtable.fileReadPositional(io.userdata, file, buffer, offset);
}

pub const WriteStreamingError = error{} || Io.UnexpectedError || Io.Cancelable;

pub fn writeStreaming(file: File, io: Io, buffer: [][]const u8) WriteStreamingError!usize {
    return file.fileWriteStreaming(io, buffer);
}

pub const WritePositionalError = WriteStreamingError || error{Unseekable};

pub fn writePositional(file: File, io: Io, buffer: [][]const u8, offset: u64) WritePositionalError!usize {
    return io.vtable.fileWritePositional(io.userdata, file, buffer, offset);
}

pub fn openAbsolute(io: Io, absolute_path: []const u8, flags: OpenFlags) OpenError!File {
    assert(std.fs.path.isAbsolute(absolute_path));
    return Io.Dir.cwd().openFile(io, absolute_path, flags);
}

/// Defaults to positional reading; falls back to streaming.
///
/// Positional is more threadsafe, since the global seek position is not
/// affected.
pub fn reader(file: File, io: Io, buffer: []u8) Reader {
    return .init(file, io, buffer);
}

/// Positional is more threadsafe, since the global seek position is not
/// affected, but when such syscalls are not available, preemptively
/// initializing in streaming mode skips a failed syscall.
pub fn readerStreaming(file: File, io: Io, buffer: []u8) Reader {
    return .initStreaming(file, io, buffer);
}

pub const SeekError = error{
    Unseekable,
    /// The file descriptor does not hold the required rights to seek on it.
    AccessDenied,
} || Io.Cancelable || Io.UnexpectedError;

/// Memoizes key information about a file handle such as:
/// * The size from calling stat, or the error that occurred therein.
/// * The current seek position.
/// * The error that occurred when trying to seek.
/// * Whether reading should be done positionally or streaming.
/// * Whether reading should be done via fd-to-fd syscalls (e.g. `sendfile`)
///   versus plain variants (e.g. `read`).
///
/// Fulfills the `Io.Reader` interface.
pub const Reader = struct {
    io: Io,
    file: File,
    err: ?Error = null,
    mode: Reader.Mode = .positional,
    /// Tracks the true seek position in the file. To obtain the logical
    /// position, use `logicalPos`.
    pos: u64 = 0,
    size: ?u64 = null,
    size_err: ?SizeError = null,
    seek_err: ?Reader.SeekError = null,
    interface: Io.Reader,

    pub const Error = error{
        InputOutput,
        SystemResources,
        IsDir,
        BrokenPipe,
        ConnectionResetByPeer,
        Timeout,
        /// In WASI, EBADF is mapped to this error because it is returned when
        /// trying to read a directory file descriptor as if it were a file.
        NotOpenForReading,
        SocketUnconnected,
        /// This error occurs when no global event loop is configured,
        /// and reading from the file descriptor would block.
        WouldBlock,
        /// In WASI, this error occurs when the file descriptor does
        /// not hold the required rights to read from it.
        AccessDenied,
        /// This error occurs in Linux if the process to be read from
        /// no longer exists.
        ProcessNotFound,
        /// Unable to read file due to lock.
        LockViolation,
    } || Io.Cancelable || Io.UnexpectedError;

    pub const SizeError = std.os.windows.GetFileSizeError || StatError || error{
        /// Occurs if, for example, the file handle is a network socket and therefore does not have a size.
        Streaming,
    };

    pub const SeekError = File.SeekError || error{
        /// Seeking fell back to reading, and reached the end before the requested seek position.
        /// `pos` remains at the end of the file.
        EndOfStream,
        /// Seeking fell back to reading, which failed.
        ReadFailed,
    };

    pub const Mode = enum {
        streaming,
        positional,
        /// Avoid syscalls other than `read` and `readv`.
        streaming_reading,
        /// Avoid syscalls other than `pread` and `preadv`.
        positional_reading,
        /// Indicates reading cannot continue because of a seek failure.
        failure,

        pub fn toStreaming(m: @This()) @This() {
            return switch (m) {
                .positional, .streaming => .streaming,
                .positional_reading, .streaming_reading => .streaming_reading,
                .failure => .failure,
            };
        }

        pub fn toReading(m: @This()) @This() {
            return switch (m) {
                .positional, .positional_reading => .positional_reading,
                .streaming, .streaming_reading => .streaming_reading,
                .failure => .failure,
            };
        }
    };

    pub fn initInterface(buffer: []u8) Io.Reader {
        return .{
            .vtable = &.{
                .stream = Reader.stream,
                .discard = Reader.discard,
                .readVec = Reader.readVec,
            },
            .buffer = buffer,
            .seek = 0,
            .end = 0,
        };
    }

    pub fn init(file: File, io: Io, buffer: []u8) Reader {
        return .{
            .io = io,
            .file = file,
            .interface = initInterface(buffer),
        };
    }

    /// Takes a legacy `std.fs.File` to help with upgrading.
    pub fn initAdapted(file: std.fs.File, io: Io, buffer: []u8) Reader {
        return .init(.{ .handle = file.handle }, io, buffer);
    }

    pub fn initSize(file: File, io: Io, buffer: []u8, size: ?u64) Reader {
        return .{
            .io = io,
            .file = file,
            .interface = initInterface(buffer),
            .size = size,
        };
    }

    /// Positional is more threadsafe, since the global seek position is not
    /// affected, but when such syscalls are not available, preemptively
    /// initializing in streaming mode skips a failed syscall.
    pub fn initStreaming(file: File, io: Io, buffer: []u8) Reader {
        return .{
            .io = io,
            .file = file,
            .interface = Reader.initInterface(buffer),
            .mode = .streaming,
            .seek_err = error.Unseekable,
            .size_err = error.Streaming,
        };
    }

    pub fn getSize(r: *Reader) SizeError!u64 {
        return r.size orelse {
            if (r.size_err) |err| return err;
            if (stat(r.file, r.io)) |st| {
                if (st.kind == .file) {
                    r.size = st.size;
                    return st.size;
                } else {
                    r.mode = r.mode.toStreaming();
                    r.size_err = error.Streaming;
                    return error.Streaming;
                }
            } else |err| {
                r.size_err = err;
                return err;
            }
        };
    }

    pub fn seekBy(r: *Reader, offset: i64) Reader.SeekError!void {
        const io = r.io;
        switch (r.mode) {
            .positional, .positional_reading => {
                setLogicalPos(r, @intCast(@as(i64, @intCast(logicalPos(r))) + offset));
            },
            .streaming, .streaming_reading => {
                const seek_err = r.seek_err orelse e: {
                    if (io.vtable.fileSeekBy(io.userdata, r.file, offset)) |_| {
                        setLogicalPos(r, @intCast(@as(i64, @intCast(logicalPos(r))) + offset));
                        return;
                    } else |err| {
                        r.seek_err = err;
                        break :e err;
                    }
                };
                var remaining = std.math.cast(u64, offset) orelse return seek_err;
                while (remaining > 0) {
                    remaining -= discard(&r.interface, .limited64(remaining)) catch |err| {
                        r.seek_err = err;
                        return err;
                    };
                }
                r.interface.tossBuffered();
            },
            .failure => return r.seek_err.?,
        }
    }

    /// Repositions logical read offset relative to the beginning of the file.
    pub fn seekTo(r: *Reader, offset: u64) Reader.SeekError!void {
        const io = r.io;
        switch (r.mode) {
            .positional, .positional_reading => {
                setLogicalPos(r, offset);
            },
            .streaming, .streaming_reading => {
                const logical_pos = logicalPos(r);
                if (offset >= logical_pos) return Reader.seekBy(r, @intCast(offset - logical_pos));
                if (r.seek_err) |err| return err;
                io.vtable.fileSeekTo(io.userdata, r.file, offset) catch |err| {
                    r.seek_err = err;
                    return err;
                };
                setLogicalPos(r, offset);
            },
            .failure => return r.seek_err.?,
        }
    }

    pub fn logicalPos(r: *const Reader) u64 {
        return r.pos - r.interface.bufferedLen();
    }

    fn setLogicalPos(r: *Reader, offset: u64) void {
        const logical_pos = r.logicalPos();
        if (offset < logical_pos or offset >= r.pos) {
            r.interface.tossBuffered();
            r.pos = offset;
        } else r.interface.toss(@intCast(offset - logical_pos));
    }

    /// Number of slices to store on the stack, when trying to send as many byte
    /// vectors through the underlying read calls as possible.
    const max_buffers_len = 16;

    fn stream(io_reader: *Io.Reader, w: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
        const r: *Reader = @alignCast(@fieldParentPtr("interface", io_reader));
        return streamMode(r, w, limit, r.mode);
    }

    pub fn streamMode(r: *Reader, w: *Io.Writer, limit: Io.Limit, mode: Reader.Mode) Io.Reader.StreamError!usize {
        switch (mode) {
            .positional, .streaming => return w.sendFile(r, limit) catch |write_err| switch (write_err) {
                error.Unimplemented => {
                    r.mode = r.mode.toReading();
                    return 0;
                },
                else => |e| return e,
            },
            .positional_reading => {
                const dest = limit.slice(try w.writableSliceGreedy(1));
                var data: [1][]u8 = .{dest};
                const n = try readVecPositional(r, &data);
                w.advance(n);
                return n;
            },
            .streaming_reading => {
                const dest = limit.slice(try w.writableSliceGreedy(1));
                var data: [1][]u8 = .{dest};
                const n = try readVecStreaming(r, &data);
                w.advance(n);
                return n;
            },
            .failure => return error.ReadFailed,
        }
    }

    fn readVec(io_reader: *Io.Reader, data: [][]u8) Io.Reader.Error!usize {
        const r: *Reader = @alignCast(@fieldParentPtr("interface", io_reader));
        switch (r.mode) {
            .positional, .positional_reading => return readVecPositional(r, data),
            .streaming, .streaming_reading => return readVecStreaming(r, data),
            .failure => return error.ReadFailed,
        }
    }

    fn readVecPositional(r: *Reader, data: [][]u8) Io.Reader.Error!usize {
        const io = r.io;
        var iovecs_buffer: [max_buffers_len][]u8 = undefined;
        const dest_n, const data_size = try r.interface.writableVector(&iovecs_buffer, data);
        const dest = iovecs_buffer[0..dest_n];
        assert(dest[0].len > 0);
        const n = io.vtable.fileReadPositional(io.userdata, r.file, dest, r.pos) catch |err| switch (err) {
            error.Unseekable => {
                r.mode = r.mode.toStreaming();
                const pos = r.pos;
                if (pos != 0) {
                    r.pos = 0;
                    r.seekBy(@intCast(pos)) catch {
                        r.mode = .failure;
                        return error.ReadFailed;
                    };
                }
                return 0;
            },
            else => |e| {
                r.err = e;
                return error.ReadFailed;
            },
        };
        if (n == 0) {
            r.size = r.pos;
            return error.EndOfStream;
        }
        r.pos += n;
        if (n > data_size) {
            r.interface.end += n - data_size;
            return data_size;
        }
        return n;
    }

    fn readVecStreaming(r: *Reader, data: [][]u8) Io.Reader.Error!usize {
        const io = r.io;
        var iovecs_buffer: [max_buffers_len][]u8 = undefined;
        const dest_n, const data_size = try r.interface.writableVector(&iovecs_buffer, data);
        const dest = iovecs_buffer[0..dest_n];
        assert(dest[0].len > 0);
        const n = io.vtable.fileReadStreaming(io.userdata, r.file, dest) catch |err| {
            r.err = err;
            return error.ReadFailed;
        };
        if (n == 0) {
            r.size = r.pos;
            return error.EndOfStream;
        }
        r.pos += n;
        if (n > data_size) {
            r.interface.end += n - data_size;
            return data_size;
        }
        return n;
    }

    fn discard(io_reader: *Io.Reader, limit: Io.Limit) Io.Reader.Error!usize {
        const r: *Reader = @alignCast(@fieldParentPtr("interface", io_reader));
        const io = r.io;
        const file = r.file;
        switch (r.mode) {
            .positional, .positional_reading => {
                const size = r.getSize() catch {
                    r.mode = r.mode.toStreaming();
                    return 0;
                };
                const logical_pos = logicalPos(r);
                const delta = @min(@intFromEnum(limit), size - logical_pos);
                setLogicalPos(r, logical_pos + delta);
                return delta;
            },
            .streaming, .streaming_reading => {
                // Unfortunately we can't seek forward without knowing the
                // size because the seek syscalls provided to us will not
                // return the true end position if a seek would exceed the
                // end.
                fallback: {
                    if (r.size_err == null and r.seek_err == null) break :fallback;

                    const buffered_len = r.interface.bufferedLen();
                    var remaining = @intFromEnum(limit);
                    if (remaining <= buffered_len) {
                        r.interface.seek += remaining;
                        return remaining;
                    }
                    remaining -= buffered_len;
                    r.interface.seek = 0;
                    r.interface.end = 0;

                    var trash_buffer: [128]u8 = undefined;
                    var data: [1][]u8 = .{trash_buffer[0..@min(trash_buffer.len, remaining)]};
                    var iovecs_buffer: [max_buffers_len][]u8 = undefined;
                    const dest_n, const data_size = try r.interface.writableVector(&iovecs_buffer, &data);
                    const dest = iovecs_buffer[0..dest_n];
                    assert(dest[0].len > 0);
                    const n = io.vtable.fileReadStreaming(io.userdata, file, dest) catch |err| {
                        r.err = err;
                        return error.ReadFailed;
                    };
                    if (n == 0) {
                        r.size = r.pos;
                        return error.EndOfStream;
                    }
                    r.pos += n;
                    if (n > data_size) {
                        r.interface.end += n - data_size;
                        remaining -= data_size;
                    } else {
                        remaining -= n;
                    }
                    return @intFromEnum(limit) - remaining;
                }
                const size = r.getSize() catch return 0;
                const n = @min(size - r.pos, std.math.maxInt(i64), @intFromEnum(limit));
                io.vtable.fileSeekBy(io.userdata, file, n) catch |err| {
                    r.seek_err = err;
                    return 0;
                };
                r.pos += n;
                return n;
            },
            .failure => return error.ReadFailed,
        }
    }

    /// Returns whether the stream is at the logical end.
    pub fn atEnd(r: *Reader) bool {
        // Even if stat fails, size is set when end is encountered.
        const size = r.size orelse return false;
        return size - logicalPos(r) == 0;
    }
};
