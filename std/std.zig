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

/*
// TODO error handling
pub fn readline(buf: []u8) -> ?[]u8 {
    var index = 0;
    while (index < buf.len) {
        // TODO unknown size array indexing operator
        const err = read(stdin_fileno, &buf.ptr[index], 1);
        if (err != 0) {
            return null;
        }
        // TODO unknown size array indexing operator
        if (buf.ptr[index] == '\n') {
            return buf[0...index + 1];
        }
        index += 1;
    }
    return null;
}
*/

fn digit_to_char(digit: u64) -> u8 {
    '0' + (digit as u8)
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
        buf[index] = digit_to_char(digit);
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
