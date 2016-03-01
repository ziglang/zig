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

const buffer_size = 4 * 1024;
const max_u64_base10_digits = 20;
const max_f64_digits = 65;

pub struct OutStream {
    fd: isize,
    buffer: [buffer_size]u8,
    index: isize,

    pub fn print_str(os: &OutStream, str: []const u8) -> %isize {
        var src_bytes_left = str.len;
        var src_index: @typeof(str.len) = 0;
        const dest_space_left = os.buffer.len - os.index;

        while (src_bytes_left > 0) {
            const copy_amt = math.min_isize(dest_space_left, src_bytes_left);
            @memcpy(&os.buffer[os.index], &str[src_index], copy_amt);
            os.index += copy_amt;
            if (os.index == os.buffer.len) {
                %return os.flush();
            }
            src_bytes_left -= copy_amt;
        }
        return str.len;
    }

    /// Prints a byte buffer, flushes the buffer, then returns the number of
    /// bytes printed. The "f" is for "flush".
    pub fn printf(os: &OutStream, str: []const u8) -> %isize {
        const byte_count = %return os.print_str(str);
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
        const amt_written = linux.write(os.fd, &os.buffer[0], os.index);
        os.index = 0;
        if (amt_written < 0) {
            return switch (-amt_written) {
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

#attribute("cold")
pub fn abort() -> unreachable {
    linux.raise(linux.SIGABRT);
    linux.raise(linux.SIGKILL);
    while (true) {}
}

pub error InvalidChar;
pub error Overflow;

pub fn parse_u64(buf: []u8, radix: u8) -> %u64 {
    var x : u64 = 0;

    for (buf) |c| {
        const digit = char_to_digit(c);

        if (digit >= radix) {
            return error.InvalidChar;
        }

        // x *= radix
        if (@mul_with_overflow(u64, x, radix, &x)) {
            return error.Overflow;
        }

        // x += digit
        if (@add_with_overflow(u64, x, digit, &x)) {
            return error.Overflow;
        }
    }

    return x;
}

fn char_to_digit(c: u8) -> u8 {
    // TODO use switch with range
    if ('0' <= c && c <= '9') {
        c - '0'
    } else if ('A' <= c && c <= 'Z') {
        c - 'A' + 10
    } else if ('a' <= c && c <= 'z') {
        c - 'a' + 10
    } else {
        @max_value(u8)
    }
}

pub fn buf_print_i64(out_buf: []u8, x: i64) -> isize {
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + buf_print_u64(out_buf[1...], u64(-(x + 1)) + 1);
    } else {
        return buf_print_u64(out_buf, u64(x));
    }
}

pub fn buf_print_u64(out_buf: []u8, x: u64) -> isize {
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
    parse_u64("123a", 10) %% |err| {
        if (err == error.InvalidChar) return;
        unreachable{};
    };
    unreachable{};
}
