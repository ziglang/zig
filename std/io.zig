const system = switch(@compileVar("os")) {
    Os.linux => @import("linux.zig"),
    Os.darwin => @import("darwin.zig"),
    else => @compileError("Unsupported OS"),
};

const errno = @import("errno.zig");
const math = @import("math.zig");
const endian = @import("endian.zig");
const debug = @import("debug.zig");
const assert = debug.assert;
const os = @import("os.zig");
const mem = @import("mem.zig");

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
const max_u64_base10_digits = 20;
const max_f64_digits = 65;

pub const OpenRead     = 0b0001;
pub const OpenWrite    = 0b0010;
pub const OpenCreate   = 0b0100;
pub const OpenTruncate = 0b1000;

pub struct OutStream {
    fd: i32,
    buffer: [buffer_size]u8,
    index: usize,

    pub fn writeByte(self: &OutStream, b: u8) -> %void {
        if (self.buffer.len == self.index) %return self.flush();
        self.buffer[self.index] = b;
        self.index += 1;
    }

    pub fn write(self: &OutStream, bytes: []const u8) -> %usize {
        var src_bytes_left = bytes.len;
        var src_index: @typeOf(bytes.len) = 0;
        const dest_space_left = self.buffer.len - self.index;

        while (src_bytes_left > 0) {
            const copy_amt = math.min(dest_space_left, src_bytes_left);
            @memcpy(&self.buffer[self.index], &bytes[src_index], copy_amt);
            self.index += copy_amt;
            if (self.index == self.buffer.len) {
                %return self.flush();
            }
            src_bytes_left -= copy_amt;
        }
        return bytes.len;
    }

    /// Prints a byte buffer, flushes the buffer, then returns the number of
    /// bytes printed. The "f" is for "flush".
    pub fn printf(self: &OutStream, str: []const u8) -> %usize {
        const byte_count = %return self.write(str);
        %return self.flush();
        return byte_count;
    }

    pub fn printInt(self: &OutStream, inline T: type, x: T) -> %usize {
        // TODO replace max_u64_base10_digits with math.log10(math.pow(2, @sizeOf(T)))
        if (self.index + max_u64_base10_digits >= self.buffer.len) {
            %return self.flush();
        }
        const amt_printed = bufPrintInt(T, self.buffer[self.index...], x);
        self.index += amt_printed;
        return amt_printed;
    }

