const std = @import("../std.zig");
const builtin = @import("builtin");
const os = std.os;
const io = std.io;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const posix = os.posix;
const windows = os.windows;
const Os = builtin.Os;
const windows_util = @import("windows/util.zig");
const maxInt = std.math.maxInt;

const is_posix = builtin.os != builtin.Os.windows;
const is_windows = builtin.os == builtin.Os.windows;

pub const File = struct {
    /// The OS-specific file descriptor or file handle.
    handle: posix.fd_t,

    pub const Mode = switch (builtin.os) {
        Os.windows => void,
        else => u32,
    };

    pub const default_mode = switch (builtin.os) {
        Os.windows => {},
        else => 0o666,
    };

    pub const OpenError = os.WindowsOpenError || os.PosixOpenError;

    /// `openRead` except with a null terminated path
    pub fn openReadC(path: [*]const u8) OpenError!File {
        if (is_posix) {
            const flags = posix.O_LARGEFILE | posix.O_RDONLY;
            const fd = try os.posixOpenC(path, flags, 0);
            return openHandle(fd);
        }
        if (is_windows) {
            return openRead(mem.toSliceConst(u8, path));
        }
        @compileError("Unsupported OS");
    }

    /// Call close to clean up.
    pub fn openRead(path: []const u8) OpenError!File {
        if (is_posix) {
            const path_c = try os.toPosixPath(path);
            return openReadC(&path_c);
        }
        if (is_windows) {
            const path_w = try windows_util.sliceToPrefixedFileW(path);
            return openReadW(&path_w);
        }
        @compileError("Unsupported OS");
    }

    pub fn openReadW(path_w: [*]const u16) OpenError!File {
        const handle = try os.windowsOpenW(
            path_w,
            windows.GENERIC_READ,
            windows.FILE_SHARE_READ,
            windows.OPEN_EXISTING,
            windows.FILE_ATTRIBUTE_NORMAL,
        );
        return openHandle(handle);
    }

    /// Calls `openWriteMode` with os.File.default_mode for the mode.
    pub fn openWrite(path: []const u8) OpenError!File {
        return openWriteMode(path, os.File.default_mode);
    }

    /// If the path does not exist it will be created.
    /// If a file already exists in the destination it will be truncated.
    /// Call close to clean up.
    pub fn openWriteMode(path: []const u8, file_mode: Mode) OpenError!File {
        if (is_posix) {
            const flags = posix.O_LARGEFILE | posix.O_WRONLY | posix.O_CREAT | posix.O_CLOEXEC | posix.O_TRUNC;
            const fd = try os.posixOpen(path, flags, file_mode);
            return openHandle(fd);
        } else if (is_windows) {
            const path_w = try windows_util.sliceToPrefixedFileW(path);
            return openWriteModeW(&path_w, file_mode);
        } else {
            @compileError("TODO implement openWriteMode for this OS");
        }
    }

    pub fn openWriteModeW(path_w: [*]const u16, file_mode: Mode) OpenError!File {
        const handle = try os.windowsOpenW(
            path_w,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            windows.CREATE_ALWAYS,
            windows.FILE_ATTRIBUTE_NORMAL,
        );
        return openHandle(handle);
    }

    /// If the path does not exist it will be created.
    /// If a file already exists in the destination this returns OpenError.PathAlreadyExists
    /// Call close to clean up.
    pub fn openWriteNoClobber(path: []const u8, file_mode: Mode) OpenError!File {
        if (is_posix) {
            const path_c = try os.toPosixPath(path);
            return openWriteNoClobberC(&path_c, file_mode);
        } else if (is_windows) {
            const path_w = try windows_util.sliceToPrefixedFileW(path);
            return openWriteNoClobberW(&path_w, file_mode);
        } else {
            @compileError("TODO implement openWriteMode for this OS");
        }
    }

    pub fn openWriteNoClobberC(path: [*]const u8, file_mode: Mode) OpenError!File {
        if (is_posix) {
            const flags = posix.O_LARGEFILE | posix.O_WRONLY | posix.O_CREAT | posix.O_CLOEXEC | posix.O_EXCL;
            const fd = try os.posixOpenC(path, flags, file_mode);
            return openHandle(fd);
        } else if (is_windows) {
            const path_w = try windows_util.cStrToPrefixedFileW(path);
            return openWriteNoClobberW(&path_w, file_mode);
        } else {
            @compileError("TODO implement openWriteMode for this OS");
        }
    }

    pub fn openWriteNoClobberW(path_w: [*]const u16, file_mode: Mode) OpenError!File {
        const handle = try os.windowsOpenW(
            path_w,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            windows.CREATE_NEW,
            windows.FILE_ATTRIBUTE_NORMAL,
        );
        return openHandle(handle);
    }

    pub fn openHandle(handle: posix.fd_t) File {
        return File{ .handle = handle };
    }

    /// Test for the existence of `path`.
    /// `path` is UTF8-encoded.
    pub fn exists(path: []const u8) AccessError!void {
        return posix.access(path, posix.F_OK);
    }

    /// Same as `exists` except the parameter is null-terminated UTF16LE-encoded.
    pub fn existsW(path: [*]const u16) AccessError!void {
        return posix.accessW(path, posix.F_OK);
    }

    /// Same as `exists` except the parameter is null-terminated.
    pub fn existsC(path: [*]const u8) AccessError!void {
        return posix.accessC(path, posix.F_OK);
    }

    /// Upon success, the stream is in an uninitialized state. To continue using it,
    /// you must use the open() function.
    pub fn close(self: File) void {
        os.close(self.handle);
    }

    /// Test whether the file refers to a terminal.
    /// See also `supportsAnsiEscapeCodes`.
    pub fn isTty(self: File) bool {
        return posix.isatty(self.handle);
    }

    /// Test whether ANSI escape codes will be treated as such.
    pub fn supportsAnsiEscapeCodes(self: File) bool {
        if (windows.is_the_target) {
            return posix.isCygwinPty(self.handle);
        }
        return self.isTty();
    }

    pub const SeekError = error{
        /// TODO make this error impossible to get
        Overflow,
        Unseekable,
        Unexpected,
    };

    pub fn seekForward(self: File, amount: i64) SeekError!void {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.freebsd, Os.netbsd => {
                const iamount = try math.cast(isize, amount);
                const result = posix.lseek(self.handle, iamount, posix.SEEK_CUR);
                const err = posix.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        // We do not make this an error code because if you get EBADF it's always a bug,
                        // since the fd could have been reused.
                        posix.EBADF => unreachable,
                        posix.EINVAL => error.Unseekable,
                        posix.EOVERFLOW => error.Unseekable,
                        posix.ESPIPE => error.Unseekable,
                        posix.ENXIO => error.Unseekable,
                        else => os.unexpectedErrorPosix(err),
                    };
                }
            },
            Os.windows => {
                if (windows.SetFilePointerEx(self.handle, amount, null, windows.FILE_CURRENT) == 0) {
                    const err = windows.GetLastError();
                    return switch (err) {
                        windows.ERROR.INVALID_PARAMETER => unreachable,
                        else => os.unexpectedErrorWindows(err),
                    };
                }
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn seekTo(self: File, pos: u64) SeekError!void {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.freebsd, Os.netbsd => {
                const ipos = try math.cast(isize, pos);
                const result = posix.lseek(self.handle, ipos, posix.SEEK_SET);
                const err = posix.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        // We do not make this an error code because if you get EBADF it's always a bug,
                        // since the fd could have been reused.
                        posix.EBADF => unreachable,
                        posix.EINVAL => error.Unseekable,
                        posix.EOVERFLOW => error.Unseekable,
                        posix.ESPIPE => error.Unseekable,
                        posix.ENXIO => error.Unseekable,
                        else => os.unexpectedErrorPosix(err),
                    };
                }
            },
            Os.windows => {
                const ipos = try math.cast(isize, pos);
                if (windows.SetFilePointerEx(self.handle, ipos, null, windows.FILE_BEGIN) == 0) {
                    const err = windows.GetLastError();
                    return switch (err) {
                        windows.ERROR.INVALID_PARAMETER => unreachable,
                        windows.ERROR.INVALID_HANDLE => unreachable,
                        else => os.unexpectedErrorWindows(err),
                    };
                }
            },
            else => @compileError("unsupported OS: " ++ @tagName(builtin.os)),
        }
    }

    pub const GetSeekPosError = error{
        SystemResources,
        Unseekable,
        Unexpected,
    };

    pub fn getPos(self: File) GetSeekPosError!u64 {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios, Os.freebsd, Os.netbsd => {
                const result = posix.lseek(self.handle, 0, posix.SEEK_CUR);
                const err = posix.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        // We do not make this an error code because if you get EBADF it's always a bug,
                        // since the fd could have been reused.
                        posix.EBADF => unreachable,
                        posix.EINVAL => error.Unseekable,
                        posix.EOVERFLOW => error.Unseekable,
                        posix.ESPIPE => error.Unseekable,
                        posix.ENXIO => error.Unseekable,
                        else => os.unexpectedErrorPosix(err),
                    };
                }
                return u64(result);
            },
            Os.windows => {
                var pos: windows.LARGE_INTEGER = undefined;
                if (windows.SetFilePointerEx(self.handle, 0, &pos, windows.FILE_CURRENT) == 0) {
                    const err = windows.GetLastError();
                    return switch (err) {
                        windows.ERROR.INVALID_PARAMETER => unreachable,
                        else => os.unexpectedErrorWindows(err),
                    };
                }

                return @intCast(u64, pos);
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn getEndPos(self: File) GetSeekPosError!u64 {
        if (is_posix) {
            const stat = try os.posixFStat(self.handle);
            return @intCast(u64, stat.size);
        } else if (is_windows) {
            var file_size: windows.LARGE_INTEGER = undefined;
            if (windows.GetFileSizeEx(self.handle, &file_size) == 0) {
                const err = windows.GetLastError();
                return switch (err) {
                    else => os.unexpectedErrorWindows(err),
                };
            }
            return @intCast(u64, file_size);
        } else {
            @compileError("TODO support getEndPos on this OS");
        }
    }

    pub const ModeError = error{
        SystemResources,
        Unexpected,
    };

    pub fn mode(self: File) ModeError!Mode {
        if (is_posix) {
            var stat: posix.Stat = undefined;
            const err = posix.getErrno(posix.fstat(self.handle, &stat));
            if (err > 0) {
                return switch (err) {
                    // We do not make this an error code because if you get EBADF it's always a bug,
                    // since the fd could have been reused.
                    posix.EBADF => unreachable,
                    posix.ENOMEM => error.SystemResources,
                    else => os.unexpectedErrorPosix(err),
                };
            }

            // TODO: we should be able to cast u16 to ModeError!u32, making this
            // explicit cast not necessary
            return Mode(stat.mode);
        } else if (is_windows) {
            return {};
        } else {
            @compileError("TODO support file mode on this OS");
        }
    }

    pub const ReadError = posix.ReadError;

    pub fn read(self: File, buffer: []u8) ReadError!usize {
        return posix.read(self.handle, buffer);
    }

    pub const WriteError = posix.WriteError;

    pub fn write(self: File, bytes: []const u8) WriteError!void {
        return posix.write(self.handle, bytes);
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
                .seekForwardFn = SeekableStream.seekForwardFn,
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

        pub const Stream = io.SeekableStream(SeekError, GetSeekPosError);

        pub fn seekToFn(seekable_stream: *Stream, pos: u64) SeekError!void {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.seekTo(pos);
        }

        pub fn seekForwardFn(seekable_stream: *Stream, amt: i64) SeekError!void {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.seekForward(amt);
        }

        pub fn getEndPosFn(seekable_stream: *Stream) GetSeekPosError!u64 {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.getEndPos();
        }

        pub fn getPosFn(seekable_stream: *Stream) GetSeekPosError!u64 {
            const self = @fieldParentPtr(SeekableStream, "stream", seekable_stream);
            return self.file.getPos();
        }
    };

    pub fn stdout() !File {
        const handle = try posix.GetStdHandle(posix.STD_OUTPUT_HANDLE);
        return openHandle(handle);
    }

    pub fn stderr() !File {
        const handle = try posix.GetStdHandle(posix.STD_ERROR_HANDLE);
        return openHandle(handle);
    }

    pub fn stdin() !File {
        const handle = try posix.GetStdHandle(posix.STD_INPUT_HANDLE);
        return openHandle(handle);
    }
};
