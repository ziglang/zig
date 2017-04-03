const system = switch(@compileVar("os")) {
    Os.linux => @import("os/linux.zig"),
    Os.darwin => @import("os/darwin.zig"),
    else => @compileError("Unsupported OS"),
};

const errno = @import("os/errno.zig");
const math = @import("math.zig");
const debug = @import("debug.zig");
const assert = debug.assert;
const os = @import("os/index.zig");
const mem = @import("mem.zig");
const Buffer0 = @import("cstr.zig").Buffer0;
const fmt = @import("fmt.zig");

pub var stdin = InStream {
    .fd = system.STDIN_FILENO,
};

pub var stdout = OutStream {
    .fd = system.STDOUT_FILENO,
    .buffer = undefined,
    .index = 0,
};

pub var stderr = OutStream {
    .fd = system.STDERR_FILENO,
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
error Eof;

const buffer_size = 4 * 1024;

pub const OpenRead     = 0b0001;
pub const OpenWrite    = 0b0010;
pub const OpenCreate   = 0b0100;
pub const OpenTruncate = 0b1000;

pub const OutStream = struct {
    fd: i32,
    buffer: [buffer_size]u8,
    index: usize,

    /// `path` may need to be copied in memory to add a null terminating byte. In this case
    /// a fixed size buffer of size std.os.max_noalloc_path_len is an attempted solution. If the fixed
    /// size buffer is too small, and the provided allocator is null, error.NameTooLong is returned.
    /// otherwise if the fixed size buffer is too small, allocator is used to obtain the needed memory.
    /// Call close to clean up.
    pub fn open(path: []const u8, allocator: ?&mem.Allocator) -> %OutStream {
        switch (@compileVar("os")) {
            Os.linux, Os.darwin, Os.macosx, Os.ios => {
                const flags = system.O_LARGEFILE|system.O_WRONLY|system.O_CREAT|system.O_CLOEXEC|system.O_TRUNC;
                const fd = %return os.posixOpen(path, flags, 0o666, allocator);
                return OutStream {
                    .fd = fd,
                    .index = 0,
                    .buffer = undefined,
                };
            },
            else => @compileError("Unsupported OS"),
        }

    }

    pub fn writeByte(self: &OutStream, b: u8) -> %void {
        if (self.buffer.len == self.index) %return self.flush();
        self.buffer[self.index] = b;
        self.index += 1;
    }

    pub fn write(self: &OutStream, bytes: []const u8) -> %void {
        if (bytes.len >= buffer_size) {
            %return self.flush();
            return os.posixWrite(self.fd, bytes);
        }

        var src_index: usize = 0;

        while (src_index < bytes.len) {
            const dest_space_left = self.buffer.len - self.index;
            const copy_amt = math.min(dest_space_left, bytes.len - src_index);
            mem.copy(u8, self.buffer[self.index...], bytes[src_index...src_index + copy_amt]);
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
        if (self.index != 0) {
            %return os.posixWrite(self.fd, self.buffer[0...self.index]);
            self.index = 0;
        }
    }

    pub fn close(self: &OutStream) {
        assert(self.index == 0);
        os.posixClose(self.fd);
    }
};

// TODO created a BufferedInStream struct and move some of this code there
// BufferedInStream API goes on top of minimal InStream API.
pub const InStream = struct {
    fd: i32,

    /// `path` may need to be copied in memory to add a null terminating byte. In this case
    /// a fixed size buffer of size std.os.max_noalloc_path_len is an attempted solution. If the fixed
    /// size buffer is too small, and the provided allocator is null, error.NameTooLong is returned.
    /// otherwise if the fixed size buffer is too small, allocator is used to obtain the needed memory.
    /// Call close to clean up.
    pub fn open(path: []const u8, allocator: ?&mem.Allocator) -> %InStream {
        switch (@compileVar("os")) {
            Os.linux, Os.darwin, Os.macosx, Os.ios => {
                const flags = system.O_LARGEFILE|system.O_RDONLY;
                const fd = %return os.posixOpen(path, flags, 0, allocator);
                return InStream {
                    .fd = fd,
                };
            },
            else => @compileError("Unsupported OS"),
        }
    }

    /// Upon success, the stream is in an uninitialized state. To continue using it,
    /// you must use the open() function.
    pub fn close(self: &InStream) {
        switch (@compileVar("os")) {
            Os.linux, Os.darwin, Os.macosx, Os.ios => {
                os.posixClose(self.fd);
            },
            else => @compileError("Unsupported OS"),
        }
    }

    /// Returns the number of bytes read. If the number read is smaller than buf.len, then
    /// the stream reached End Of File.
    pub fn read(is: &InStream, buf: []u8) -> %usize {
        switch (@compileVar("os")) {
            Os.linux, Os.darwin => {
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
            },
            else => @compileError("Unsupported OS"),
        }
    }

    pub fn readNoEof(is: &InStream, buf: []u8) -> %void {
        const amt_read = %return is.read(buf);
        if (amt_read < buf.len) return error.Eof;
    }

    pub fn readByte(is: &InStream) -> %u8 {
        var result: [1]u8 = undefined;
        %return is.readNoEof(result[0...]);
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
        %return is.readNoEof(bytes[0...]);
        return mem.readInt(bytes, T, is_be);
    }

    pub fn readVarInt(is: &InStream, is_be: bool, comptime T: type, size: usize) -> %T {
        assert(size <= @sizeOf(T));
        assert(size <= 8);
        var input_buf: [8]u8 = undefined;
        const input_slice = input_buf[0...size];
        %return is.readNoEof(input_slice);
        return mem.readInt(input_slice, T, is_be);
    }

    pub fn seekForward(is: &InStream, amount: usize) -> %void {
        switch (@compileVar("os")) {
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
        switch (@compileVar("os")) {
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
        switch (@compileVar("os")) {
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

    pub fn readAll(is: &InStream, buf: &Buffer0) -> %void {
        %return buf.resize(buffer_size);

        var actual_buf_len: usize = 0;
        while (true) {
            const dest_slice = buf.toSlice()[actual_buf_len...];
            const bytes_read = %return is.read(dest_slice);
            actual_buf_len += bytes_read;

            if (bytes_read != dest_slice.len) {
                return buf.resize(actual_buf_len);
            }

            %return buf.resize(actual_buf_len + buffer_size);
        }
    }
};

pub fn openSelfExe() -> %InStream {
    switch (@compileVar("os")) {
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
