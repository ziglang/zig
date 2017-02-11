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
const max_f64_digits = 65;
const max_int_digits = 65;

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
        var src_bytes_left = bytes.len;
        var src_index: usize = 0;
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
    }

    const State = enum { // TODO put inside printf function and make sure the name and debug info is correct
        Start,
        OpenBrace,
        CloseBrace,
        Integer,
        IntegerWidth,
    };

    /// Calls print and then flushes the buffer.
    pub fn printf(self: &OutStream, comptime format: []const u8, args: ...) -> %void {
        comptime var start_index = 0;
        comptime var state = State.Start;
        comptime var next_arg = 0;
        comptime var radix = 0;
        comptime var uppercase = false;
        comptime var width = 0;
        comptime var width_start = 0;

        inline for (format) |c, i| {
            switch (state) {
                State.Start => switch (c) {
                    '{' => {
                        if (start_index < i) %return self.write(format[start_index...i]);
                        state = State.OpenBrace;
                    },
                    '}' => {
                        if (start_index < i) %return self.write(format[start_index...i]);
                        state = State.CloseBrace;
                    },
                    else => {},
                },
                State.OpenBrace => switch (c) {
                    '{' => {
                        state = State.Start;
                        start_index = i;
                    },
                    '}' => {
                        %return self.printValue(args[next_arg]);
                        next_arg += 1;
                        state = State.Start;
                        start_index = i + 1;
                    },
                    'd' => {
                        radix = 10;
                        uppercase = false;
                        width = 0;
                        state = State.Integer;
                    },
                    'x' => {
                        radix = 16;
                        uppercase = false;
                        width = 0;
                        state = State.Integer;
                    },
                    'X' => {
                        radix = 16;
                        uppercase = true;
                        width = 0;
                        state = State.Integer;
                    },
                    else => @compileError("Unknown format character: " ++ []u8{c}),
                },
                State.CloseBrace => switch (c) {
                    '}' => {
                        state = State.Start;
                        start_index = i;
                    },
                    else => @compileError("Single '}' encountered in format string"),
                },
                State.Integer => switch (c) {
                    '}' => {
                        self.printInt(args[next_arg], radix, uppercase, width);
                        next_arg += 1;
                        state = State.Start;
                        start_index = i + 1;
                    },
                    '0' ... '9' => {
                        width_start = i;
                        state = State.IntegerWidth;
                    },
                    else => @compileError("Unexpected character in format string: " ++ []u8{c}),
                },
                State.IntegerWidth => switch (c) {
                    '}' => {
                        width = comptime %%parseUnsigned(usize, format[width_start...i], 10);
                        self.printInt(args[next_arg], radix, uppercase, width);
                        next_arg += 1;
                        state = State.Start;
                        start_index = i + 1;
                    },
                    '0' ... '9' => {},
                    else => @compileError("Unexpected character in format string: " ++ []u8{c}),
                },
            }
        }
        comptime {
            if (args.len != next_arg) {
                @compileError("Unused arguments");
            }
            if (state != State.Start) {
                @compileError("Incomplete format string: " ++ format);
            }
        }
        if (start_index < format.len) {
            %return self.write(format[start_index...format.len]);
        }
        %return self.flush();
    }

    pub fn printValue(self: &OutStream, value: var) -> %void {
        const T = @typeOf(value);
        if (@isInteger(T)) {
            return self.printInt(value, 10, false, 0);
        } else if (@isFloat(T)) {
            return self.printFloat(T, value);
        } else if (@canImplicitCast([]const u8, value)) {
            const casted_value = ([]const u8)(value);
            return self.write(casted_value);
        } else if (T == void) {
            return self.write("void");
        } else {
            @compileError("Unable to print type '" ++ @typeName(T) ++ "'");
        }
    }

    pub fn printInt(self: &OutStream, x: var, base: u8, uppercase: bool, width: usize) -> %void {
        if (self.index + max_int_digits >= self.buffer.len) {
            %return self.flush();
        }
        const amt_printed = bufPrintInt(self.buffer[self.index...], x, base, uppercase, width);
        self.index += amt_printed;
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

    pub fn close(self: &OutStream) {
        while (true) {
            const close_ret = system.close(self.fd);
            const close_err = system.getErrno(close_ret);
            if (close_err > 0 && close_err == errno.EINTR)
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

    pub fn readIntLe(is: &InStream, comptime T: type) -> %T {
        is.readInt(false, T)
    }

    pub fn readIntBe(is: &InStream, comptime T: type) -> %T {
        is.readInt(true, T)
    }

    pub fn readInt(is: &InStream, is_be: bool, comptime T: type) -> %T {
        var result: T = undefined;
        const result_slice = ([]u8)((&result)[0...1]);
        %return is.readNoEof(result_slice);
        return endian.swapIf(!is_be, T, result);
    }

    pub fn readVarInt(is: &InStream, is_be: bool, comptime T: type, size: usize) -> %T {
        assert(size <= @sizeOf(T));
        assert(size <= 8);
        var input_buf: [8]u8 = undefined;
        const input_slice = input_buf[0...size];
        %return is.readNoEof(input_slice);
        return mem.sliceAsInt(input_slice, is_be, T);
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
};

pub fn parseUnsigned(comptime T: type, buf: []const u8, radix: u8) -> %T {
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
    const value = switch (c) {
        '0' ... '9' => c - '0',
        'A' ... 'Z' => c - 'A' + 10,
        'a' ... 'z' => c - 'a' + 10,
        else => return error.InvalidChar,
    };

    if (value >= radix)
        return error.InvalidChar;

    return value;
}

fn digitToChar(digit: u8, uppercase: bool) -> u8 {
    return switch (digit) {
        0 ... 9 => digit + '0',
        10 ... 35 => digit + ((if (uppercase) u8('A') else u8('a')) - 10),
        else => @unreachable(),
    };
}

/// Guaranteed to not use more than max_int_digits
pub fn bufPrintInt(out_buf: []u8, x: var, base: u8, uppercase: bool, width: usize) -> usize {
    if (@typeOf(x).is_signed)
        bufPrintSigned(out_buf, x, base, uppercase, width)
    else
        bufPrintUnsigned(out_buf, x, base, uppercase, width)
}

fn bufPrintSigned(out_buf: []u8, x: var, base: u8, uppercase: bool, width: usize) -> usize {
    const uint = @intType(false, @typeOf(x).bit_count);
    // include the sign in the width
    const new_width = if (width == 0) 0 else (width - 1);
    var new_value: uint = undefined;
    if (x < 0) {
        out_buf[0] = '-';
        new_value = uint(-(x + 1)) + 1;
    } else {
        out_buf[0] = '+';
        new_value = uint(x);
    }
    return 1 + bufPrintUnsigned(out_buf[1...], new_value, base, uppercase, new_width);
}

fn bufPrintUnsigned(out_buf: []u8, x: var, base: u8, uppercase: bool, width: usize) -> usize {
    // max_int_digits accounts for the minus sign. when printing an unsigned
    // number we don't need to do that.
    var buf: [max_int_digits - 1]u8 = undefined;
    var a = x;
    var index: usize = buf.len;

    while (true) {
        const digit = a % base;
        index -= 1;
        buf[index] = digitToChar(u8(digit), uppercase);
        a /= base;
        if (a == 0)
            break;
    }

    const src_buf = buf[index...];
    const padding = if (width > src_buf.len) (width - src_buf.len) else 0;

    mem.set(u8, out_buf[0...padding], '0');
    mem.copy(u8, out_buf[padding...], src_buf);
    return src_buf.len + padding;
}

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

fn bufPrintIntToSlice(buf: []u8, value: var, base: u8, uppercase: bool, width: usize) -> []u8 {
    return buf[0...bufPrintInt(buf, value, base, uppercase, width)];
}

fn testParseU64DigitTooBig() {
    @setFnTest(this);

    parseUnsigned(u64, "123a", 10) %% |err| {
        if (err == error.InvalidChar) return;
        @unreachable();
    };
    @unreachable();
}

fn testParseUnsignedComptime() {
    @setFnTest(this);

    comptime {
        assert(%%parseUnsigned(usize, "2", 10) == 2);
    }
}

fn testBufPrintInt() {
    @setFnTest(this);

    var buf: [max_int_digits]u8 = undefined;
    assert(mem.eql(bufPrintIntToSlice(buf, i32(-12345678), 2, false, 0), "-101111000110000101001110"));
    assert(mem.eql(bufPrintIntToSlice(buf, i32(-12345678), 10, false, 0), "-12345678"));
    assert(mem.eql(bufPrintIntToSlice(buf, i32(-12345678), 16, false, 0), "-bc614e"));
    assert(mem.eql(bufPrintIntToSlice(buf, i32(-12345678), 16, true, 0), "-BC614E"));

    assert(mem.eql(bufPrintIntToSlice(buf, u32(12345678), 10, true, 0), "12345678"));

    assert(mem.eql(bufPrintIntToSlice(buf, u32(666), 10, false, 6), "000666"));
    assert(mem.eql(bufPrintIntToSlice(buf, u32(0x1234), 16, false, 6), "001234"));
    assert(mem.eql(bufPrintIntToSlice(buf, u32(0x1234), 16, false, 1), "1234"));

    assert(mem.eql(bufPrintIntToSlice(buf, i32(42), 10, false, 3), "+42"));
    assert(mem.eql(bufPrintIntToSlice(buf, i32(-42), 10, false, 3), "-42"));
}
