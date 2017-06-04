const builtin = @import("builtin");
const Os = builtin.Os;
const system = switch(builtin.os) {
    Os.linux => @import("os/linux.zig"),
    Os.darwin => @import("os/darwin.zig"),
    Os.windows => @import("os/windows/index.zig"),
    else => @compileError("Unsupported OS"),
};

const errno = @import("os/errno.zig");
const math = @import("math.zig");
const debug = @import("debug.zig");
const assert = debug.assert;
const os = @import("os/index.zig");
const mem = @import("mem.zig");
const Buffer = @import("buffer.zig").Buffer;
const fmt = @import("fmt.zig");

const is_posix = builtin.os != builtin.Os.windows;
const is_windows = builtin.os == builtin.Os.windows;

pub var stdin = InStream {
    .fd = if (is_posix) system.STDIN_FILENO else {},
    .handle_id = if (is_windows) system.STD_INPUT_HANDLE else {},
    .handle = if (is_windows) null else {},
};

pub var stdout = OutStream {
    .fd = if (is_posix) system.STDOUT_FILENO else {},
    .handle_id = if (is_windows) system.STD_OUTPUT_HANDLE else {},
    .handle = if (is_windows) null else {},
    .buffer = undefined,
    .index = 0,
};

pub var stderr = OutStream {
    .fd = if (is_posix) system.STDERR_FILENO else {},
    .handle_id = if (is_windows) system.STD_ERROR_HANDLE else {},
    .handle = if (is_windows) null else {},
    .buffer = undefined,
    .index = 0,
};

/// The function received invalid input at runtime. An Invalid error means a
/// bug in the program that called the function.
error Invalid;

/// When an Unexpected error occurs, code that emitted the error likely needs
/// a patch to recognize the unexpected case so that it can handle it and emit
/// a more specific error.
error Unexpected;

error DiskQuota;
error FileTooBig;
error Io;
error NoSpaceLeft;
error BadPerm;
error PipeFail;
error BadFd;
error IsDir;
error NotDir;
error SymLinkLoop;
error ProcessFdQuotaExceeded;
error SystemFdQuotaExceeded;
error NameTooLong;
error NoDevice;
error PathNotFound;
error NoMem;
error Unseekable;
error EndOfFile;
error NoStdHandles;

pub const OpenRead     = 0b0001;
pub const OpenWrite    = 0b0010;
pub const OpenCreate   = 0b0100;
pub const OpenTruncate = 0b1000;

pub const OutStream = struct {
    fd: if (is_posix) i32 else void,
    handle_id: if (is_windows) system.DWORD else void,
    handle: if (is_windows) ?system.HANDLE else void,
    buffer: [os.page_size]u8,
    index: usize,

    /// Calls ::openMode with 0o666 for the mode.
    pub fn open(path: []const u8, allocator: ?&mem.Allocator) -> %OutStream {
        return openMode(path, 0o666, allocator);

    }

    /// `path` may need to be copied in memory to add a null terminating byte. In this case
    /// a fixed size buffer of size std.os.max_noalloc_path_len is an attempted solution. If the fixed
    /// size buffer is too small, and the provided allocator is null, error.NameTooLong is returned.
    /// otherwise if the fixed size buffer is too small, allocator is used to obtain the needed memory.
    /// Call close to clean up.
    pub fn openMode(path: []const u8, mode: usize, allocator: ?&mem.Allocator) -> %OutStream {
        if (is_posix) {
            const flags = system.O_LARGEFILE|system.O_WRONLY|system.O_CREAT|system.O_CLOEXEC|system.O_TRUNC;
            const fd = %return os.posixOpen(path, flags, mode, allocator);
            return OutStream {
                .fd = fd,
                .handle = {},
                .handle_id = {},
                .index = 0,
                .buffer = undefined,
            };
        } else if (is_windows) {
            @compileError("TODO: windows OutStream.openMode");
        } else {
            @compileError("Unsupported OS");
        }

    }

    pub fn writeByte(self: &OutStream, b: u8) -> %void {
        if (self.buffer.len == self.index) %return self.flush();
        self.buffer[self.index] = b;
        self.index += 1;
    }

    pub fn write(self: &OutStream, bytes: []const u8) -> %void {
        if (bytes.len >= self.buffer.len) {
            %return self.flush();
            return self.unbufferedWrite(bytes);
        }

        var src_index: usize = 0;

        while (src_index < bytes.len) {
            const dest_space_left = self.buffer.len - self.index;
            const copy_amt = math.min(dest_space_left, bytes.len - src_index);
            mem.copy(u8, self.buffer[self.index..], bytes[src_index..src_index + copy_amt]);
            self.index += copy_amt;
            assert(self.index <= self.buffer.len);
            if (self.index == self.buffer.len) {
                %return self.flush();
            }
            src_index += copy_amt;
        }
    }

    /// Calls print and then flushes the buffer.
    pub fn printf(self: &OutStream, comptime format: []const u8, args: ...) -> %void {
        %return self.print(format, args);
        %return self.flush();
    }

    /// Does not flush the buffer.
    pub fn print(self: &OutStream, comptime format: []const u8, args: ...) -> %void {
        var context = PrintContext {
            .self = self,
            .result = {},
        };
        _ = fmt.format(&context, printOutput, format, args);
        return context.result;
    }
    const PrintContext = struct {
        self: &OutStream,
        result: %void,
    };
    fn printOutput(context: &PrintContext, bytes: []const u8) -> bool {
        context.self.write(bytes) %% |err| {
            context.result = err;
            return false;
        };
        return true;
    }

    pub fn flush(self: &OutStream) -> %void {
        if (self.index == 0)
            return;

        return self.unbufferedWrite(self.buffer[0..self.index]);
    }

    pub fn close(self: &OutStream) {
        assert(self.index == 0);
        os.posixClose(self.fd);
    }

    pub fn isTty(self: &OutStream) -> %bool {
        if (is_posix) {
            return system.isatty(self.fd);
        } else if (is_windows) {
            return os.windowsIsTty(%return self.getHandle());
        } else {
            @compileError("Unsupported OS");
        }
    }

    fn getHandle(self: &OutStream) -> %system.HANDLE {
        if (self.handle) |handle| return handle;
        if (system.GetStdHandle(self.handle_id)) |handle| {
            if (handle == system.INVALID_HANDLE_VALUE) {
                return error.Unexpected;
            }
            self.handle = handle;
            return handle;
        } else {
            return error.NoStdHandles;
        }
    }

    fn unbufferedWrite(self: &OutStream, bytes: []const u8) -> %void {
        if (is_posix) {
            %return os.posixWrite(self.fd, self.buffer[0..self.index]);
            self.index = 0;
        } else if (is_windows) {
            const handle = %return self.getHandle();
            %return os.windowsWrite(handle, self.buffer[0..self.index]);
            self.index = 0;
        } else {
            @compileError("Unsupported OS");
        }
    }

};

