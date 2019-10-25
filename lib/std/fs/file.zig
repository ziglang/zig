const std = @import("../std.zig");
const builtin = @import("builtin");
const os = std.os;
const io = std.io;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const windows = os.windows;
const Os = builtin.Os;
const maxInt = std.math.maxInt;

pub const File = struct {
    /// The OS-specific file descriptor or file handle.
    handle: os.fd_t,

    pub const Mode = switch (builtin.os) {
        Os.windows => void,
        else => u32,
    };

    pub const default_mode = switch (builtin.os) {
        Os.windows => {},
        else => 0o666,
    };

    pub const OpenError = windows.CreateFileError || os.OpenError;

    /// Call close to clean up.
    pub fn openRead(path: []const u8) OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try windows.sliceToPrefixedFileW(path);
            return openReadW(&path_w);
        }
        const path_c = try os.toPosixPath(path);
        return openReadC(&path_c);
    }

    /// `openRead` except with a null terminated path
    pub fn openReadC(path: [*]const u8) OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try windows.cStrToPrefixedFileW(path);
            return openReadW(&path_w);
        }
        const flags = os.O_LARGEFILE | os.O_RDONLY;
        const fd = try os.openC(path, flags, 0);
        return openHandle(fd);
    }

    /// `openRead` except with a null terminated UTF16LE encoded path
    pub fn openReadW(path_w: [*]const u16) OpenError!File {
        const handle = try windows.CreateFileW(
            path_w,
            windows.GENERIC_READ,
            windows.FILE_SHARE_READ,
            null,
            windows.OPEN_EXISTING,
            windows.FILE_ATTRIBUTE_NORMAL,
            null,
        );
        return openHandle(handle);
    }

    /// Calls `openWriteMode` with `default_mode` for the mode.
    pub fn openWrite(path: []const u8) OpenError!File {
        return openWriteMode(path, default_mode);
    }

    /// If the path does not exist it will be created.
    /// If a file already exists in the destination it will be truncated.
    /// Call close to clean up.
    pub fn openWriteMode(path: []const u8, file_mode: Mode) OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try windows.sliceToPrefixedFileW(path);
            return openWriteModeW(&path_w, file_mode);
        }
        const path_c = try os.toPosixPath(path);
        return openWriteModeC(&path_c, file_mode);
    }

    /// Same as `openWriteMode` except `path` is null-terminated.
    pub fn openWriteModeC(path: [*]const u8, file_mode: Mode) OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try windows.cStrToPrefixedFileW(path);
            return openWriteModeW(&path_w, file_mode);
        }
        const flags = os.O_LARGEFILE | os.O_WRONLY | os.O_CREAT | os.O_CLOEXEC | os.O_TRUNC;
        const fd = try os.openC(path, flags, file_mode);
        return openHandle(fd);
    }

    /// Same as `openWriteMode` except `path` is null-terminated and UTF16LE encoded
    pub fn openWriteModeW(path_w: [*]const u16, file_mode: Mode) OpenError!File {
        const handle = try windows.CreateFileW(
            path_w,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            null,
            windows.CREATE_ALWAYS,
            windows.FILE_ATTRIBUTE_NORMAL,
            null,
        );
        return openHandle(handle);
    }

    /// If the path does not exist it will be created.
    /// If a file already exists in the destination this returns OpenError.PathAlreadyExists
    /// Call close to clean up.
    pub fn openWriteNoClobber(path: []const u8, file_mode: Mode) OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try windows.sliceToPrefixedFileW(path);
            return openWriteNoClobberW(&path_w, file_mode);
        }
        const path_c = try os.toPosixPath(path);
        return openWriteNoClobberC(&path_c, file_mode);
    }

    pub fn openWriteNoClobberC(path: [*]const u8, file_mode: Mode) OpenError!File {
        if (builtin.os == .windows) {
            const path_w = try windows.cStrToPrefixedFileW(path);
            return openWriteNoClobberW(&path_w, file_mode);
        }
        const flags = os.O_LARGEFILE | os.O_WRONLY | os.O_CREAT | os.O_CLOEXEC | os.O_EXCL;
        const fd = try os.openC(path, flags, file_mode);
        return openHandle(fd);
    }

    pub fn openWriteNoClobberW(path_w: [*]const u16, file_mode: Mode) OpenError!File {
        const handle = try windows.CreateFileW(
            path_w,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            null,
            windows.CREATE_NEW,
            windows.FILE_ATTRIBUTE_NORMAL,
            null,
        );
        return openHandle(handle);
    }

    pub fn openHandle(handle: os.fd_t) File {
        return File{ .handle = handle };
    }

    /// Test for the existence of `path`.
    /// `path` is UTF8-encoded.
    /// In general it is recommended to avoid this function. For example,
    /// instead of testing if a file exists and then opening it, just
    /// open it and handle the error for file not found.
    pub fn access(path: []const u8) !void {
        return os.access(path, os.F_OK);
    }

    /// Same as `access` except the parameter is null-terminated.
    pub fn accessC(path: [*]const u8) !void {
        return os.accessC(path, os.F_OK);
    }

    /// Same as `access` except the parameter is null-terminated UTF16LE-encoded.
    pub fn accessW(path: [*]const u16) !void {
        return os.accessW(path, os.F_OK);
    }

    /// Upon success, the stream is in an uninitialized state. To continue using it,
    /// you must use the open() function.
    pub fn close(self: File) void {
        return os.close(self.handle);
    }

    /// Test whether the file refers to a terminal.
    /// See also `supportsAnsiEscapeCodes`.
    pub fn isTty(self: File) bool {
        return os.isatty(self.handle);
    }

    /// Test whether ANSI escape codes will be treated as such.
    pub fn supportsAnsiEscapeCodes(self: File) bool {
        if (builtin.os == .windows) {
            return os.isCygwinPty(self.handle);
        }
        if (self.isTty()) {
            if (self.handle == os.STDOUT_FILENO or self.handle == os.STDERR_FILENO) {
                // Use getenvC to workaround https://github.com/ziglang/zig/issues/3511
                if (os.getenvC(c"TERM")) |term| {
                    if (std.mem.eql(u8, term, "dumb"))
                        return false;
                }
            }
            return true;
        }
        return false;
    }

    pub const SeekError = os.SeekError;

    /// Repositions read/write file offset relative to the current offset.
    pub fn seekBy(self: File, offset: i64) SeekError!void {
        return os.lseek_CUR(self.handle, offset);
    }

    /// Repositions read/write file offset relative to the end.
    pub fn seekFromEnd(self: File, offset: i64) SeekError!void {
        return os.lseek_END(self.handle, offset);
    }

    /// Repositions read/write file offset relative to the beginning.
    pub fn seekTo(self: File, offset: u64) SeekError!void {
        return os.lseek_SET(self.handle, offset);
    }

    pub const GetPosError = os.SeekError || os.FStatError;

    pub fn getPos(self: File) GetPosError!u64 {
        return os.lseek_CUR_get(self.handle);
    }

    pub fn getEndPos(self: File) GetPosError!u64 {
        if (builtin.os == .windows) {
            return windows.GetFileSizeEx(self.handle);
        }
        return (try self.stat()).size;
    }

    pub const ModeError = os.FStatError;

    pub fn mode(self: File) ModeError!Mode {
        if (builtin.os == .windows) {
            return {};
        }
        return (try self.stat()).mode;
    }

    pub const Stat = struct {
        size: u64,
        mode: Mode,

        /// access time in nanoseconds
        atime: i64,

        /// last modification time in nanoseconds
        mtime: i64,

        /// creation time in nanoseconds
        ctime: i64,
    };

    pub const StatError = os.FStatError;

    pub fn stat(self: File) StatError!Stat {
        if (builtin.os == .windows) {
            var io_status_block: windows.IO_STATUS_BLOCK = undefined;
            var info: windows.FILE_ALL_INFORMATION = undefined;
            const rc = windows.ntdll.NtQueryInformationFile(self.handle, &io_status_block, &info, @sizeOf(windows.FILE_ALL_INFORMATION), .FileAllInformation);
            switch (rc) {
                windows.STATUS.SUCCESS => {},
                windows.STATUS.BUFFER_OVERFLOW => {},
                windows.STATUS.INVALID_PARAMETER => unreachable,
                else => return windows.unexpectedStatus(rc),
            }
            return Stat{
                .size = @bitCast(u64, info.StandardInformation.EndOfFile),
                .mode = {},
                .atime = windows.fromSysTime(info.BasicInformation.LastAccessTime),
                .mtime = windows.fromSysTime(info.BasicInformation.LastWriteTime),
                .ctime = windows.fromSysTime(info.BasicInformation.CreationTime),
            };
        }

        const st = try os.fstat(self.handle);
        const atime = st.atime();
        const mtime = st.mtime();
        const ctime = st.ctime();
        return Stat{
            .size = @bitCast(u64, st.size),
            .mode = st.mode,
            .atime = i64(atime.tv_sec) * std.time.ns_per_s + atime.tv_nsec,
            .mtime = i64(mtime.tv_sec) * std.time.ns_per_s + mtime.tv_nsec,
            .ctime = i64(ctime.tv_sec) * std.time.ns_per_s + ctime.tv_nsec,
        };
    }

    pub const UpdateTimesError = os.FutimensError || windows.SetFileTimeError;

    /// The underlying file system may have a different granularity than nanoseconds,
    /// and therefore this function cannot guarantee any precision will be stored.
    /// Further, the maximum value is limited by the system ABI. When a value is provided
    /// that exceeds this range, the value is clamped to the maximum.
    pub fn updateTimes(
        self: File,
        /// access timestamp in nanoseconds
        atime: i64,
        /// last modification timestamp in nanoseconds
        mtime: i64,
    ) UpdateTimesError!void {
        if (builtin.os == .windows) {
            const atime_ft = windows.nanoSecondsToFileTime(atime);
            const mtime_ft = windows.nanoSecondsToFileTime(mtime);
            return windows.SetFileTime(self.handle, null, &atime_ft, &mtime_ft);
        }
        const times = [2]os.timespec{
            os.timespec{
                .tv_sec = math.cast(isize, @divFloor(atime, std.time.ns_per_s)) catch maxInt(isize),
                .tv_nsec = math.cast(isize, @mod(atime, std.time.ns_per_s)) catch maxInt(isize),
            },
            os.timespec{
                .tv_sec = math.cast(isize, @divFloor(mtime, std.time.ns_per_s)) catch maxInt(isize),
                .tv_nsec = math.cast(isize, @mod(mtime, std.time.ns_per_s)) catch maxInt(isize),
            },
        };
        try os.futimens(self.handle, &times);
    }

    pub const ReadError = os.ReadError;

    pub fn read(self: File, buffer: []u8) ReadError!usize {
        return os.read(self.handle, buffer);
    }

    pub const WriteError = os.WriteError;

    pub fn write(self: File, bytes: []const u8) WriteError!void {
        return os.write(self.handle, bytes);
    }

    pub fn writev_iovec(self: File, iovecs: []const os.iovec_const) WriteError!void {
        if (std.event.Loop.instance) |loop| {
            return std.event.fs.writevPosix(loop, self.handle, iovecs);
        } else {
            return os.writev(self.handle, iovecs);
        }
    }

    pub fn inStream(file: File) InStream {
        return InStream{
            .file = file,
            .stream = InStream.Stream{ .readFn = InStream.readFn },
        };
    }

    pub fn outStream(file: File) OutStream {
        return OutStream{
            .file = file,
            .stream = OutStream.Stream{ .writeFn = OutStream.writeFn },
        };
    }

    pub fn seekableStream(file: File) SeekableStream {
        return SeekableStream{
            .file = file,
            .stream = SeekableStream.Stream{
                .seekToFn = SeekableStream.seekToFn,
                .seekByFn = SeekableStream.seekByFn,
                .getPosFn = SeekableStream.getPosFn,
                .getEndPosFn = SeekableStream.getEndPosFn,
            },
        };
    }

    /// Implementation of io.InStream trait for File
    pub const InStream = struct {
        file: File,
        stream: Stream,

        pub const Error = ReadError;
        pub const Stream = io.InStream(Error);

        fn readFn(in_stream: *Stream, buffer: []u8) Error!usize {
            const self = @fieldParentPtr(InStream, "stream", in_stream);
            return self.file.read(buffer);
        }
    };

    /// Implementation of io.OutStream trait for File
    pub const OutStream = struct {
        file: File,
        stream: Stream,

        pub const Error = WriteError;
        pub const Stream = io.OutStream(Error);

        fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
            const self = @fieldParentPtr(OutStream, "stream", out_stream);
            return self.file.write(bytes);
        }
    };

    /// Implementation of io.SeekableStream trait for File
    pub const SeekableStream = struct {
        file: File,
        stream: Stream,

        pub const Stream = io.SeekableStream(SeekError, GetPosError);

        pub fn seekToFn(seekable_stream: *Stream, pos: u64) SeekError!void {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.seekTo(pos);
        }

        pub fn seekByFn(seekable_stream: *Stream, amt: i64) SeekError!void {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.seekBy(amt);
        }

        pub fn getEndPosFn(seekable_stream: *Stream) GetPosError!u64 {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.getEndPos();
        }

        pub fn getPosFn(seekable_stream: *Stream) GetPosError!u64 {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.getPos();
        }
    };
};
