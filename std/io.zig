const linux = @import("linux.zig");
const errno = @import("errno.zig");
const math = @import("math.zig");
const endian = @import("endian.zig");
const debug = @import("debug.zig");
const assert = debug.assert;

pub const stdin_fileno = 0;
pub const stdout_fileno = 1;
pub const stderr_fileno = 2;

pub var stdin = InStream {
    .fd = stdin_fileno,
    .offset = 0,
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
pub error Invalid;

/// When an Unexpected error occurs, code that emitted the error likely needs
/// a patch to recognize the unexpected case so that it can handle it and emit
/// a more specific error.
pub error Unexpected;

pub error DiskQuota;
pub error FileTooBig;
// TODO hide interrupts at this layer by retrying. Users can use the linux specific APIs if they
// want to handle interrupts.
pub error SigInterrupt;
pub error Io;
pub error NoSpaceLeft;
pub error BadPerm;
pub error PipeFail;
pub error BadFd;
pub error IsDir;
pub error NotDir;
pub error SymLinkLoop;
pub error ProcessFdQuotaExceeded;
pub error SystemFdQuotaExceeded;
pub error NameTooLong;
pub error NoDevice;
pub error PathNotFound;
pub error NoMem;
pub error Unseekable;
pub error Eof;

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

    pub fn writeByte(os: &OutStream, b: u8) -> %void {
        if (os.buffer.len == os.index) %return os.flush();
        os.buffer[os.index] = b;
        os.index += 1;
    }

    pub fn write(os: &OutStream, bytes: []const u8) -> %usize {
        var src_bytes_left = bytes.len;
        var src_index: @typeOf(bytes.len) = 0;
        const dest_space_left = os.buffer.len - os.index;

        while (src_bytes_left > 0) {
            const copy_amt = math.min(usize, dest_space_left, src_bytes_left);
            @memcpy(&os.buffer[os.index], &bytes[src_index], copy_amt);
            os.index += copy_amt;
            if (os.index == os.buffer.len) {
                %return os.flush();
            }
            src_bytes_left -= copy_amt;
        }
        return bytes.len;
    }

    /// Prints a byte buffer, flushes the buffer, then returns the number of
    /// bytes printed. The "f" is for "flush".
    pub fn printf(os: &OutStream, str: []const u8) -> %usize {
        const byte_count = %return os.write(str);
        %return os.flush();
        return byte_count;
    }

    pub fn printInt(os: &OutStream, inline T: type, x: T) -> %usize {
        // TODO replace max_u64_base10_digits with math.log10(math.pow(2, @sizeOf(T)))
        if (os.index + max_u64_base10_digits >= os.buffer.len) {
            %return os.flush();
        }
        const amt_printed = bufPrintInt(T, os.buffer[os.index...], x);
        os.index += amt_printed;
        return amt_printed;
    }

    pub fn flush(os: &OutStream) -> %void {
        const write_ret = linux.write(os.fd, &os.buffer[0], os.index);
        const write_err = linux.getErrno(write_ret);
        if (write_err > 0) {
            return switch (write_err) {
                errno.EINVAL => unreachable{},
                errno.EDQUOT => error.DiskQuota,
                errno.EFBIG  => error.FileTooBig,
                errno.EINTR  => error.SigInterrupt,
                errno.EIO    => error.Io,
                errno.ENOSPC => error.NoSpaceLeft,
                errno.EPERM  => error.BadPerm,
                errno.EPIPE  => error.PipeFail,
                else         => error.Unexpected,
            }
        }
        os.index = 0;
    }

    pub fn close(os: &OutStream) -> %void {
        const close_ret = linux.close(os.fd);
        const close_err = linux.getErrno(close_ret);
        if (close_err > 0) {
            return switch (close_err) {
                errno.EIO   => error.Io,
                errno.EBADF => error.BadFd,
                errno.EINTR => error.SigInterrupt,
                else        => error.Unexpected,
            }
        }
    }
}

