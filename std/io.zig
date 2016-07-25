const linux = @import("linux.zig");
const errno = @import("errno.zig");
const math = @import("math.zig");

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
pub error Invalid;

/// When an Unexpected error occurs, code that emitted the error likely needs
/// a patch to recognize the unexpected case so that it can handle it and emit
/// a more specific error.
pub error Unexpected;

pub error DiskQuota;
pub error FileTooBig;
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

const buffer_size = 4 * 1024;
const max_u64_base10_digits = 20;
const max_f64_digits = 65;

pub const OpenRead     = 0b0001;
pub const OpenWrite    = 0b0010;
pub const OpenCreate   = 0b0100;
pub const OpenTruncate = 0b1000;

pub struct OutStream {
    fd: isize,
    buffer: [buffer_size]u8,
    index: isize,

    pub fn write(os: &OutStream, bytes: []const u8) -> %isize {
        var src_bytes_left = bytes.len;
        var src_index: @typeof(bytes.len) = 0;
        const dest_space_left = os.buffer.len - os.index;

        while (src_bytes_left > 0) {
            const copy_amt = math.min(isize, dest_space_left, src_bytes_left);
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
    pub fn printf(os: &OutStream, str: []const u8) -> %isize {
        const byte_count = %return os.write(str);
        %return os.flush();
        return byte_count;
    }

    pub fn print_u64(os: &OutStream, x: u64) -> %isize {
        if (os.index + max_u64_base10_digits >= os.buffer.len) {
            %return os.flush();
        }
        const amt_printed = buf_print_u64(os.buffer[os.index...], x);
        os.index += amt_printed;

        return amt_printed;
    }

    pub fn print_i64(os: &OutStream, x: i64) -> %isize {
        if (os.index + max_u64_base10_digits >= os.buffer.len) {
            %return os.flush();
        }
        const amt_printed = buf_print_i64(os.buffer[os.index...], x);
        os.index += amt_printed;

        return amt_printed;
    }

    pub fn print_f64(os: &OutStream, x: f64) -> %isize {
        if (os.index + max_f64_digits >= os.buffer.len) {
            %return os.flush();
        }
        const amt_printed = buf_print_f64(os.buffer[os.index...], x, 4);
        os.index += amt_printed;

        return amt_printed;
    }

    pub fn flush(os: &OutStream) -> %void {
        const write_ret = linux.write(os.fd, &os.buffer[0], os.index);
        const write_err = linux.get_errno(write_ret);
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
        const closed = linux.close(os.fd);
        if (closed < 0) {
            return switch (-closed) {
                errno.EIO => error.Io,
                errno.EBADF => error.BadFd,
                errno.EINTR => error.SigInterrupt,
                else => error.Unexpected,
            }
        }
    }
}

pub struct InStream {
    fd: isize,

    pub fn open(path: []u8) -> %InStream {
        const fd = linux.open(path, linux.O_LARGEFILE|linux.O_RDONLY, 0);
        if (fd < 0) {
            return switch (-fd) {
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

        return InStream { .fd = fd, };
    }

    pub fn read(is: &InStream, buf: []u8) -> %isize {
        const amt_read = linux.read(is.fd, &buf[0], buf.len);
        if (amt_read < 0) {
            return switch (-amt_read) {
                errno.EINVAL => unreachable{},
                errno.EFAULT => unreachable{},
                errno.EBADF  => error.BadFd,
                errno.EINTR  => error.SigInterrupt,
                errno.EIO    => error.Io,
                else         => error.Unexpected,
            }
        }
        return amt_read;
    }

    pub fn close(is: &InStream) -> %void {
        const closed = linux.close(is.fd);
        if (closed < 0) {
            return switch (-closed) {
                errno.EIO => error.Io,
                errno.EBADF => error.BadFd,
                errno.EINTR => error.SigInterrupt,
                else => error.Unexpected,
            }
        }
    }
}

pub fn parse_unsigned(inline T: type, buf: []u8, radix: u8) -> %T {
    var x: T = 0;

    for (buf) |c| {
        const digit = %return char_to_digit(c, radix);
        x = %return math.mul_overflow(T, x, radix);
        x = %return math.add_overflow(T, x, digit);
    }

    return x;
}

pub error InvalidChar;
fn char_to_digit(c: u8, radix: u8) -> %u8 {
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

pub fn buf_print_signed(inline T: type, out_buf: []u8, x: T) -> isize {
    const uint = @int_type(false, T.bit_count, false);
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + buf_print_unsigned(uint, out_buf[1...], uint(-(x + 1)) + 1);
    } else {
        return buf_print_unsigned(uint, out_buf, uint(x));
    }
}

pub fn buf_print_i64(out_buf: []u8, x: i64) -> isize {
    buf_print_signed(i64, out_buf, x)
}

pub fn buf_print_unsigned(inline T: type, out_buf: []u8, x: T) -> isize {
    var buf: [max_u64_base10_digits]u8 = undefined;
    var a = x;
    var index: isize = buf.len;

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

pub fn buf_print_u64(out_buf: []u8, x: u64) -> isize {
    buf_print_unsigned(u64, out_buf, x)
}

pub fn buf_print_f64(out_buf: []u8, x: f64, decimals: isize) -> isize {
    const numExpBits = 11;
    const numRawSigBits = 52; // not including implicit 1 bit
    const expBias = 1023;

    var decs = decimals;
    if (decs >= max_u64_base10_digits) {
        decs = max_u64_base10_digits - 1;
    }

    if (x == math.f64_get_pos_inf()) {
        const buf2 = "+Inf";
        @memcpy(&out_buf[0], &buf2[0], buf2.len);
        return 4;
    } else if (x == math.f64_get_neg_inf()) {
        const buf2 = "-Inf";
        @memcpy(&out_buf[0], &buf2[0], buf2.len);
        return 4;
    } else if (math.f64_is_nan(x)) {
        const buf2 = "NaN";
        @memcpy(&out_buf[0], &buf2[0], buf2.len);
        return 3;
    }

    var buf: [max_f64_digits]u8 = undefined;

    var len: isize = 0;

    // 1 sign bit
    // 11 exponent bits
    // 52 significand bits (+ 1 implicit always non-zero bit)

    const bits = math.f64_to_bits(x);
    if (bits & (1 << 63) != 0) {
        buf[0] = '-';
        len += 1;
    }

    const rexponent: i64 = i64((bits >> numRawSigBits) & ((1 << numExpBits) - 1));
    const exponent = rexponent - expBias - numRawSigBits;

    if (rexponent == 0) {
        buf[len] = '0';
        len += 1;
        @memcpy(&out_buf[0], &buf[0], len);
        return len;
    }

    const sig = (bits & ((1 << numRawSigBits) - 1)) | (1 << numRawSigBits);

    if (exponent >= 0) {
        // number is an integer

        if (exponent >= 64 - 53) {
            // use XeX form

            // TODO support printing large floats
            //len += buf_print_u64(buf[len...], sig << 10);
            const str = "LARGEF64";
            @memcpy(&buf[len], &str[0], str.len);
            len += str.len;
        } else {
            // use typical form

            len += buf_print_u64(buf[len...], sig << u64(exponent));
            buf[len] = '.';
            len += 1;

            var i: isize = 0;
            while (i < decs) {
                buf[len] = '0';
                len += 1;
                i += 1;
            }
        }
    } else {
        // number is not an integer

        // print out whole part
        len += buf_print_u64(buf[len...], sig >> u64(-exponent));
        buf[len] = '.';
        len += 1;

        // print out fractional part
        // dec_num holds: fractional part * 10 ^ decs
        var dec_num: u64 = 0;

        var a: isize = 1;
        var i: isize = 0;
        while (i < decs + 5) {
            a *= 10;
            i += 1;
        }

        // create a mask: 1's for the fractional part, 0's for whole part
        var masked_sig = sig & ((1 << u64(-exponent)) - 1);
        i = -1;
        while (i >= exponent) {
            var bit_set = ((1 << u64(i-exponent)) & masked_sig) != 0;

            if (bit_set) {
                dec_num += usize(a) >> usize(-i);
            }

            i -= 1;
        }

        dec_num /= 100000;

        len += decs;

        i = len - 1;
        while (i >= len - decs) {
            buf[i] = '0' + u8(dec_num % 10);
            dec_num /= 10;
            i -= 1;
        }
    }

    @memcpy(&out_buf[0], &buf[0], len);

    len
}

#attribute("test")
fn parse_u64_digit_too_big() {
    parse_unsigned(u64, "123a", 10) %% |err| {
        if (err == error.InvalidChar) return;
        unreachable{};
    };
    unreachable{};
}
