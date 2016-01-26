import "syscall.zig";
import "errno.zig";

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
    .buffered = true,
};

pub var stderr = OutStream {
    .fd = stderr_fileno,
    .buffer = undefined,
    .index = 0,
    .buffered = false,
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

pub struct OutStream {
    fd: isize,
    buffer: [buffer_size]u8,
    index: isize,
    buffered: bool,

    pub fn print_str(os: &OutStream, str: []const u8) -> %isize {
        var src_bytes_left = str.len;
        var src_index: @typeof(str.len) = 0;
        const dest_space_left = os.buffer.len - os.index;

        while (src_bytes_left > 0) {
            const copy_amt = min_isize(dest_space_left, src_bytes_left);
            @memcpy(&os.buffer[os.index], &str[src_index], copy_amt);
            os.index += copy_amt;
            if (os.index == os.buffer.len) {
                %return os.flush();
            }
            src_bytes_left -= copy_amt;
        }
        if (!os.buffered) {
            %return os.flush();
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

        if (!os.buffered) {
            %return os.flush();
        }

        return amt_printed;
    }


    pub fn print_i64(os: &OutStream, x: i64) -> %isize {
        if (os.index + max_u64_base10_digits >= os.buffer.len) {
            %return os.flush();
        }
        const amt_printed = buf_print_i64(os.buffer[os.index...], x);
        os.index += amt_printed;

        if (!os.buffered) {
            %return os.flush();
        }

        return amt_printed;
    }


    pub fn flush(os: &OutStream) -> %void {
        const amt_written = write(os.fd, os.buffer.ptr, os.index);
        os.index = 0;
        if (amt_written < 0) {
            return switch (-amt_written) {
                EINVAL => unreachable{},
                EDQUOT => error.DiskQuota,
                EFBIG  => error.FileTooBig,
                EINTR  => error.SigInterrupt,
                EIO    => error.Io,
                ENOSPC => error.NoSpaceLeft,
                EPERM  => error.BadPerm,
                EPIPE  => error.PipeFail,
                else   => error.Unexpected,
            }
        }
    }
}

pub struct InStream {
    fd: isize,

    pub fn read(is: &InStream, buf: []u8) -> %isize {
        const amt_read = read(is.fd, buf.ptr, buf.len);
        if (amt_read < 0) {
            return switch (-amt_read) {
                EINVAL => unreachable{},
                EFAULT => unreachable{},
                EBADF  => error.BadFd,
                EINTR  => error.SigInterrupt,
                EIO    => error.Io,
                else   => error.Unexpected,
            }
        }
        return amt_read;
    }
}

pub fn os_get_random_bytes(buf: []u8) -> %void {
    const amt_got = getrandom(buf.ptr, buf.len, 0);
    if (amt_got < 0) {
        return switch (-amt_got) {
            EINVAL => unreachable{},
            EFAULT => unreachable{},
            EINTR  => error.SigInterrupt,
            else   => error.Unexpected,
        }
    }
}


pub error InvalidChar;
pub error Overflow;

pub fn parse_u64(buf: []u8, radix: u8) -> %u64 {
    var x : u64 = 0;

    for (c, buf) {
        const digit = char_to_digit(c);

        if (digit > radix) {
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

fn buf_print_i64(out_buf: []u8, x: i64) -> isize {
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + buf_print_u64(out_buf[1...], u64(-(x + 1)) + 1);
    } else {
        return buf_print_u64(out_buf, u64(x));
    }
}

fn buf_print_u64(out_buf: []u8, x: u64) -> isize {
    var buf: [max_u64_base10_digits]u8 = undefined;
    var a = x;
    var index = buf.len;

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

fn min_isize(x: isize, y: isize) -> isize {
    if (x < y) x else y
}