    pub fn flush(self: &OutStream) -> %void {
        while (true) {
            const write_ret = system.write(self.fd, &self.buffer[0], self.index);
            const write_err = system.getErrno(write_ret);
            if (write_err > 0) {
                return switch (write_err) {
                    errno.EINTR  => continue,
                    errno.EINVAL => @unreachable(),
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

    pub fn close(self: &OutStream) -> %void {
        while (true) {
            const close_ret = system.close(self.fd);
            const close_err = system.getErrno(close_ret);
            if (close_err > 0) {
                return switch (close_err) {
                    errno.EINTR => continue,

                    errno.EIO   => error.Io,
                    errno.EBADF => error.BadFd,
                    else        => error.Unexpected,
                }
            }
            return;
        }
    }
}

// TODO created a BufferedInStream struct and move some of this code there
// BufferedInStream API goes on top of minimal InStream API.
pub struct InStream {
    fd: i32,

    /// Call close to clean up.
    pub fn open(is: &InStream, path: []const u8) -> %void {
        switch (@compileVar("os")) {
            linux, darwin => {
                while (true) {
                    const result = system.open(path, system.O_LARGEFILE|system.O_RDONLY, 0);
                    const err = system.getErrno(result);
                    if (err > 0) {
                        return switch (err) {
                            errno.EINTR => continue,

                            errno.EFAULT => @unreachable(),
                            errno.EINVAL => @unreachable(),
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
            linux, darwin => {
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
            linux, darwin => {
                var index: usize = 0;
                while (index < buf.len) {
                    const amt_read = system.read(is.fd, &buf[index], buf.len - index);
                    const read_err = system.getErrno(amt_read);
                    if (read_err > 0) {
                        switch (read_err) {
                            errno.EINTR  => continue,

                            errno.EINVAL => @unreachable(),
                            errno.EFAULT => @unreachable(),
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
        %return is.readNoEof(result);
        return result[0];
    }

    pub fn readIntLe(is: &InStream, inline T: type) -> %T {
        is.readInt(false, T)
    }

    pub fn readIntBe(is: &InStream, inline T: type) -> %T {
        is.readInt(true, T)
    }

    pub fn readInt(is: &InStream, is_be: bool, inline T: type) -> %T {
        var result: T = undefined;
        const result_slice = ([]u8)((&result)[0...1]);
        %return is.readNoEof(result_slice);
        return endian.swapIf(!is_be, T, result);
    }

    pub fn readVarInt(is: &InStream, is_be: bool, inline T: type, size: usize) -> %T {
        assert(size <= @sizeOf(T));
        assert(size <= 8);
        var input_buf: [8]u8 = undefined;
        const input_slice = input_buf[0...size];
        %return is.readNoEof(input_slice);
        return mem.sliceAsInt(input_slice, is_be, T);
    }

    pub fn seekForward(is: &InStream, amount: usize) -> %void {
        switch (@compileVar("os")) {
            linux, darwin => {
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
            linux, darwin => {
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
            linux, darwin => {
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
}

pub fn parseUnsigned(inline T: type, buf: []u8, radix: u8) -> %T {
    var x: T = 0;

    for (buf) |c| {
        const digit = %return charToDigit(c, radix);
        x = %return math.mulOverflow(T, x, radix);
        x = %return math.addOverflow(T, x, digit);
    }

    return x;
}

error InvalidChar;
fn charToDigit(c: u8, radix: u8) -> %u8 {
    const value = if ('0' <= c && c <= '9') {
        c - '0'
    } else if ('A' <= c && c <= 'Z') {
        c - 'A' + 10
    } else if ('a' <= c && c <= 'z') {
        c - 'a' + 10
    } else {
        return error.InvalidChar;
    };
    return if (value >= radix) error.InvalidChar else value;
}

pub fn bufPrintInt(inline T: type, out_buf: []u8, x: T) -> usize {
    if (T.is_signed) bufPrintSigned(T, out_buf, x) else bufPrintUnsigned(T, out_buf, x)
}

fn bufPrintSigned(inline T: type, out_buf: []u8, x: T) -> usize {
    const uint = @intType(false, T.bit_count);
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + bufPrintUnsigned(uint, out_buf[1...], uint(-(x + 1)) + 1);
    } else {
        return bufPrintUnsigned(uint, out_buf, uint(x));
    }
}

fn bufPrintUnsigned(inline T: type, out_buf: []u8, x: T) -> usize {
    var buf: [max_u64_base10_digits]u8 = undefined;
    var a = x;
    var index: usize = buf.len;

    while (true) {
        const digit = a % 10;
        index -= 1;
        buf[index] = '0' + u8(digit);
        a /= 10;
        if (a == 0)
            break;
    }

    const len = buf.len - index;

    @memcpy(&out_buf[0], &buf[index], len);

    return len;
}

fn parseU64DigitTooBig() {
    @setFnTest(this, true);

    parseUnsigned(u64, "123a", 10) %% |err| {
        if (err == error.InvalidChar) return;
        @unreachable();
    };
    @unreachable();
}

pub fn openSelfExe(stream: &InStream) -> %void {
    switch (@compileVar("os")) {
        linux => {
            %return stream.open("/proc/self/exe");
        },
        darwin => {
            %%stderr.printf("TODO: openSelfExe on Darwin\n");
            os.abort();
        },
        else => @compileError("unsupported os"),
    }
}