// TODO created a BufferedInStream struct and move some of this code there
// BufferedInStream API goes on top of minimal InStream API.
pub struct InStream {
    fd: i32,
    offset: usize,

    /// Call close to clean up.
    pub fn open(is: &InStream, path: []const u8) -> %void {
        const result = linux.open(path, linux.O_LARGEFILE|linux.O_RDONLY, 0);
        const err = linux.getErrno(result);
        if (err > 0) {
            return switch (err) {
                errno.EFAULT => unreachable{},
                errno.EINVAL => unreachable{},
                errno.EACCES => error.BadPerm,
                errno.EFBIG, errno.EOVERFLOW => error.FileTooBig,
                errno.EINTR => error.SigInterrupt,
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
        is.offset = 0;
    }

    pub fn close(is: &InStream) -> %void {
        const close_ret = linux.close(is.fd);
        const close_err = linux.getErrno(close_ret);
        if (close_err > 0) {
            return switch (close_err) {
                errno.EIO => error.Io,
                errno.EBADF => error.BadFd,
                errno.EINTR => error.SigInterrupt,
                else => error.Unexpected,
            }
        }
    }

    /// Returns the number of bytes read. If the number read is smaller than buf.len, then
    /// the stream reached End Of File.
    pub fn read(is: &InStream, buf: []u8) -> %usize {
        switch (@compileVar("os")) {
            linux => {
                while (true) {
                    const amt_read = linux.pread(is.fd, buf.ptr, buf.len, is.offset);
                    const read_err = linux.getErrno(amt_read);
                    if (read_err > 0) {
                        switch (read_err) {
                            errno.EINTR  => continue,
                            errno.EINVAL => unreachable{},
                            errno.EFAULT => unreachable{},
                            errno.EBADF  => return error.BadFd,
                            errno.EIO    => return error.Io,
                            else         => return error.Unexpected,
                        }
                    }
                    is.offset += amt_read;
                    return amt_read;
                }
            },
            else => @compileErr("unsupported OS"),
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

    pub inline fn readIntLe(is: &InStream, inline T: type) -> %T {
        is.readInt(false, T)
    }

    pub inline fn readIntBe(is: &InStream, inline T: type) -> %T {
        is.readInt(true, T)
    }

    pub inline fn readInt(is: &InStream, is_be: bool, inline T: type) -> %T {
        var result: T = undefined;
        const result_slice = ([]u8)((&result)[0...1]);
        %return is.readNoEof(result_slice);
        return endian.swapIf(!is_be, T, result);
    }

    pub inline fn readVarInt(is: &InStream, is_be: bool, inline T: type, size: usize) -> %T {
        var result: T = zeroes;
        const result_slice = ([]u8)((&result)[0...1]);
        const padding = @sizeOf(T) - size;
        {var i: usize = 0; while (i < size; i += 1) {
            const index = if (is_be == @compileVar("is_big_endian")) {
                padding + i
            } else {
                result_slice.len - i - 1 - padding
            };
            result_slice[index] = %return is.readByte();
        }}
        return result;
    }

    pub fn seekForward(is: &InStream, amount: usize) -> %void {
        is.offset += amount;
    }

    pub fn seekTo(is: &InStream, pos: usize) -> %void {
        is.offset = pos;
    }

    pub fn endPos(is: &InStream) -> %usize {
        var stat: linux.stat = undefined;
        const err = linux.getErrno(linux.fstat(is.fd, &stat));
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

pub error InvalidChar;
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

#attribute("test")
fn parseU64DigitTooBig() {
    parseUnsigned(u64, "123a", 10) %% |err| {
        if (err == error.InvalidChar) return;
        unreachable{};
    };
    unreachable{};
}

pub fn openSelfExe(stream: &InStream) -> %void {
    switch (@compileVar("os")) {
        linux => {
            %return stream.open("/proc/self/exe");
        },
        else => @compileErr("unsupported os"),
    }
}
