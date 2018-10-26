const std = @import("../index.zig");
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

pub const File = struct.{
    /// The OS-specific file descriptor or file handle.
    handle: os.FileHandle,

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
            return openWriteNoClobberC(path_c, file_mode);
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

    pub fn openHandle(handle: os.FileHandle) File {
        return File.{ .handle = handle };
    }

    pub const AccessError = error.{
        PermissionDenied,
        FileNotFound,
        NameTooLong,
        InputOutput,
        SystemResources,
        BadPathName,

        /// On Windows, file paths must be valid Unicode.
        InvalidUtf8,

        Unexpected,
    };

    /// Call from Windows-specific code if you already have a UTF-16LE encoded, null terminated string.
    /// Otherwise use `access` or `accessC`.
    pub fn accessW(path: [*]const u16) AccessError!void {
        if (os.windows.GetFileAttributesW(path) != os.windows.INVALID_FILE_ATTRIBUTES) {
            return;
        }

        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            windows.ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            windows.ERROR.ACCESS_DENIED => return error.PermissionDenied,
            else => return os.unexpectedErrorWindows(err),
        }
    }

    /// Call if you have a UTF-8 encoded, null-terminated string.
    /// Otherwise use `access` or `accessW`.
    pub fn accessC(path: [*]const u8) AccessError!void {
        if (is_windows) {
            const path_w = try windows_util.cStrToPrefixedFileW(path);
            return accessW(&path_w);
        }
        if (is_posix) {
            const result = posix.access(path, posix.F_OK);
            const err = posix.getErrno(result);
            switch (err) {
                0 => return,
                posix.EACCES => return error.PermissionDenied,
                posix.EROFS => return error.PermissionDenied,
                posix.ELOOP => return error.PermissionDenied,
                posix.ETXTBSY => return error.PermissionDenied,
                posix.ENOTDIR => return error.FileNotFound,
                posix.ENOENT => return error.FileNotFound,

                posix.ENAMETOOLONG => return error.NameTooLong,
                posix.EINVAL => unreachable,
                posix.EFAULT => unreachable,
                posix.EIO => return error.InputOutput,
                posix.ENOMEM => return error.SystemResources,
                else => return os.unexpectedErrorPosix(err),
            }
        }
        @compileError("Unsupported OS");
    }

    pub fn access(path: []const u8) AccessError!void {
        if (is_windows) {
            const path_w = try windows_util.sliceToPrefixedFileW(path);
            return accessW(&path_w);
        }
        if (is_posix) {
            var path_with_null: [posix.PATH_MAX]u8 = undefined;
            if (path.len >= posix.PATH_MAX) return error.NameTooLong;
            mem.copy(u8, path_with_null[0..], path);
            path_with_null[path.len] = 0;
            return accessC(&path_with_null);
        }
        @compileError("Unsupported OS");
    }

    /// Upon success, the stream is in an uninitialized state. To continue using it,
    /// you must use the open() function.
    pub fn close(self: File) void {
        os.close(self.handle);
    }

    /// Calls `os.isTty` on `self.handle`.
    pub fn isTty(self: File) bool {
        return os.isTty(self.handle);
    }

    pub fn seekForward(self: File, amount: isize) !void {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
                const result = posix.lseek(self.handle, amount, posix.SEEK_CUR);
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

    pub fn seekTo(self: File, pos: usize) !void {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
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

    pub fn getPos(self: File) !usize {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
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
                return result;
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

                assert(pos >= 0);
                return math.cast(usize, pos) catch error.FilePosLargerThanPointerRange;
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn getEndPos(self: File) !usize {
        if (is_posix) {
            const stat = try os.posixFStat(self.handle);
            return @intCast(usize, stat.size);
        } else if (is_windows) {
            var file_size: windows.LARGE_INTEGER = undefined;
            if (windows.GetFileSizeEx(self.handle, &file_size) == 0) {
                const err = windows.GetLastError();
                return switch (err) {
                    else => os.unexpectedErrorWindows(err),
                };
            }
            if (file_size < 0)
                return error.Overflow;
            return math.cast(usize, @intCast(u64, file_size));
        } else {
            @compileError("TODO support getEndPos on this OS");
        }
    }

    pub const ModeError = error.{
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

    pub const ReadError = os.WindowsReadError || os.PosixReadError;

    pub fn read(self: File, buffer: []u8) ReadError!usize {
        if (is_posix) {
            return os.posixRead(self.handle, buffer);
        } else if (is_windows) {
            var index: usize = 0;
            while (index < buffer.len) {
                const want_read_count = @intCast(windows.DWORD, math.min(windows.DWORD(maxInt(windows.DWORD)), buffer.len - index));
                var amt_read: windows.DWORD = undefined;
                if (windows.ReadFile(self.handle, buffer.ptr + index, want_read_count, &amt_read, null) == 0) {
                    const err = windows.GetLastError();
                    return switch (err) {
                        windows.ERROR.OPERATION_ABORTED => continue,
                        windows.ERROR.BROKEN_PIPE => return index,
                        else => os.unexpectedErrorWindows(err),
                    };
                }
                if (amt_read == 0) return index;
                index += amt_read;
            }
            return index;
        } else {
            @compileError("Unsupported OS");
        }
    }

    pub const WriteError = os.WindowsWriteError || os.PosixWriteError;

    pub fn write(self: File, bytes: []const u8) WriteError!void {
        if (is_posix) {
            try os.posixWrite(self.handle, bytes);
        } else if (is_windows) {
            try os.windowsWrite(self.handle, bytes);
        } else {
            @compileError("Unsupported OS");
        }
    }

    pub fn inStream(file: File) InStream {
        return InStream.{
            .file = file,
            .stream = InStream.Stream.{ .readFn = InStream.readFn },
        };
    }

    pub fn outStream(file: File) OutStream {
        return OutStream.{
            .file = file,
            .stream = OutStream.Stream.{ .writeFn = OutStream.writeFn },
        };
    }

    /// Implementation of io.InStream trait for File
    pub const InStream = struct.{
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
    pub const OutStream = struct.{
        file: File,
        stream: Stream,

        pub const Error = WriteError;
        pub const Stream = io.OutStream(Error);

        fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
            const self = @fieldParentPtr(OutStream, "stream", out_stream);
            return self.file.write(bytes);
        }
    };
};
