const std = @import("../index.zig");
const builtin = @import("builtin");
const os = std.os;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const posix = os.posix;
const windows = os.windows;
const Os = builtin.Os;

const is_posix = builtin.os != builtin.Os.windows;
const is_windows = builtin.os == builtin.Os.windows;

pub const File = struct {
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

    /// `path` needs to be copied in memory to add a null terminating byte, hence the allocator.
    /// Call close to clean up.
    /// TODO deprecated, just use open
    pub fn openRead(allocator: *mem.Allocator, path: []const u8) OpenError!File {
        if (is_posix) {
            const flags = posix.O_LARGEFILE | posix.O_RDONLY;
            const fd = try os.posixOpen(allocator, path, flags, 0);
            return openHandle(fd);
        } else if (is_windows) {
            const handle = try os.windowsOpen(
                allocator,
                path,
                windows.GENERIC_READ,
                windows.FILE_SHARE_READ,
                windows.OPEN_EXISTING,
                windows.FILE_ATTRIBUTE_NORMAL,
            );
            return openHandle(handle);
        } else {
            @compileError("TODO implement openRead for this OS");
        }
    }

    /// Calls `openWriteMode` with os.File.default_mode for the mode.
    /// TODO deprecated, just use open
    pub fn openWrite(allocator: *mem.Allocator, path: []const u8) OpenError!File {
        return openWriteMode(allocator, path, os.File.default_mode);
    }

    /// If the path does not exist it will be created.
    /// If a file already exists in the destination it will be truncated.
    /// `path` needs to be copied in memory to add a null terminating byte, hence the allocator.
    /// Call close to clean up.
    /// TODO deprecated, just use open
    pub fn openWriteMode(allocator: *mem.Allocator, path: []const u8, file_mode: Mode) OpenError!File {
        if (is_posix) {
            const flags = posix.O_LARGEFILE | posix.O_WRONLY | posix.O_CREAT | posix.O_CLOEXEC | posix.O_TRUNC;
            const fd = try os.posixOpen(allocator, path, flags, file_mode);
            return openHandle(fd);
        } else if (is_windows) {
            const handle = try os.windowsOpen(
                allocator,
                path,
                windows.GENERIC_WRITE,
                windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
                windows.CREATE_ALWAYS,
                windows.FILE_ATTRIBUTE_NORMAL,
            );
            return openHandle(handle);
        } else {
            @compileError("TODO implement openWriteMode for this OS");
        }
    }

    /// If the path does not exist it will be created.
    /// If a file already exists in the destination this returns OpenError.PathAlreadyExists
    /// `path` needs to be copied in memory to add a null terminating byte, hence the allocator.
    /// Call close to clean up.
    /// TODO deprecated, just use open
    pub fn openWriteNoClobber(allocator: *mem.Allocator, path: []const u8, file_mode: Mode) OpenError!File {
        if (is_posix) {
            const flags = posix.O_LARGEFILE | posix.O_WRONLY | posix.O_CREAT | posix.O_CLOEXEC | posix.O_EXCL;
            const fd = try os.posixOpen(allocator, path, flags, file_mode);
            return openHandle(fd);
        } else if (is_windows) {
            const handle = try os.windowsOpen(
                allocator,
                path,
                windows.GENERIC_WRITE,
                windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
                windows.CREATE_NEW,
                windows.FILE_ATTRIBUTE_NORMAL,
            );
            return openHandle(handle);
        } else {
            @compileError("TODO implement openWriteMode for this OS");
        }
    }

    pub fn openHandle(handle: os.FileHandle) File {
        return File{ .handle = handle };
    }

    pub const AccessError = error{
        PermissionDenied,
        NotFound,
        NameTooLong,
        BadMode,
        BadPathName,
        Io,
        SystemResources,
        OutOfMemory,

        Unexpected,
    };

    pub fn access(allocator: *mem.Allocator, path: []const u8) AccessError!void {
        const path_with_null = try std.cstr.addNullByte(allocator, path);
        defer allocator.free(path_with_null);

        if (is_posix) {
            const result = posix.access(path_with_null.ptr, posix.F_OK);
            const err = posix.getErrno(result);
            switch (err) {
                0 => return,
                posix.EACCES => return error.PermissionDenied,
                posix.EROFS => return error.PermissionDenied,
                posix.ELOOP => return error.PermissionDenied,
                posix.ETXTBSY => return error.PermissionDenied,
                posix.ENOTDIR => return error.NotFound,
                posix.ENOENT => return error.NotFound,

                posix.ENAMETOOLONG => return error.NameTooLong,
                posix.EINVAL => unreachable,
                posix.EFAULT => return error.BadPathName,
                posix.EIO => return error.Io,
                posix.ENOMEM => return error.SystemResources,
                else => return os.unexpectedErrorPosix(err),
            }
        } else if (is_windows) {
            if (os.windows.GetFileAttributesA(path_with_null.ptr) != os.windows.INVALID_FILE_ATTRIBUTES) {
                return;
            }

            const err = windows.GetLastError();
            switch (err) {
                windows.ERROR.FILE_NOT_FOUND,
                windows.ERROR.PATH_NOT_FOUND,
                => return error.NotFound,
                windows.ERROR.ACCESS_DENIED => return error.PermissionDenied,
                else => return os.unexpectedErrorWindows(err),
            }
        } else {
            @compileError("TODO implement access for this OS");
        }
    }

    /// Upon success, the stream is in an uninitialized state. To continue using it,
    /// you must use the open() function.
    pub fn close(self: *File) void {
        os.close(self.handle);
        self.handle = undefined;
    }

    /// Calls `os.isTty` on `self.handle`.
    pub fn isTty(self: *File) bool {
        return os.isTty(self.handle);
    }

    pub fn seekForward(self: *File, amount: isize) !void {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
                const result = posix.lseek(self.handle, amount, posix.SEEK_CUR);
                const err = posix.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        posix.EBADF => error.BadFd,
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
                        windows.ERROR.INVALID_PARAMETER => error.BadFd,
                        else => os.unexpectedErrorWindows(err),
                    };
                }
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn seekTo(self: *File, pos: usize) !void {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
                const ipos = try math.cast(isize, pos);
                const result = posix.lseek(self.handle, ipos, posix.SEEK_SET);
                const err = posix.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        posix.EBADF => error.BadFd,
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
                        windows.ERROR.INVALID_PARAMETER => error.BadFd,
                        else => os.unexpectedErrorWindows(err),
                    };
                }
            },
            else => @compileError("unsupported OS: " ++ @tagName(builtin.os)),
        }
    }

    pub fn getPos(self: *File) !usize {
        switch (builtin.os) {
            Os.linux, Os.macosx, Os.ios => {
                const result = posix.lseek(self.handle, 0, posix.SEEK_CUR);
                const err = posix.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        posix.EBADF => error.BadFd,
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
                        windows.ERROR.INVALID_PARAMETER => error.BadFd,
                        else => os.unexpectedErrorWindows(err),
                    };
                }

                assert(pos >= 0);
                return math.cast(usize, pos) catch error.FilePosLargerThanPointerRange;
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn getEndPos(self: *File) !usize {
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

    pub const ModeError = error{
        BadFd,
        SystemResources,
        Unexpected,
    };

    pub fn mode(self: *File) ModeError!Mode {
        if (is_posix) {
            var stat: posix.Stat = undefined;
            const err = posix.getErrno(posix.fstat(self.handle, &stat));
            if (err > 0) {
                return switch (err) {
                    posix.EBADF => error.BadFd,
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

    pub const ReadError = error{
        FileClosed,
        InputOutput,
        IsDir,
        WouldBlock,
        SystemResources,

        Unexpected,
    };

    pub fn read(self: *File, buffer: []u8) ReadError!usize {
        if (is_posix) {
            var index: usize = 0;
            while (index < buffer.len) {
                const amt_read = posix.read(self.handle, buffer.ptr + index, buffer.len - index);
                const read_err = posix.getErrno(amt_read);
                if (read_err > 0) {
                    switch (read_err) {
                        posix.EINTR => continue,
                        posix.EINVAL => unreachable,
                        posix.EFAULT => unreachable,
                        posix.EAGAIN => return error.WouldBlock,
                        posix.EBADF => return error.FileClosed,
                        posix.EIO => return error.InputOutput,
                        posix.EISDIR => return error.IsDir,
                        posix.ENOBUFS => return error.SystemResources,
                        posix.ENOMEM => return error.SystemResources,
                        else => return os.unexpectedErrorPosix(read_err),
                    }
                }
                if (amt_read == 0) return index;
                index += amt_read;
            }
            return index;
        } else if (is_windows) {
            var index: usize = 0;
            while (index < buffer.len) {
                const want_read_count = @intCast(windows.DWORD, math.min(windows.DWORD(@maxValue(windows.DWORD)), buffer.len - index));
                var amt_read: windows.DWORD = undefined;
                if (windows.ReadFile(self.handle, @ptrCast(*c_void, buffer.ptr + index), want_read_count, &amt_read, null) == 0) {
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
            unreachable;
        }
    }

    pub const WriteError = os.WindowsWriteError || os.PosixWriteError;

    pub fn write(self: *File, bytes: []const u8) WriteError!void {
        if (is_posix) {
            try os.posixWrite(self.handle, bytes);
        } else if (is_windows) {
            try os.windowsWrite(self.handle, bytes);
        } else {
            @compileError("Unsupported OS");
        }
    }
};
