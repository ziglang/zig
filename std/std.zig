use "syscall.zig";

const stdin_fileno : isize = 0;
const stdout_fileno : isize = 1;
const stderr_fileno : isize = 2;

// TODO error handling
pub fn os_get_random_bytes(buf: &u8, count: usize) -> isize {
    getrandom(buf, count, 0)
}

// TODO error handling
// TODO handle buffering and flushing (mutex protected)
pub fn print_str(str: []const u8) -> isize {
    fprint_str(stdout_fileno, str)
}

// TODO error handling
// TODO handle buffering and flushing (mutex protected)
pub fn fprint_str(fd: isize, str: []const u8) -> isize {
    write(fd, str.ptr, str.len)
}

// TODO handle buffering and flushing (mutex protected)
// TODO error handling
pub fn print_u64(x: u64) -> isize {
    // TODO use max_u64_base10_digits instead of hardcoding 20
    var buf: [20]u8;
    const len = buf_print_u64(buf.ptr, x);
    return write(stdout_fileno, buf.ptr, len);
}

// TODO handle buffering and flushing (mutex protected)
// TODO error handling
pub fn print_i64(x: i64) -> isize {
    // TODO use max_u64_base10_digits instead of hardcoding 20
    var buf: [20]u8;
    const len = buf_print_i64(buf.ptr, x);
    return write(stdout_fileno, buf.ptr, len);
}

// TODO error handling
pub fn readline(buf: []u8, out_len: &usize) -> bool {
    // TODO unknown size array indexing operator
    const amt_read = read(stdin_fileno, buf.ptr, buf.len);
    if (amt_read < 0) {
        return true;
    }
    *out_len = amt_read as usize;
    return false;
}

// TODO return ?u64 when we support returning struct byval
pub fn parse_u64(buf: []u8, radix: u8, result: &u64) -> bool {
    var x : u64 = 0;

    var i : #typeof(buf.len) = 0;
    while (i < buf.len) {
        // TODO array indexing operator
        const c = buf.ptr[i];
        const digit = char_to_digit(c);

        if (digit > radix) {
            return true;
        }

        x *= radix;
        x += digit;

        /* TODO intrinsics mul and add with overflow
        // x *= radix
        if (@mul_with_overflow_u64(x, radix, &x)) {
            return true;
        }

        // x += digit
        if (@add_with_overflow_u64(x, digit, &x)) {
            return true;
        }
        */

        i += 1;
    }

    *result = x;
    return false;
}

fn char_to_digit(c: u8) -> u8 {
    if ('0' <= c && c <= '9') {
        c - '0'
    } else if ('A' <= c && c <= 'Z') {
        c - 'A' + 10
    } else if ('a' <= c && c <= 'z') {
        c - 'a' + 10
    } else {
        #max_value(u8)
    }
}

const max_u64_base10_digits: usize = 20;

// TODO use an array for out_buf instead of pointer. this should give bounds checking in
// debug mode and length can get optimized out in release mode. requires array slicing syntax
// for the buf_print_u64 call.
fn buf_print_i64(out_buf: &u8, x: i64) -> usize {
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + buf_print_u64(&out_buf[1], ((-(x + 1)) as u64) + 1);
    } else {
        return buf_print_u64(out_buf, x as u64);
    }
}

// TODO use an array for out_buf instead of pointer.
fn buf_print_u64(out_buf: &u8, x: u64) -> usize {
    var buf: [max_u64_base10_digits]u8;
    var a = x;
    var index = buf.len;

    while (true) {
        const digit = a % 10;
        index -= 1;
        buf[index] = '0' + (digit as u8);
        a /= 10;
        if (a == 0)
            break;
    }

    const len = buf.len - index;

    // TODO memcpy intrinsic
    var i: usize = 0;
    while (i < len) {
        out_buf[i] = buf[index + i];
        i += 1;
    }

    return len;
}
