import "syscall.zig";
import "errno.zig";

pub const stdin_fileno = 0;
pub const stdout_fileno = 1;
pub const stderr_fileno = 2;

/*
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

pub %.Unexpected;
pub %.DiskQuota;
pub %.FileTooBig;
pub %.SigInterrupt;
pub %.Io;
pub %.NoSpaceLeft;
pub %.BadPerm;
pub %.PipeFail;
*/

const buffer_size = 4 * 1024;
const max_u64_base10_digits = 20;

/*
pub struct OutStream {
    fd: isize,
    buffer: [buffer_size]u8,
    index: @typeof(buffer_size),
    buffered: bool,

    pub fn print_str(os: &OutStream, str: []const u8) %isize => {
        var src_bytes_left = str.len;
        var src_index: @typeof(str.len) = 0;
        const dest_space_left = os.buffer.len - index;

        while (src_bytes_left > 0) {
            const copy_amt = min_isize(dest_space_left, src_bytes_left);
            @memcpy(&buffer[os.index], &str[src_index], copy_amt);
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

    pub fn print_u64(os: &OutStream, x: u64) %isize => {
        if (os.index + max_u64_base10_digits >= os.buffer.len) {
            %return os.flush();
        }
        const amt_printed = buf_print_u64(buf[os.index...], x);
        os.index += amt_printed;

        if (!os.buffered) {
            %return os.flush();
        }

        return amt_printed;
    }


    pub fn print_i64(os: &OutStream, x: i64) %isize => {
        if (os.index + max_u64_base10_digits >= os.buffer.len) {
            %return os.flush();
        }
        const amt_printed = buf_print_i64(buf[os.index...], x);
        os.index += amt_printed;

        if (!os.buffered) {
            %return os.flush();
        }

        return amt_printed;
    }


    pub fn flush(os: &OutStream) %void => {
        const amt_to_write = os.index;
        os.index = 0;
        switch (write(os.fd, os.buffer.ptr, amt_to_write)) {
            EINVAL => unreachable{},
            EDQUOT => %.DiskQuota,
            EFBIG  => %.FileTooBig,
            EINTR  => %.SigInterrupt,
            EIO    => %.Io,
            ENOSPC => %.NoSpaceLeft,
            EPERM  => %.BadPerm,
            EPIPE  => %.PipeFail,
            else   => %.Unexpected,
        }
    }
}

pub struct InStream {
    fd: isize,

    pub fn readline(buf: []u8) %isize => {
        const amt_read = read(stdin_fileno, buf.ptr, buf.len);
        if (amt_read < 0) {
            switch (-amt_read) {
                EINVAL => unreachable{},
                EFAULT => unreachable{},
                EBADF  => %.BadFd,
                EINTR  => %.SigInterrupt,
                EIO    => %.Io,
                else   => %.Unexpected,
            }
        }
        return amt_read;
    }

}

pub fn os_get_random_bytes(buf: []u8) %void => {
    switch (getrandom(buf.ptr, buf.len, 0)) {
        EINVAL => unreachable{},
        EFAULT => unreachable{},
        EINTR  => %.SigInterrupt,
        else   => %.Unexpected,
    }
}
*/


// TODO remove this
pub fn print_str(str: []const u8) isize => {
    fprint_str(stdout_fileno, str)
}

// TODO remove this
pub fn fprint_str(fd: isize, str: []const u8) isize => {
    write(fd, str.ptr, str.len)
}

// TODO remove this
pub fn os_get_random_bytes(buf: []u8) isize => {
    getrandom(buf.ptr, buf.len, 0)
}

// TODO remove this
pub fn print_u64(x: u64) isize => {
    var buf: [max_u64_base10_digits]u8;
    const len = buf_print_u64(buf, x);
    return write(stdout_fileno, buf.ptr, len);
}

// TODO remove this
pub fn print_i64(x: i64) isize => {
    var buf: [max_u64_base10_digits]u8;
    const len = buf_print_i64(buf, x);
    return write(stdout_fileno, buf.ptr, len);
}

// TODO remove this
pub fn readline(buf: []u8, out_len: &isize) bool => {
    const amt_read = read(stdin_fileno, buf.ptr, buf.len);
    if (amt_read < 0) {
        return true;
    }
    *out_len = isize(amt_read);
    return false;
}


// TODO return %u64 when we support errors
pub fn parse_u64(buf: []u8, radix: u8, result: &u64) bool => {
    var x : u64 = 0;

    for (c, buf) {
        const digit = char_to_digit(c);

        if (digit > radix) {
            return true;
        }

        // x *= radix
        if (@mul_with_overflow(u64, x, radix, &x)) {
            return true;
        }

        // x += digit
        if (@add_with_overflow(u64, x, digit, &x)) {
            return true;
        }
    }

    *result = x;
    return false;
}

fn char_to_digit(c: u8) u8 => {
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

fn buf_print_i64(out_buf: []u8, x: i64) isize => {
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + buf_print_u64(out_buf[1...], u64(-(x + 1)) + 1);
    } else {
        return buf_print_u64(out_buf, u64(x));
    }
}

fn buf_print_u64(out_buf: []u8, x: u64) isize => {
    var buf: [max_u64_base10_digits]u8;
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