// TODO created a BufferedInStream struct and move some of this code there
// BufferedInStream API goes on top of minimal InStream API.
pub const InStream = struct {
    fd: if (is_posix) i32 else void,
    handle_id: if (is_windows) system.DWORD else void,
    handle: if (is_windows) ?system.HANDLE else void,

    /// `path` may need to be copied in memory to add a null terminating byte. In this case
    /// a fixed size buffer of size std.os.max_noalloc_path_len is an attempted solution. If the fixed
    /// size buffer is too small, and the provided allocator is null, error.NameTooLong is returned.
    /// otherwise if the fixed size buffer is too small, allocator is used to obtain the needed memory.
    /// Call close to clean up.
    pub fn open(path: []const u8, allocator: ?&mem.Allocator) -> %InStream {
        if (is_posix) {
            const flags = system.O_LARGEFILE|system.O_RDONLY;
            const fd = %return os.posixOpen(path, flags, 0, allocator);
            return InStream {
                .fd = fd,
                .handle_id = {},
                .handle = {},
            };
        } else if (is_windows) {
            @compileError("TODO windows InStream.open");
        } else {
            @compileError("Unsupported OS");
        }
    }

    /// Upon success, the stream is in an uninitialized state. To continue using it,
    /// you must use the open() function.
    pub fn close(self: &InStream) {
        if (is_posix) {
            os.posixClose(self.fd);
        } else {
            @compileError("Unsupported OS");
        }
    }

    /// Returns the number of bytes read. If the number read is smaller than buf.len, then
    /// the stream reached End Of File.
    pub fn read(is: &InStream, buf: []u8) -> %usize {
        if (is_posix) {
            var index: usize = 0;
            while (index < buf.len) {
                const amt_read = system.read(is.fd, &buf[index], buf.len - index);
                const read_err = system.getErrno(amt_read);
                if (read_err > 0) {
                    switch (read_err) {
                        errno.EINTR  => continue,
                        errno.EINVAL => unreachable,
                        errno.EFAULT => unreachable,
                        errno.EBADF  => return error.BadFd,
                        errno.EIO    => return error.Io,
                        else         => return error.Unexpected,
                    }
                }
                if (amt_read == 0) return index;
                index += amt_read;
            }
            return index;
        } else if (is_windows) {
            @compileError("TODO windows read impl");
        } else {
            @compileError("Unsupported OS");
        }
    }

    pub fn readNoEof(is: &InStream, buf: []u8) -> %void {
        const amt_read = %return is.read(buf);
        if (amt_read < buf.len) return error.EndOfFile;
    }

    pub fn readByte(is: &InStream) -> %u8 {
        var result: [1]u8 = undefined;
        %return is.readNoEof(result[0..]);
        return result[0];
    }

    pub fn readByteSigned(is: &InStream) -> %i8 {
        var result: [1]i8 = undefined;
        %return is.readNoEof(([]u8)(result[0..]));
        return result[0];
    }

    pub fn readIntLe(is: &InStream, comptime T: type) -> %T {
        is.readInt(false, T)
    }

    pub fn readIntBe(is: &InStream, comptime T: type) -> %T {
        is.readInt(true, T)
    }

    pub fn readInt(is: &InStream, is_be: bool, comptime T: type) -> %T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        %return is.readNoEof(bytes[0..]);
        return mem.readInt(bytes, T, is_be);
    }

    pub fn readVarInt(is: &InStream, is_be: bool, comptime T: type, size: usize) -> %T {
        assert(size <= @sizeOf(T));
        assert(size <= 8);
        var input_buf: [8]u8 = undefined;
        const input_slice = input_buf[0..size];
        %return is.readNoEof(input_slice);
        return mem.readInt(input_slice, T, is_be);
    }

    pub fn seekForward(is: &InStream, amount: usize) -> %void {
        switch (builtin.os) {
            Os.linux, Os.darwin => {
                const result = system.lseek(is.fd, amount, system.SEEK_CUR);
                const err = system.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        errno.EBADF => error.BadFd,
                        errno.EINVAL => error.Unseekable,
                        errno.EOVERFLOW => error.Unseekable,
                        errno.ESPIPE => error.Unseekable,
                        errno.ENXIO => error.Unseekable,
                        else => error.Unexpected,
                    };
                }
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn seekTo(is: &InStream, pos: usize) -> %void {
        switch (builtin.os) {
            Os.linux, Os.darwin => {
                const result = system.lseek(is.fd, pos, system.SEEK_SET);
                const err = system.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        errno.EBADF => error.BadFd,
                        errno.EINVAL => error.Unseekable,
                        errno.EOVERFLOW => error.Unseekable,
                        errno.ESPIPE => error.Unseekable,
                        errno.ENXIO => error.Unseekable,
                        else => error.Unexpected,
                    };
                }
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn getPos(is: &InStream) -> %usize {
        switch (builtin.os) {
            Os.linux, Os.darwin => {
                const result = system.lseek(is.fd, 0, system.SEEK_CUR);
                const err = system.getErrno(result);
                if (err > 0) {
                    return switch (err) {
                        errno.EBADF => error.BadFd,
                        errno.EINVAL => error.Unseekable,
                        errno.EOVERFLOW => error.Unseekable,
                        errno.ESPIPE => error.Unseekable,
                        errno.ENXIO => error.Unseekable,
                        else => error.Unexpected,
                    };
                }
                return result;
            },
            else => @compileError("unsupported OS"),
        }
    }

    pub fn getEndPos(is: &InStream) -> %usize {
        var stat: system.stat = undefined;
        const err = system.getErrno(system.fstat(is.fd, &stat));
        if (err > 0) {
            return switch (err) {
                errno.EBADF => error.BadFd,
                errno.ENOMEM => error.NoMem,
                else => error.Unexpected,
            }
        }

        return usize(stat.size);
    }

    pub fn readAll(is: &InStream, buf: &Buffer) -> %void {
        %return buf.resize(os.page_size);

        var actual_buf_len: usize = 0;
        while (true) {
            const dest_slice = buf.toSlice()[actual_buf_len..];
            const bytes_read = %return is.read(dest_slice);
            actual_buf_len += bytes_read;

            if (bytes_read != dest_slice.len) {
                return buf.resize(actual_buf_len);
            }

            %return buf.resize(actual_buf_len + os.page_size);
        }
    }

    pub fn isTty(self: &InStream) -> %bool {
        if (is_posix) {
            return system.isatty(self.fd);
        } else if (is_windows) {
            return os.windowsIsTty(%return self.getHandle());
        } else {
            @compileError("Unsupported OS");
        }
    }

    fn getHandle(self: &InStream) -> %system.HANDLE {
        if (self.handle) |handle| return handle;
        if (system.GetStdHandle(self.handle_id)) |handle| {
            if (handle == system.INVALID_HANDLE_VALUE) {
                return error.Unexpected;
            }
            self.handle = handle;
            return handle;
        } else {
            return error.NoStdHandles;
        }
    }
};

pub fn openSelfExe() -> %InStream {
    switch (builtin.os) {
        Os.linux => {
            return InStream.open("/proc/self/exe", null);
        },
        Os.darwin => {
            debug.panic("TODO: openSelfExe on Darwin");
        },
        else => @compileError("Unsupported OS"),
    }
}

/// `path` may need to be copied in memory to add a null terminating byte. In this case
/// a fixed size buffer of size std.os.max_noalloc_path_len is an attempted solution. If the fixed
/// size buffer is too small, and the provided allocator is null, error.NameTooLong is returned.
/// otherwise if the fixed size buffer is too small, allocator is used to obtain the needed memory.
pub fn writeFile(path: []const u8, data: []const u8, allocator: ?&mem.Allocator) -> %void {
    // TODO have an unbuffered File abstraction and use that here.
    // Then a buffered out stream abstraction can go on top of that for
    // use cases like stdout and stderr.
    var out_stream = %return OutStream.open(path, allocator);
    defer out_stream.close();
    %return out_stream.write(data);
    %return out_stream.flush();
}
