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
    /// TODO change this to Io.Timestamp except don't waste storage on clock
    atime: i128,
    /// Last modification time in nanoseconds, relative to UTC 1970-01-01.
    /// TODO change this to Io.Timestamp except don't waste storage on clock
    mtime: i128,
    /// Last status/metadata change time in nanoseconds, relative to UTC 1970-01-01.
    /// TODO change this to Io.Timestamp except don't waste storage on clock
    ctime: i128,
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
} || Io.Cancelable || Io.UnexpectedError;

/// Returns `Stat` containing basic information about the `File`.
pub fn stat(file: File, io: Io) StatError!Stat {
    return io.vtable.fileStat(io.userdata, file);
}

pub const OpenFlags = std.fs.File.OpenFlags;
pub const CreateFlags = std.fs.File.CreateFlags;

pub const OpenError = std.fs.File.OpenError || Io.Cancelable;

pub fn close(file: File, io: Io) void {
    return io.vtable.fileClose(io.userdata, file);
}

pub const ReadStreamingError = error{
    InputOutput,
    SystemResources,
    IsDir,
    BrokenPipe,
    ConnectionResetByPeer,
    ConnectionTimedOut,
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

pub const ReadPositionalError = ReadStreamingError || error{Unseekable};

pub fn readPositional(file: File, io: Io, buffer: []u8, offset: u64) ReadPositionalError!usize {
    return io.vtable.pread(io.userdata, file, buffer, offset);
}

pub const WriteError = std.fs.File.WriteError || Io.Cancelable;

pub fn write(file: File, io: Io, buffer: []const u8) WriteError!usize {
    return @errorCast(file.pwrite(io, buffer, -1));
}

pub fn writeAll(file: File, io: Io, bytes: []const u8) WriteError!void {
    var index: usize = 0;
    while (index < bytes.len) index += try file.write(io, bytes[index..]);
}

pub const PWriteError = std.fs.File.PWriteError || Io.Cancelable;

pub fn pwrite(file: File, io: Io, buffer: []const u8, offset: std.posix.off_t) PWriteError!usize {
    return io.vtable.pwrite(io.userdata, file, buffer, offset);
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

    pub const Error = std.posix.ReadError || Io.Cancelable;

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
            if (std.posix.Stat == void) {
                r.size_err = error.Streaming;
                return error.Streaming;
            }
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
                if (std.posix.SEEK == void) {
                    r.seek_err = error.Unseekable;
                    return error.Unseekable;
                }
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
                r.interface.seek = 0;
                r.interface.end = 0;
            },
            .failure => return r.seek_err.?,
        }
    }

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
        const logical_pos = logicalPos(r);
        if (offset < logical_pos or offset >= r.pos) {
            r.interface.seek = 0;
            r.interface.end = 0;
            r.pos = offset;
        } else {
            const logical_delta: usize = @intCast(offset - logical_pos);
            r.interface.seek += logical_delta;
        }
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
        const pos = r.pos;
        switch (r.mode) {
            .positional, .positional_reading => {
                const size = r.getSize() catch {
                    r.mode = r.mode.toStreaming();
                    return 0;
                };
                const delta = @min(@intFromEnum(limit), size - pos);
                r.pos = pos + delta;
                return delta;
            },
            .streaming, .streaming_reading => {
                const size = r.getSize() catch return 0;
                const n = @min(size - pos, std.math.maxInt(i64), @intFromEnum(limit));
                io.vtable.fileSeekBy(io.userdata, file, n) catch |err| {
                    r.seek_err = err;
                    return 0;
                };
                r.pos = pos + n;
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
