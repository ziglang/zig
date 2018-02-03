const std = @import("../index.zig");
const math = std.math;
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const builtin = @import("builtin");
const errol3 = @import("errol/index.zig").errol3;

const max_int_digits = 65;

const State = enum { // TODO put inside format function and make sure the name and debug info is correct
    Start,
    OpenBrace,
    CloseBrace,
    Integer,
    IntegerWidth,
    Float,
    FloatWidth,
    Character,
    Buf,
    BufWidth,
};

/// Renders fmt string with args, calling output with slices of bytes.
/// If `output` returns an error, the error is returned from `format` and
/// `output` is not called again.
pub fn format(context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8) Errors!void,
    comptime fmt: []const u8, args: ...) Errors!void
{
    comptime var start_index = 0;
    comptime var state = State.Start;
    comptime var next_arg = 0;
    comptime var radix = 0;
    comptime var uppercase = false;
    comptime var width = 0;
    comptime var width_start = 0;

    inline for (fmt) |c, i| {
        switch (state) {
            State.Start => switch (c) {
                '{' => {
                    if (start_index < i) {
                        try output(context, fmt[start_index..i]);
                    }
                    state = State.OpenBrace;
                },
                '}' => {
                    if (start_index < i) {
                        try output(context, fmt[start_index..i]);
                    }
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
                    try formatValue(args[next_arg], context, Errors, output);
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
                'c' => {
                    state = State.Character;
                },
                's' => {
                    state = State.Buf;
                },'.' => {
                    state = State.Float;
                },
                else => @compileError("Unknown format character: " ++ []u8{c}),
            },
            State.Buf => switch (c) {
                '}' => {
                    return output(context, args[next_arg]);
                },
                '0' ... '9' => {
                    width_start = i;
                    state = State.BufWidth;
                },
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
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
                    try formatInt(args[next_arg], radix, uppercase, width, context, Errors, output);
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
                    width = comptime (parseUnsigned(usize, fmt[width_start..i], 10) catch unreachable);
                    try formatInt(args[next_arg], radix, uppercase, width, context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {},
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
            },
            State.Float => switch (c) {
                '}' => {
                    try formatFloatDecimal(args[next_arg], 0, context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {
                    width_start = i;
                    state = State.FloatWidth;
                },
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
            },
            State.FloatWidth => switch (c) {
                '}' => {
                    width = comptime (parseUnsigned(usize, fmt[width_start..i], 10) catch unreachable);
                    try formatFloatDecimal(args[next_arg], width, context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {},
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
            },
            State.BufWidth => switch (c) {
                '}' => {
                    width = comptime (parseUnsigned(usize, fmt[width_start..i], 10) catch unreachable);
                    try formatBuf(args[next_arg], width, context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {},
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
            },
            State.Character => switch (c) {
                '}' => {
                    try formatAsciiChar(args[next_arg], context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
            },
        }
    }
    comptime {
        if (args.len != next_arg) {
            @compileError("Unused arguments");
        }
        if (state != State.Start) {
            @compileError("Incomplete format string: " ++ fmt);
        }
    }
    if (start_index < fmt.len) {
        try output(context, fmt[start_index..]);
    }
}

pub fn formatValue(value: var, context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void {
    const T = @typeOf(value);
    switch (@typeId(T)) {
        builtin.TypeId.Int => {
            return formatInt(value, 10, false, 0, context, Errors, output);
        },
        builtin.TypeId.Float => {
            return formatFloat(value, context, Errors, output);
        },
        builtin.TypeId.Void => {
            return output(context, "void");
        },
        builtin.TypeId.Bool => {
            return output(context, if (value) "true" else "false");
        },
        builtin.TypeId.Nullable => {
            if (value) |payload| {
                return formatValue(payload, context, Errors, output);
            } else {
                return output(context, "null");
            }
        },
        builtin.TypeId.ErrorUnion => {
            if (value) |payload| {
                return formatValue(payload, context, Errors, output);
            } else |err| {
                return formatValue(err, context, Errors, output);
            }
        },
        builtin.TypeId.ErrorSet => {
            try output(context, "error.");
            return output(context, @errorName(value));
        },
        builtin.TypeId.Pointer => {
            if (@typeId(T.Child) == builtin.TypeId.Array and T.Child.Child == u8) {
                return output(context, (*value)[0..]);
            } else {
                @compileError("Unable to format type '" ++ @typeName(T) ++ "'");
            }
        },
        else => if (@canImplicitCast([]const u8, value)) {
            const casted_value = ([]const u8)(value);
            return output(context, casted_value);
        } else {
            @compileError("Unable to format type '" ++ @typeName(T) ++ "'");
        },
    }
}

pub fn formatAsciiChar(c: u8, context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void {
    return output(context, (&c)[0..1]);
}

pub fn formatBuf(buf: []const u8, width: usize,
    context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void
{
    try output(context, buf);

    var leftover_padding = if (width > buf.len) (width - buf.len) else return;
    const pad_byte: u8 = ' ';
    while (leftover_padding > 0) : (leftover_padding -= 1) {
        try output(context, (&pad_byte)[0..1]);
    }
}

pub fn formatFloat(value: var, context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void {
    var x = f64(value);

    // Errol doesn't handle these special cases.
    if (math.isNan(x)) {
        return output(context, "NaN");
    }
    if (math.signbit(x)) {
        try output(context, "-");
        x = -x;
    }
    if (math.isPositiveInf(x)) {
        return output(context, "Infinity");
    }
    if (x == 0.0) {
        return output(context, "0.0");
    }

    var buffer: [32]u8 = undefined;
    const float_decimal = errol3(x, buffer[0..]);
    try output(context, float_decimal.digits[0..1]);
    try output(context, ".");
    if (float_decimal.digits.len > 1) {
        const num_digits = if (@typeOf(value) == f32)
            math.min(usize(9), float_decimal.digits.len)
        else
            float_decimal.digits.len;
        try output(context, float_decimal.digits[1 .. num_digits]);
    } else {
        try output(context, "0");
    }

    if (float_decimal.exp != 1) {
        try output(context, "e");
        try formatInt(float_decimal.exp - 1, 10, false, 0, context, Errors, output);
    }
}

pub fn formatFloatDecimal(value: var, precision: usize, context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void {
    var x = f64(value);

    // Errol doesn't handle these special cases.
    if (math.isNan(x)) {
        return output(context, "NaN");
    }
    if (math.signbit(x)) {
        try output(context, "-");
        x = -x;
    }
    if (math.isPositiveInf(x)) {
        return output(context, "Infinity");
    }
    if (x == 0.0) {
        return output(context, "0.0");
    }

    var buffer: [32]u8 = undefined;
    const float_decimal = errol3(x, buffer[0..]);

    const num_left_digits = if (float_decimal.exp > 0) usize(float_decimal.exp) else 1;

    try output(context, float_decimal.digits[0 .. num_left_digits]);
    try output(context, ".");
    if (float_decimal.digits.len > 1) {
        const num_valid_digtis = if (@typeOf(value) == f32)  math.min(usize(7), float_decimal.digits.len)
        else
            float_decimal.digits.len;

        const num_right_digits = if (precision != 0)
            math.min(precision, (num_valid_digtis-num_left_digits))
        else
            num_valid_digtis - num_left_digits;
        try output(context, float_decimal.digits[num_left_digits .. (num_left_digits + num_right_digits)]);
    } else {
        try output(context, "0");
    }
}


pub fn formatInt(value: var, base: u8, uppercase: bool, width: usize,
    context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void
{
    if (@typeOf(value).is_signed) {
        return formatIntSigned(value, base, uppercase, width, context, Errors, output);
    } else {
        return formatIntUnsigned(value, base, uppercase, width, context, Errors, output);
    }
}

fn formatIntSigned(value: var, base: u8, uppercase: bool, width: usize,
    context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void
{
    const uint = @IntType(false, @typeOf(value).bit_count);
    if (value < 0) {
        const minus_sign: u8 = '-';
        try output(context, (&minus_sign)[0..1]);
        const new_value = uint(-(value + 1)) + 1;
        const new_width = if (width == 0) 0 else (width - 1);
        return formatIntUnsigned(new_value, base, uppercase, new_width, context, Errors, output);
    } else if (width == 0) {
        return formatIntUnsigned(uint(value), base, uppercase, width, context, Errors, output);
    } else {
        const plus_sign: u8 = '+';
        try output(context, (&plus_sign)[0..1]);
        const new_value = uint(value);
        const new_width = if (width == 0) 0 else (width - 1);
        return formatIntUnsigned(new_value, base, uppercase, new_width, context, Errors, output);
    }
}

fn formatIntUnsigned(value: var, base: u8, uppercase: bool, width: usize,
    context: var, comptime Errors: type, output: fn(@typeOf(context), []const u8)Errors!void) Errors!void
{
    // max_int_digits accounts for the minus sign. when printing an unsigned
    // number we don't need to do that.
    var buf: [max_int_digits - 1]u8 = undefined;
    var a = if (@sizeOf(@typeOf(value)) == 1) u8(value) else value;
    var index: usize = buf.len;

    while (true) {
        const digit = a % base;
        index -= 1;
        buf[index] = digitToChar(u8(digit), uppercase);
        a /= base;
        if (a == 0)
            break;
    }

    const digits_buf = buf[index..];
    const padding = if (width > digits_buf.len) (width - digits_buf.len) else 0;

    if (padding > index) {
        const zero_byte: u8 = '0';
        var leftover_padding = padding - index;
        while (true) {
            try output(context, (&zero_byte)[0..1]);
            leftover_padding -= 1;
            if (leftover_padding == 0)
                break;
        }
        mem.set(u8, buf[0..index], '0');
        return output(context, buf);
    } else {
        const padded_buf = buf[index - padding..];
        mem.set(u8, padded_buf[0..padding], '0');
        return output(context, padded_buf);
    }
}

pub fn formatIntBuf(out_buf: []u8, value: var, base: u8, uppercase: bool, width: usize) usize {
    var context = FormatIntBuf {
        .out_buf = out_buf,
        .index = 0,
    };
    formatInt(value, base, uppercase, width, &context, error{}, formatIntCallback) catch unreachable;
    return context.index;
}
const FormatIntBuf = struct {
    out_buf: []u8,
    index: usize,
};
fn formatIntCallback(context: &FormatIntBuf, bytes: []const u8) (error{}!void) {
    mem.copy(u8, context.out_buf[context.index..], bytes);
    context.index += bytes.len;
}

pub fn parseInt(comptime T: type, buf: []const u8, radix: u8) !T {
    if (!T.is_signed)
        return parseUnsigned(T, buf, radix);
    if (buf.len == 0)
        return T(0);
    if (buf[0] == '-') {
        return math.negate(try parseUnsigned(T, buf[1..], radix));
    } else if (buf[0] == '+') {
        return parseUnsigned(T, buf[1..], radix);
    } else {
        return parseUnsigned(T, buf, radix);
    }
}

test "fmt.parseInt" {
    assert((parseInt(i32, "-10", 10) catch unreachable) == -10);
    assert((parseInt(i32, "+10", 10) catch unreachable) == 10);
    assert(if (parseInt(i32, " 10", 10)) |_| false else |err| err == error.InvalidChar);
    assert(if (parseInt(i32, "10 ", 10)) |_| false else |err| err == error.InvalidChar);
    assert(if (parseInt(u32, "-10", 10)) |_| false else |err| err == error.InvalidChar);
    assert((parseInt(u8, "255", 10) catch unreachable) == 255);
    assert(if (parseInt(u8, "256", 10)) |_| false else |err| err == error.Overflow);
}

const ParseUnsignedError = error {
    /// The result cannot fit in the type specified
    Overflow,
    /// The input had a byte that was not a digit
    InvalidCharacter,
};

pub fn parseUnsigned(comptime T: type, buf: []const u8, radix: u8) ParseUnsignedError!T {
    var x: T = 0;

    for (buf) |c| {
        const digit = try charToDigit(c, radix);
        x = try math.mul(T, x, radix);
        x = try math.add(T, x, digit);
    }

    return x;
}

fn charToDigit(c: u8, radix: u8) (error{InvalidCharacter}!u8) {
    const value = switch (c) {
        '0' ... '9' => c - '0',
        'A' ... 'Z' => c - 'A' + 10,
        'a' ... 'z' => c - 'a' + 10,
        else => return error.InvalidCharacter,
    };

    if (value >= radix)
        return error.InvalidCharacter;

    return value;
}

fn digitToChar(digit: u8, uppercase: bool) u8 {
    return switch (digit) {
        0 ... 9 => digit + '0',
        10 ... 35 => digit + ((if (uppercase) u8('A') else u8('a')) - 10),
        else => unreachable,
    };
}

const BufPrintContext = struct {
    remaining: []u8,
};

fn bufPrintWrite(context: &BufPrintContext, bytes: []const u8) !void {
    if (context.remaining.len < bytes.len) return error.BufferTooSmall;
    mem.copy(u8, context.remaining, bytes);
    context.remaining = context.remaining[bytes.len..];
}

pub fn bufPrint(buf: []u8, comptime fmt: []const u8, args: ...) ![]u8 {
    var context = BufPrintContext { .remaining = buf, };
    try format(&context, error{BufferTooSmall}, bufPrintWrite, fmt, args);
    return buf[0..buf.len - context.remaining.len];
}

pub fn allocPrint(allocator: &mem.Allocator, comptime fmt: []const u8, args: ...) ![]u8 {
    var size: usize = 0;
    format(&size, error{}, countSize, fmt, args) catch |err| switch (err) {};
    const buf = try allocator.alloc(u8, size);
    return bufPrint(buf, fmt, args);
}

fn countSize(size: &usize, bytes: []const u8) !void {
    *size += bytes.len;
}

test "buf print int" {
    var buffer: [max_int_digits]u8 = undefined;
    const buf = buffer[0..];
    assert(mem.eql(u8, bufPrintIntToSlice(buf, i32(-12345678), 2, false, 0), "-101111000110000101001110"));
    assert(mem.eql(u8, bufPrintIntToSlice(buf, i32(-12345678), 10, false, 0), "-12345678"));
    assert(mem.eql(u8, bufPrintIntToSlice(buf, i32(-12345678), 16, false, 0), "-bc614e"));
    assert(mem.eql(u8, bufPrintIntToSlice(buf, i32(-12345678), 16, true, 0), "-BC614E"));

    assert(mem.eql(u8, bufPrintIntToSlice(buf, u32(12345678), 10, true, 0), "12345678"));

    assert(mem.eql(u8, bufPrintIntToSlice(buf, u32(666), 10, false, 6), "000666"));
    assert(mem.eql(u8, bufPrintIntToSlice(buf, u32(0x1234), 16, false, 6), "001234"));
    assert(mem.eql(u8, bufPrintIntToSlice(buf, u32(0x1234), 16, false, 1), "1234"));

    assert(mem.eql(u8, bufPrintIntToSlice(buf, i32(42), 10, false, 3), "+42"));
    assert(mem.eql(u8, bufPrintIntToSlice(buf, i32(-42), 10, false, 3), "-42"));
}

fn bufPrintIntToSlice(buf: []u8, value: var, base: u8, uppercase: bool, width: usize) []u8 {
    return buf[0..formatIntBuf(buf, value, base, uppercase, width)];
}

test "parse u64 digit too big" {
    _ = parseUnsigned(u64, "123a", 10) catch |err| {
        if (err == error.InvalidChar) return;
        unreachable;
    };
    unreachable;
}

test "parse unsigned comptime" {
    comptime {
        assert((try parseUnsigned(usize, "2", 10)) == 2);
    }
}

test "fmt.format" {
    {
        var buf1: [32]u8 = undefined;
        const value: ?i32 = 1234;
        const result = try bufPrint(buf1[0..], "nullable: {}\n", value);
        assert(mem.eql(u8, result, "nullable: 1234\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: ?i32 = null;
        const result = try bufPrint(buf1[0..], "nullable: {}\n", value);
        assert(mem.eql(u8, result, "nullable: null\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: error!i32 = 1234;
        const result = try bufPrint(buf1[0..], "error union: {}\n", value);
        assert(mem.eql(u8, result, "error union: 1234\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: error!i32 = error.InvalidChar;
        const result = try bufPrint(buf1[0..], "error union: {}\n", value);
        assert(mem.eql(u8, result, "error union: error.InvalidChar\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: u3 = 0b101;
        const result = try bufPrint(buf1[0..], "u3: {}\n", value);
        assert(mem.eql(u8, result, "u3: 5\n"));
    }

    // TODO get these tests passing in release modes
    // https://github.com/zig-lang/zig/issues/564
    if (builtin.mode == builtin.Mode.Debug) {
        {
            var buf1: [32]u8 = undefined;
            const value: f32 = 12.34;
            const result = try bufPrint(buf1[0..], "f32: {}\n", value);
            assert(mem.eql(u8, result, "f32: 1.23400001e1\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const value: f64 = -12.34e10;
            const result = try bufPrint(buf1[0..], "f64: {}\n", value);
            assert(mem.eql(u8, result, "f64: -1.234e11\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const result = try bufPrint(buf1[0..], "f64: {}\n", math.nan_f64);
            assert(mem.eql(u8, result, "f64: NaN\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const result = try bufPrint(buf1[0..], "f64: {}\n", math.inf_f64);
            assert(mem.eql(u8, result, "f64: Infinity\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const result = try bufPrint(buf1[0..], "f64: {}\n", -math.inf_f64);
            assert(mem.eql(u8, result, "f64: -Infinity\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const value: f32 = 1.1234;
            const result = try bufPrint(buf1[0..], "f32: {.1}\n", value);
            assert(mem.eql(u8, result, "f32: 1.1\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const value: f32 = 1234.567;
            const result = try bufPrint(buf1[0..], "f32: {.2}\n", value);
            assert(mem.eql(u8, result, "f32: 1234.56\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const value: f32 = -11.1234;
            const result = try bufPrint(buf1[0..], "f32: {.4}\n", value);
            // -11.1234 is converted to f64 -11.12339... internally (errol3() function takes f64).
            // -11.12339... is truncated to -11.1233
            assert(mem.eql(u8, result, "f32: -11.1233\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const value: f32 = 91.12345;
            const result = try bufPrint(buf1[0..], "f32: {.}\n", value);
            assert(mem.eql(u8, result, "f32: 91.12345\n"));
        }
        {
            var buf1: [32]u8 = undefined;
            const value: f64 = 91.12345678901235;
            const result = try bufPrint(buf1[0..], "f64: {.10}\n", value);
            assert(mem.eql(u8, result, "f64: 91.1234567890\n"));
        }

    }
}

pub fn trim(buf: []const u8) []const u8 {
    var start: usize = 0;
    while (start < buf.len and isWhiteSpace(buf[start])) : (start += 1) { }

    var end: usize = buf.len;
    while (true) {
        if (end > start) {
            const new_end = end - 1;
            if (isWhiteSpace(buf[new_end])) {
                end = new_end;
                continue;
            }
        }
        break;

    }
    return buf[start..end];
}

test "fmt.trim" {
    assert(mem.eql(u8, "abc", trim("\n  abc  \t")));
    assert(mem.eql(u8, "", trim("   ")));
    assert(mem.eql(u8, "", trim("")));
    assert(mem.eql(u8, "abc", trim(" abc")));
    assert(mem.eql(u8, "abc", trim("abc ")));
}

pub fn isWhiteSpace(byte: u8) bool {
    return switch (byte) {
        ' ', '\t', '\n', '\r' => true,
        else => false,
    };
}
