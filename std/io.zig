const system = switch(@compileVar("os")) {
    Os.linux => @import("linux.zig"),
    Os.darwin => @import("darwin.zig"),
    else => @compileError("Unsupported OS"),
};

const errno = @import("errno.zig");
const math = @import("math.zig");
const debug = @import("debug.zig");
const assert = debug.assert;
const os = @import("os.zig");
const mem = @import("mem.zig");
const Buffer0 = @import("cstr.zig").Buffer0;
const fmt = @import("fmt.zig");

pub const stdin_fileno = 0;
pub const stdout_fileno = 1;
pub const stderr_fileno = 2;

pub var stdin = InStream {
    .fd = stdin_fileno,
};

pub var stdout = OutStream {
    .fd = stdout_fileno,
    .buffer = undefined,
    .index = 0,
};

pub var stderr = OutStream {
    .fd = stderr_fileno,
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

    pub fn writeByte(self: &OutStream, b: u8) -> %void {
        if (self.buffer.len == self.index) %return self.flush();
        self.buffer[self.index] = b;
        self.index += 1;
    }

    pub fn write(self: &OutStream, bytes: []const u8) -> %void {
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
        while (true) {
            const write_ret = system.write(self.fd, &self.buffer[0], self.index);
            const write_err = system.getErrno(write_ret);
            if (write_err > 0) {
                return switch (write_err) {
                    errno.EINTR  => continue,
                    errno.EINVAL => unreachable,
                    errno.EDQUOT => error.DiskQuota,
                    errno.EFBIG  => error.FileTooBig,
                    errno.EIO    => error.Io,
                    errno.ENOSPC => error.NoSpaceLeft,
                    errno.EPERM  => error.BadPerm,
                    errno.EPIPE  => error.PipeFail,
                    else         => error.Unexpected,
                }
            }
            self.index = 0;
            return;
        }
    }

    pub fn close(self: &OutStream) {
        while (true) {
            const close_ret = system.close(self.fd);
            const close_err = system.getErrno(close_ret);
            if (close_err > 0 and close_err == errno.EINTR)
                continue;
            return;
        }
    }
};

// TODO created a BufferedInStream struct and move some of this code there
// BufferedInStream API goes on top of minimal InStream API.
pub const InStream = struct {
    fd: i32,

    /// Call close to clean up.
    pub fn open(is: &InStream, path: []const u8) -> %void {
        switch (@compileVar("os")) {
            Os.linux, Os.darwin => {
                while (true) {
                    const result = system.open(path, system.O_LARGEFILE|system.O_RDONLY, 0);
                    const err = system.getErrno(result);
                    if (err > 0) {
                        return switch (err) {
                            errno.EINTR => continue,

                            errno.EFAULT => unreachable,
                            errno.EINVAL => unreachable,
                            errno.EACCES => error.BadPerm,
                            errno.EFBIG, errno.EOVERFLOW => error.FileTooBig,
                            errno.EISDIR => error.IsDir,
                            errno.ELOOP => error.SymLinkLoop,
                            errno.EMFILE => error.ProcessFdQuotaExceeded,
                            errno.ENAMETOOLONG => error.NameTooLong,
                            errno.ENFILE => error.SystemFdQuotaExceeded,
                            errno.ENODEV => error.NoDevice,
                            errno.ENOENT => error.PathNotFound,
                            errno.ENOMEM => error.NoMem,
                            errno.ENOSPC => error.NoSpaceLeft,
                            errno.ENOTDIR => error.NotDir,
                            errno.EPERM => error.BadPerm,
                            else => error.Unexpected,
                        }
                    }
                    is.fd = i32(result);
                    return;
                }
            },
            else => @compileError("unsupported OS"),
        }

    }

    /// Upon success, the stream is in an uninitialized state. To continue using it,
    /// you must use the open() function.
    pub fn close(is: &InStream) -> %void {
        switch (@compileVar("os")) {
            Os.linux, Os.darwin => {
                while (true) {
                    const close_ret = system.close(is.fd);
                    const close_err = system.getErrno(close_ret);
                    if (close_err > 0) {
                        return switch (close_err) {
                            errno.EINTR => continue,

                            errno.EIO => error.Io,
                            errno.EBADF => error.BadFd,
                            else => error.Unexpected,
                        }
                    }
                    return;
                }
            },
            else => @compileError("unsupported OS"),
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
            else => @compileError("unsupported OS"),
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

pub fn openSelfExe(stream: &InStream) -> %void {
    switch (@compileVar("os")) {
        Os.linux => {
            %return stream.open("/proc/self/exe");
        },
        Os.darwin => {
            %%stderr.printf("TODO: openSelfExe on Darwin\n");
            os.abort();
        },
        else => @compileError("unsupported os"),
    }
}
