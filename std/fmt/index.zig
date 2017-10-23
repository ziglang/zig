const math = @import("../math/index.zig");
const debug = @import("../debug.zig");
const assert = debug.assert;
const mem = @import("../mem.zig");
const builtin = @import("builtin");
const errol3 = @import("errol/index.zig").errol3;

const max_int_digits = 65;

const State = enum { // TODO put inside format function and make sure the name and debug info is correct
    Start,
    OpenBrace,
    CloseBrace,
    Integer,
    IntegerWidth,
    Character,
    Buf,
    BufWidth,
};

/// Renders fmt string with args, calling output with slices of bytes.
/// Return false from output function and output will not be called again.
/// Returns false if output ever returned false, true otherwise.
pub fn format(context: var, output: fn(@typeOf(context), []const u8)->bool,
    comptime fmt: []const u8, args: ...) -> bool
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
                    // TODO if you make this an if statement with `and` then it breaks
                    if (start_index < i) {
                        if (!output(context, fmt[start_index..i]))
                            return false;
                    }
                    state = State.OpenBrace;
                },
                '}' => {
                    if (start_index < i) {
                        if (!output(context, fmt[start_index..i]))
                            return false;
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
                    if (!formatValue(args[next_arg], context, output))
                        return false;
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
                    if (!formatInt(args[next_arg], radix, uppercase, width, context, output))
                        return false;
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
                    width = comptime %%parseUnsigned(usize, fmt[width_start..i], 10);
                    if (!formatInt(args[next_arg], radix, uppercase, width, context, output))
                        return false;
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {},
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
            },
            State.BufWidth => switch (c) {
                '}' => {
                    width = comptime %%parseUnsigned(usize, fmt[width_start..i], 10);
                    if (!formatBuf(args[next_arg], width, context, output))
                        return false;
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {},
                else => @compileError("Unexpected character in format string: " ++ []u8{c}),
            },
            State.Character => switch (c) {
                '}' => {
                    if (!formatAsciiChar(args[next_arg], context, output))
                        return false;
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
        if (!output(context, fmt[start_index..]))
            return false;
    }

    return true;
}

pub fn formatValue(value: var, context: var, output: fn(@typeOf(context), []const u8)->bool) -> bool {
    const T = @typeOf(value);
    switch (@typeId(T)) {
        builtin.TypeId.Int => {
            return formatInt(value, 10, false, 0, context, output);
        },
        builtin.TypeId.Float => {
            return formatFloat(value, context, output);
        },
        builtin.TypeId.Void => {
            return output(context, "void");
        },
        builtin.TypeId.Bool => {
            return output(context, if (value) "true" else "false");
        },
        builtin.TypeId.Nullable => {
            if (value) |payload| {
                return formatValue(payload, context, output);
            } else {
                return output(context, "null");
            }
        },
        builtin.TypeId.ErrorUnion => {
            if (value) |payload| {
                return formatValue(payload, context, output);
            } else |err| {
                return formatValue(err, context, output);
            }
        },
        builtin.TypeId.Error => {
            if (!output(context, "error."))
                return false;
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

pub fn formatAsciiChar(c: u8, context: var, output: fn(@typeOf(context), []const u8)->bool) -> bool {
    return output(context, (&c)[0..1]);
}

pub fn formatBuf(buf: []const u8, width: usize,
    context: var, output: fn(@typeOf(context), []const u8)->bool) -> bool
{
    if (!output(context, buf))
        return false;

    var leftover_padding = if (width > buf.len) (width - buf.len) else return true;
    const pad_byte: u8 = ' ';
    while (leftover_padding > 0) : (leftover_padding -= 1) {
        if (!output(context, (&pad_byte)[0..1]))
            return false;
    }

    return true;
}

pub fn formatFloat(value: var, context: var, output: fn(@typeOf(context), []const u8)->bool) -> bool {
    var x = f64(value);

    // Errol doesn't handle these special cases.
    if (math.isNan(x)) {
        return output(context, "NaN");
    }
    if (math.isPositiveInf(x)) {
        return output(context, "Infinity");
    }
    if (math.isNegativeInf(x)) {
        return output(context, "-Infinity");
    }
    if (x == 0.0) {
        return output(context, "0.0");
    }
    if (x < 0.0) {
        if (!output(context, "-"))
            return false;
        x = -x;
    }

    var buffer: [32]u8 = undefined;
    const float_decimal = errol3(x, buffer[0..]);
    if (!output(context, float_decimal.digits[0..1]))
        return false;
    if (!output(context, "."))
        return false;
    if (float_decimal.digits.len > 1) {
        const num_digits = if (@typeOf(value) == f32) { usize(8) } else { usize(17) };
        if (!output(context, float_decimal.digits[1 .. math.min(num_digits, float_decimal.digits.len)]))
            return false;
    } else {
        if (!output(context, "0"))
            return false;
    }

    if (float_decimal.exp != 1) {
        if (!output(context, "e"))
            return false;
        if (!formatInt(float_decimal.exp - 1, 10, false, 0, context, output))
            return false;
    }
    return true;
}

pub fn formatInt(value: var, base: u8, uppercase: bool, width: usize,
    context: var, output: fn(@typeOf(context), []const u8)->bool) -> bool
{
    if (@typeOf(value).is_signed) {
        return formatIntSigned(value, base, uppercase, width, context, output);
    } else {
        return formatIntUnsigned(value, base, uppercase, width, context, output);
    }
}

fn formatIntSigned(value: var, base: u8, uppercase: bool, width: usize,
    context: var, output: fn(@typeOf(context), []const u8)->bool) -> bool
{
    const uint = @IntType(false, @typeOf(value).bit_count);
    if (value < 0) {
        const minus_sign: u8 = '-';
        if (!output(context, (&minus_sign)[0..1]))
            return false;
        const new_value = uint(-(value + 1)) + 1;
        const new_width = if (width == 0) 0 else (width - 1);
        return formatIntUnsigned(new_value, base, uppercase, new_width, context, output);
    } else if (width == 0) {
        return formatIntUnsigned(uint(value), base, uppercase, width, context, output);
    } else {
        const plus_sign: u8 = '+';
        if (!output(context, (&plus_sign)[0..1]))
            return false;
        const new_value = uint(value);
        const new_width = if (width == 0) 0 else (width - 1);
        return formatIntUnsigned(new_value, base, uppercase, new_width, context, output);
    }
}

fn formatIntUnsigned(value: var, base: u8, uppercase: bool, width: usize,
    context: var, output: fn(@typeOf(context), []const u8)->bool) -> bool
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
            if (!output(context, (&zero_byte)[0..1]))
                return false;
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

pub fn formatIntBuf(out_buf: []u8, value: var, base: u8, uppercase: bool, width: usize) -> usize {
    var context = FormatIntBuf {
        .out_buf = out_buf,
        .index = 0,
    };
    _ = formatInt(value, base, uppercase, width, &context, formatIntCallback);
    return context.index;
}
const FormatIntBuf = struct {
    out_buf: []u8,
    index: usize,
};
fn formatIntCallback(context: &FormatIntBuf, bytes: []const u8) -> bool {
    mem.copy(u8, context.out_buf[context.index..], bytes);
    context.index += bytes.len;
    return true;
}

pub fn parseInt(comptime T: type, buf: []const u8, radix: u8) -> %T {
    if (!T.is_signed)
        return parseUnsigned(T, buf, radix);
    if (buf.len == 0)
        return T(0);
    if (buf[0] == '-') {
        return math.negate(%return parseUnsigned(T, buf[1..], radix));
    } else if (buf[0] == '+') {
        return parseUnsigned(T, buf[1..], radix);
    } else {
        return parseUnsigned(T, buf, radix);
    }
}

test "fmt.parseInt" {
    assert(%%parseInt(i32, "-10", 10) == -10);
    assert(%%parseInt(i32, "+10", 10) == 10);
    assert(if (parseInt(i32, " 10", 10)) |_| false else |err| err == error.InvalidChar);
}

pub fn parseUnsigned(comptime T: type, buf: []const u8, radix: u8) -> %T {
    var x: T = 0;

    for (buf) |c| {
        const digit = %return charToDigit(c, radix);
        x = %return math.mul(T, x, radix);
        x = %return math.add(T, x, digit);
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
        else => unreachable,
    };
}

const BufPrintContext = struct {
    remaining: []u8,
};

fn bufPrintWrite(context: &BufPrintContext, bytes: []const u8) -> bool {
    mem.copy(u8, context.remaining, bytes);
    context.remaining = context.remaining[bytes.len..];
    return true;
}

pub fn bufPrint(buf: []u8, comptime fmt: []const u8, args: ...) -> []u8 {
    var context = BufPrintContext { .remaining = buf, };
    _ = format(&context, bufPrintWrite, fmt, args);
    return buf[0..buf.len - context.remaining.len];
}

pub fn allocPrint(allocator: &mem.Allocator, comptime fmt: []const u8, args: ...) -> %[]u8 {
    var size: usize = 0;
    _ = format(&size, countSize, fmt, args);
    const buf = %return allocator.alloc(u8, size);
    return bufPrint(buf, fmt, args);
}

fn countSize(size: &usize, bytes: []const u8) -> bool {
    *size += bytes.len;
    return true;
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

fn bufPrintIntToSlice(buf: []u8, value: var, base: u8, uppercase: bool, width: usize) -> []u8 {
    return buf[0..formatIntBuf(buf, value, base, uppercase, width)];
}

test "parse u64 digit too big" {
    _ = parseUnsigned(u64, "123a", 10) %% |err| {
        if (err == error.InvalidChar) return;
        unreachable;
    };
    unreachable;
}

test "parse unsigned comptime" {
    comptime {
        assert(%%parseUnsigned(usize, "2", 10) == 2);
    }
}

test "fmt.format" {
    {
        var buf1: [32]u8 = undefined;
        const value: ?i32 = 1234;
        const result = bufPrint(buf1[0..], "nullable: {}\n", value);
        assert(mem.eql(u8, result, "nullable: 1234\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: ?i32 = null;
        const result = bufPrint(buf1[0..], "nullable: {}\n", value);
        assert(mem.eql(u8, result, "nullable: null\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: %i32 = 1234;
        const result = bufPrint(buf1[0..], "error union: {}\n", value);
        assert(mem.eql(u8, result, "error union: 1234\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: %i32 = error.InvalidChar;
        const result = bufPrint(buf1[0..], "error union: {}\n", value);
        assert(mem.eql(u8, result, "error union: error.InvalidChar\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: u3 = 0b101;
        const result = bufPrint(buf1[0..], "u3: {}\n", value);
        assert(mem.eql(u8, result, "u3: 5\n"));
    }
}

pub fn trim(buf: []const u8) -> []const u8 {
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

pub fn isWhiteSpace(byte: u8) -> bool {
    return switch (byte) {
        ' ', '\t', '\n', '\r' => true,
        else => false,
    };
}
