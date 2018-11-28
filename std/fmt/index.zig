const std = @import("../index.zig");
const math = std.math;
const debug = std.debug;
const assert = debug.assert;
const assertError = debug.assertError;
const mem = std.mem;
const builtin = @import("builtin");
const errol = @import("errol/index.zig");
const lossyCast = std.math.lossyCast;

const max_int_digits = 65;

/// Renders fmt string with args, calling output with slices of bytes.
/// If `output` returns an error, the error is returned from `format` and
/// `output` is not called again.
pub fn format(context: var, comptime Errors: type, output: fn (@typeOf(context), []const u8) Errors!void, comptime fmt: []const u8, args: ...) Errors!void {
    const State = enum {
        Start,
        OpenBrace,
        CloseBrace,
        FormatString,
        Pointer,
    };

    comptime var start_index = 0;
    comptime var state = State.Start;
    comptime var next_arg = 0;

    inline for (fmt) |c, i| {
        switch (state) {
            State.Start => switch (c) {
                '{' => {
                    if (start_index < i) {
                        try output(context, fmt[start_index..i]);
                    }
                    start_index = i;
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
                    try formatType(args[next_arg], fmt[0..0], context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '*' => state = State.Pointer,
                else => {
                    state = State.FormatString;
                },
            },
            State.CloseBrace => switch (c) {
                '}' => {
                    state = State.Start;
                    start_index = i;
                },
                else => @compileError("Single '}' encountered in format string"),
            },
            State.FormatString => switch (c) {
                '}' => {
                    const s = start_index + 1;
                    try formatType(args[next_arg], fmt[s..i], context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                else => {},
            },
            State.Pointer => switch (c) {
                '}' => {
                    try output(context, @typeName(@typeOf(args[next_arg]).Child));
                    try output(context, "@");
                    try formatInt(@ptrToInt(args[next_arg]), 16, false, 0, context, Errors, output);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                else => @compileError("Unexpected format character after '*'"),
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

pub fn formatType(
    value: var,
    comptime fmt: []const u8,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    const T = @typeOf(value);
    if (T == anyerror) {
        try output(context, "error.");
        return output(context, @errorName(value));
    }
    switch (@typeInfo(T)) {
        builtin.TypeId.Int, builtin.TypeId.Float => {
            return formatValue(value, fmt, context, Errors, output);
        },
        builtin.TypeId.Void => {
            return output(context, "void");
        },
        builtin.TypeId.Bool => {
            return output(context, if (value) "true" else "false");
        },
        builtin.TypeId.Optional => {
            if (value) |payload| {
                return formatType(payload, fmt, context, Errors, output);
            } else {
                return output(context, "null");
            }
        },
        builtin.TypeId.ErrorUnion => {
            if (value) |payload| {
                return formatType(payload, fmt, context, Errors, output);
            } else |err| {
                return formatType(err, fmt, context, Errors, output);
            }
        },
        builtin.TypeId.ErrorSet => {
            try output(context, "error.");
            return output(context, @errorName(value));
        },
        builtin.TypeId.Promise => {
            return format(context, Errors, output, "promise@{x}", @ptrToInt(value));
        },
        builtin.TypeId.Enum, builtin.TypeId.Union, builtin.TypeId.Struct => {
            const has_cust_fmt = comptime cf: {
                const info = @typeInfo(T);
                const defs = switch (info) {
                    builtin.TypeId.Struct => |s| s.defs,
                    builtin.TypeId.Union => |u| u.defs,
                    builtin.TypeId.Enum => |e| e.defs,
                    else => unreachable,
                };

                for (defs) |def| {
                    if (mem.eql(u8, def.name, "format")) {
                        break :cf true;
                    }
                }
                break :cf false;
            };
            if (has_cust_fmt) return value.format(fmt, context, Errors, output);

            try output(context, @typeName(T));
            switch (comptime @typeId(T)) {
                builtin.TypeId.Enum => {
                    try output(context, ".");
                    try formatType(@tagName(value), "", context, Errors, output);
                    return;
                },
                builtin.TypeId.Struct => {
                    comptime var field_i = 0;
                    inline while (field_i < @memberCount(T)) : (field_i += 1) {
                        if (field_i == 0) {
                            try output(context, "{ .");
                        } else {
                            try output(context, ", .");
                        }
                        try output(context, @memberName(T, field_i));
                        try output(context, " = ");
                        try formatType(@field(value, @memberName(T, field_i)), "", context, Errors, output);
                    }
                    try output(context, " }");
                },
                builtin.TypeId.Union => {
                    const info = @typeInfo(T).Union;
                    if (info.tag_type) |UnionTagType| {
                        try output(context, "{ .");
                        try output(context, @tagName(UnionTagType(value)));
                        try output(context, " = ");
                        inline for (info.fields) |u_field| {
                            if (@enumToInt(UnionTagType(value)) == u_field.enum_field.?.value) {
                                try formatType(@field(value, u_field.name), "", context, Errors, output);
                            }
                        }
                        try output(context, " }");
                    } else {
                        try format(context, Errors, output, "@{x}", @ptrToInt(&value));
                    }
                },
                else => unreachable,
            }
            return;
        },
        builtin.TypeId.Pointer => |ptr_info| switch (ptr_info.size) {
            builtin.TypeInfo.Pointer.Size.One => switch (@typeInfo(ptr_info.child)) {
                builtin.TypeId.Array => |info| {
                    if (info.child == u8) {
                        return formatText(value, fmt, context, Errors, output);
                    }
                    return format(context, Errors, output, "{}@{x}", @typeName(T.Child), @ptrToInt(value));
                },
                builtin.TypeId.Enum, builtin.TypeId.Union, builtin.TypeId.Struct => {
                    return formatType(value.*, fmt, context, Errors, output);
                },
                else => return format(context, Errors, output, "{}@{x}", @typeName(T.Child), @ptrToInt(value)),
            },
            builtin.TypeInfo.Pointer.Size.Many => {
                if (ptr_info.child == u8) {
                    if (fmt.len > 0 and fmt[0] == 's') {
                        const len = std.cstr.len(value);
                        return formatText(value[0..len], fmt, context, Errors, output);
                    }
                }
                return format(context, Errors, output, "{}@{x}", @typeName(T.Child), @ptrToInt(value));
            },
            builtin.TypeInfo.Pointer.Size.Slice => {
                if (fmt.len > 0 and ((fmt[0] == 'x') or (fmt[0] == 'X'))) {
                    return formatText(value, fmt, context, Errors, output);
                }
                const casted_value = ([]const u8)(value);
                return output(context, casted_value);
            },
        },
        builtin.TypeId.Array => |info| {
            if (info.child == u8) {
                return formatText(value, fmt, context, Errors, output);
            }
            return format(context, Errors, output, "{}@{x}", @typeName(T.Child), @ptrToInt(&value));
        },
        else => @compileError("Unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

fn formatValue(
    value: var,
    comptime fmt: []const u8,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    if (fmt.len > 0) {
        if (fmt[0] == 'B') {
            comptime var width: ?usize = null;
            if (fmt.len > 1) {
                if (fmt[1] == 'i') {
                    if (fmt.len > 2) width = comptime (parseUnsigned(usize, fmt[2..], 10) catch unreachable);
                    return formatBytes(value, width, 1024, context, Errors, output);
                }
                width = comptime (parseUnsigned(usize, fmt[1..], 10) catch unreachable);
            }
            return formatBytes(value, width, 1000, context, Errors, output);
        }
    }

    comptime var T = @typeOf(value);
    switch (@typeId(T)) {
        builtin.TypeId.Float => return formatFloatValue(value, fmt, context, Errors, output),
        builtin.TypeId.Int => return formatIntValue(value, fmt, context, Errors, output),
        else => unreachable,
    }
}

pub fn formatIntValue(
    value: var,
    comptime fmt: []const u8,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    comptime var radix = 10;
    comptime var uppercase = false;
    comptime var width = 0;
    if (fmt.len > 0) {
        switch (fmt[0]) {
            'c' => {
                if (@typeOf(value) == u8) {
                    if (fmt.len > 1) @compileError("Unknown format character: " ++ []u8{fmt[1]});
                    return formatAsciiChar(value, context, Errors, output);
                }
            },
            'b' => {
                radix = 2;
                uppercase = false;
                width = 0;
            },
            'd' => {
                radix = 10;
                uppercase = false;
                width = 0;
            },
            'x' => {
                radix = 16;
                uppercase = false;
                width = 0;
            },
            'X' => {
                radix = 16;
                uppercase = true;
                width = 0;
            },
            else => @compileError("Unknown format character: " ++ []u8{fmt[0]}),
        }
        if (fmt.len > 1) width = comptime (parseUnsigned(usize, fmt[1..], 10) catch unreachable);
    }
    return formatInt(value, radix, uppercase, width, context, Errors, output);
}

fn formatFloatValue(
    value: var,
    comptime fmt: []const u8,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    comptime var width: ?usize = null;
    comptime var float_fmt = 'e';
    if (fmt.len > 0) {
        float_fmt = fmt[0];
        if (fmt.len > 1) width = comptime (parseUnsigned(usize, fmt[1..], 10) catch unreachable);
    }

    switch (float_fmt) {
        'e' => try formatFloatScientific(value, width, context, Errors, output),
        '.' => try formatFloatDecimal(value, width, context, Errors, output),
        else => @compileError("Unknown format character: " ++ []u8{float_fmt}),
    }
}

pub fn formatText(
    bytes: []const u8,
    comptime fmt: []const u8,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    if (fmt.len > 0) {
        if (fmt[0] == 's') {
            comptime var width = 0;
            if (fmt.len > 1) width = comptime (parseUnsigned(usize, fmt[1..], 10) catch unreachable);
            return formatBuf(bytes, width, context, Errors, output);
        } else if ((fmt[0] == 'x') or (fmt[0] == 'X')) {
            for (bytes) |c| {
                try formatInt(c, 16, fmt[0] == 'X', 2, context, Errors, output);
            }
            return;
        } else @compileError("Unknown format character: " ++ []u8{fmt[0]});
    }
    return output(context, bytes);
}

pub fn formatAsciiChar(
    c: u8,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    return output(context, (*[1]u8)(&c)[0..]);
}

pub fn formatBuf(
    buf: []const u8,
    width: usize,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    try output(context, buf);

    var leftover_padding = if (width > buf.len) (width - buf.len) else return;
    const pad_byte: u8 = ' ';
    while (leftover_padding > 0) : (leftover_padding -= 1) {
        try output(context, (*[1]u8)(&pad_byte)[0..1]);
    }
}

// Print a float in scientific notation to the specified precision. Null uses full precision.
// It should be the case that every full precision, printed value can be re-parsed back to the
// same type unambiguously.
pub fn formatFloatScientific(
    value: var,
    maybe_precision: ?usize,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    var x = @floatCast(f64, value);

    // Errol doesn't handle these special cases.
    if (math.signbit(x)) {
        try output(context, "-");
        x = -x;
    }

    if (math.isNan(x)) {
        return output(context, "nan");
    }
    if (math.isPositiveInf(x)) {
        return output(context, "inf");
    }
    if (x == 0.0) {
        try output(context, "0");

        if (maybe_precision) |precision| {
            if (precision != 0) {
                try output(context, ".");
                var i: usize = 0;
                while (i < precision) : (i += 1) {
                    try output(context, "0");
                }
            }
        } else {
            try output(context, ".0");
        }

        try output(context, "e+00");
        return;
    }

    var buffer: [32]u8 = undefined;
    var float_decimal = errol.errol3(x, buffer[0..]);

    if (maybe_precision) |precision| {
        errol.roundToPrecision(&float_decimal, precision, errol.RoundMode.Scientific);

        try output(context, float_decimal.digits[0..1]);

        // {e0} case prints no `.`
        if (precision != 0) {
            try output(context, ".");

            var printed: usize = 0;
            if (float_decimal.digits.len > 1) {
                const num_digits = math.min(float_decimal.digits.len, precision + 1);
                try output(context, float_decimal.digits[1..num_digits]);
                printed += num_digits - 1;
            }

            while (printed < precision) : (printed += 1) {
                try output(context, "0");
            }
        }
    } else {
        try output(context, float_decimal.digits[0..1]);
        try output(context, ".");
        if (float_decimal.digits.len > 1) {
            const num_digits = if (@typeOf(value) == f32) math.min(usize(9), float_decimal.digits.len) else float_decimal.digits.len;

            try output(context, float_decimal.digits[1..num_digits]);
        } else {
            try output(context, "0");
        }
    }

    try output(context, "e");
    const exp = float_decimal.exp - 1;

    if (exp >= 0) {
        try output(context, "+");
        if (exp > -10 and exp < 10) {
            try output(context, "0");
        }
        try formatInt(exp, 10, false, 0, context, Errors, output);
    } else {
        try output(context, "-");
        if (exp > -10 and exp < 10) {
            try output(context, "0");
        }
        try formatInt(-exp, 10, false, 0, context, Errors, output);
    }
}

// Print a float of the format x.yyyyy where the number of y is specified by the precision argument.
// By default floats are printed at full precision (no rounding).
pub fn formatFloatDecimal(
    value: var,
    maybe_precision: ?usize,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    var x = f64(value);

    // Errol doesn't handle these special cases.
    if (math.signbit(x)) {
        try output(context, "-");
        x = -x;
    }

    if (math.isNan(x)) {
        return output(context, "nan");
    }
    if (math.isPositiveInf(x)) {
        return output(context, "inf");
    }
    if (x == 0.0) {
        try output(context, "0");

        if (maybe_precision) |precision| {
            if (precision != 0) {
                try output(context, ".");
                var i: usize = 0;
                while (i < precision) : (i += 1) {
                    try output(context, "0");
                }
            } else {
                try output(context, ".0");
            }
        } else {
            try output(context, "0");
        }

        return;
    }

    // non-special case, use errol3
    var buffer: [32]u8 = undefined;
    var float_decimal = errol.errol3(x, buffer[0..]);

    if (maybe_precision) |precision| {
        errol.roundToPrecision(&float_decimal, precision, errol.RoundMode.Decimal);

        // exp < 0 means the leading is always 0 as errol result is normalized.
        var num_digits_whole = if (float_decimal.exp > 0) @intCast(usize, float_decimal.exp) else 0;

        // the actual slice into the buffer, we may need to zero-pad between num_digits_whole and this.
        var num_digits_whole_no_pad = math.min(num_digits_whole, float_decimal.digits.len);

        if (num_digits_whole > 0) {
            // We may have to zero pad, for instance 1e4 requires zero padding.
            try output(context, float_decimal.digits[0..num_digits_whole_no_pad]);

            var i = num_digits_whole_no_pad;
            while (i < num_digits_whole) : (i += 1) {
                try output(context, "0");
            }
        } else {
            try output(context, "0");
        }

        // {.0} special case doesn't want a trailing '.'
        if (precision == 0) {
            return;
        }

        try output(context, ".");

        // Keep track of fractional count printed for case where we pre-pad then post-pad with 0's.
        var printed: usize = 0;

        // Zero-fill until we reach significant digits or run out of precision.
        if (float_decimal.exp <= 0) {
            const zero_digit_count = @intCast(usize, -float_decimal.exp);
            const zeros_to_print = math.min(zero_digit_count, precision);

            var i: usize = 0;
            while (i < zeros_to_print) : (i += 1) {
                try output(context, "0");
                printed += 1;
            }

            if (printed >= precision) {
                return;
            }
        }

        // Remaining fractional portion, zero-padding if insufficient.
        debug.assert(precision >= printed);
        if (num_digits_whole_no_pad + precision - printed < float_decimal.digits.len) {
            try output(context, float_decimal.digits[num_digits_whole_no_pad .. num_digits_whole_no_pad + precision - printed]);
            return;
        } else {
            try output(context, float_decimal.digits[num_digits_whole_no_pad..]);
            printed += float_decimal.digits.len - num_digits_whole_no_pad;

            while (printed < precision) : (printed += 1) {
                try output(context, "0");
            }
        }
    } else {
        // exp < 0 means the leading is always 0 as errol result is normalized.
        var num_digits_whole = if (float_decimal.exp > 0) @intCast(usize, float_decimal.exp) else 0;

        // the actual slice into the buffer, we may need to zero-pad between num_digits_whole and this.
        var num_digits_whole_no_pad = math.min(num_digits_whole, float_decimal.digits.len);

        if (num_digits_whole > 0) {
            // We may have to zero pad, for instance 1e4 requires zero padding.
            try output(context, float_decimal.digits[0..num_digits_whole_no_pad]);

            var i = num_digits_whole_no_pad;
            while (i < num_digits_whole) : (i += 1) {
                try output(context, "0");
            }
        } else {
            try output(context, "0");
        }

        // Omit `.` if no fractional portion
        if (float_decimal.exp >= 0 and num_digits_whole_no_pad == float_decimal.digits.len) {
            return;
        }

        try output(context, ".");

        // Zero-fill until we reach significant digits or run out of precision.
        if (float_decimal.exp < 0) {
            const zero_digit_count = @intCast(usize, -float_decimal.exp);

            var i: usize = 0;
            while (i < zero_digit_count) : (i += 1) {
                try output(context, "0");
            }
        }

        try output(context, float_decimal.digits[num_digits_whole_no_pad..]);
    }
}

pub fn formatBytes(
    value: var,
    width: ?usize,
    comptime radix: usize,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    if (value == 0) {
        return output(context, "0B");
    }

    const mags_si = " kMGTPEZY";
    const mags_iec = " KMGTPEZY";
    const magnitude = switch (radix) {
        1000 => math.min(math.log2(value) / comptime math.log2(1000), mags_si.len - 1),
        1024 => math.min(math.log2(value) / 10, mags_iec.len - 1),
        else => unreachable,
    };
    const new_value = lossyCast(f64, value) / math.pow(f64, lossyCast(f64, radix), lossyCast(f64, magnitude));
    const suffix = switch (radix) {
        1000 => mags_si[magnitude],
        1024 => mags_iec[magnitude],
        else => unreachable,
    };

    try formatFloatDecimal(new_value, width, context, Errors, output);

    if (suffix == ' ') {
        return output(context, "B");
    }

    const buf = switch (radix) {
        1000 => []u8{ suffix, 'B' },
        1024 => []u8{ suffix, 'i', 'B' },
        else => unreachable,
    };
    return output(context, buf);
}

pub fn formatInt(
    value: var,
    base: u8,
    uppercase: bool,
    width: usize,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    if (@typeOf(value).is_signed) {
        return formatIntSigned(value, base, uppercase, width, context, Errors, output);
    } else {
        return formatIntUnsigned(value, base, uppercase, width, context, Errors, output);
    }
}

fn formatIntSigned(
    value: var,
    base: u8,
    uppercase: bool,
    width: usize,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    const uint = @IntType(false, @typeOf(value).bit_count);
    if (value < 0) {
        const minus_sign: u8 = '-';
        try output(context, (*[1]u8)(&minus_sign)[0..]);
        const new_value = @intCast(uint, -(value + 1)) + 1;
        const new_width = if (width == 0) 0 else (width - 1);
        return formatIntUnsigned(new_value, base, uppercase, new_width, context, Errors, output);
    } else if (width == 0) {
        return formatIntUnsigned(@intCast(uint, value), base, uppercase, width, context, Errors, output);
    } else {
        const plus_sign: u8 = '+';
        try output(context, (*[1]u8)(&plus_sign)[0..]);
        const new_value = @intCast(uint, value);
        const new_width = if (width == 0) 0 else (width - 1);
        return formatIntUnsigned(new_value, base, uppercase, new_width, context, Errors, output);
    }
}

fn formatIntUnsigned(
    value: var,
    base: u8,
    uppercase: bool,
    width: usize,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    // max_int_digits accounts for the minus sign. when printing an unsigned
    // number we don't need to do that.
    var buf: [max_int_digits - 1]u8 = undefined;
    const min_int_bits = comptime math.max(@typeOf(value).bit_count, @typeOf(base).bit_count);
    const MinInt = @IntType(@typeOf(value).is_signed, min_int_bits);
    var a: MinInt = value;
    var index: usize = buf.len;

    while (true) {
        const digit = a % base;
        index -= 1;
        buf[index] = digitToChar(@intCast(u8, digit), uppercase);
        a /= base;
        if (a == 0) break;
    }

    const digits_buf = buf[index..];
    const padding = if (width > digits_buf.len) (width - digits_buf.len) else 0;

    if (padding > index) {
        const zero_byte: u8 = '0';
        var leftover_padding = padding - index;
        while (true) {
            try output(context, (*[1]u8)(&zero_byte)[0..]);
            leftover_padding -= 1;
            if (leftover_padding == 0) break;
        }
        mem.set(u8, buf[0..index], '0');
        return output(context, buf);
    } else {
        const padded_buf = buf[index - padding ..];
        mem.set(u8, padded_buf[0..padding], '0');
        return output(context, padded_buf);
    }
}

pub fn formatIntBuf(out_buf: []u8, value: var, base: u8, uppercase: bool, width: usize) usize {
    var context = FormatIntBuf{
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
fn formatIntCallback(context: *FormatIntBuf, bytes: []const u8) (error{}!void) {
    mem.copy(u8, context.out_buf[context.index..], bytes);
    context.index += bytes.len;
}

pub fn parseInt(comptime T: type, buf: []const u8, radix: u8) !T {
    if (!T.is_signed) return parseUnsigned(T, buf, radix);
    if (buf.len == 0) return T(0);
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
    assert(if (parseInt(i32, " 10", 10)) |_| false else |err| err == error.InvalidCharacter);
    assert(if (parseInt(i32, "10 ", 10)) |_| false else |err| err == error.InvalidCharacter);
    assert(if (parseInt(u32, "-10", 10)) |_| false else |err| err == error.InvalidCharacter);
    assert((parseInt(u8, "255", 10) catch unreachable) == 255);
    assert(if (parseInt(u8, "256", 10)) |_| false else |err| err == error.Overflow);
}

const ParseUnsignedError = error{
    /// The result cannot fit in the type specified
    Overflow,

    /// The input had a byte that was not a digit
    InvalidCharacter,
};

pub fn parseUnsigned(comptime T: type, buf: []const u8, radix: u8) ParseUnsignedError!T {
    var x: T = 0;

    for (buf) |c| {
        const digit = try charToDigit(c, radix);

        if (x != 0) x = try math.mul(T, x, try math.cast(T, radix));
        x = try math.add(T, x, try math.cast(T, digit));
    }

    return x;
}

test "parseUnsigned" {
    assert((try parseUnsigned(u16, "050124", 10)) == 50124);
    assert((try parseUnsigned(u16, "65535", 10)) == 65535);
    assertError(parseUnsigned(u16, "65536", 10), error.Overflow);

    assert((try parseUnsigned(u64, "0ffffffffffffffff", 16)) == 0xffffffffffffffff);
    assertError(parseUnsigned(u64, "10000000000000000", 16), error.Overflow);

    assert((try parseUnsigned(u32, "DeadBeef", 16)) == 0xDEADBEEF);

    assert((try parseUnsigned(u7, "1", 10)) == 1);
    assert((try parseUnsigned(u7, "1000", 2)) == 8);

    assertError(parseUnsigned(u32, "f", 10), error.InvalidCharacter);
    assertError(parseUnsigned(u8, "109", 8), error.InvalidCharacter);

    assert((try parseUnsigned(u32, "NUMBER", 36)) == 1442151747);

    // these numbers should fit even though the radix itself doesn't fit in the destination type
    assert((try parseUnsigned(u1, "0", 10)) == 0);
    assert((try parseUnsigned(u1, "1", 10)) == 1);
    assertError(parseUnsigned(u1, "2", 10), error.Overflow);
    assert((try parseUnsigned(u1, "001", 16)) == 1);
    assert((try parseUnsigned(u2, "3", 16)) == 3);
    assertError(parseUnsigned(u2, "4", 16), error.Overflow);
}

pub fn charToDigit(c: u8, radix: u8) (error{InvalidCharacter}!u8) {
    const value = switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => return error.InvalidCharacter,
    };

    if (value >= radix) return error.InvalidCharacter;

    return value;
}

fn digitToChar(digit: u8, uppercase: bool) u8 {
    return switch (digit) {
        0...9 => digit + '0',
        10...35 => digit + ((if (uppercase) u8('A') else u8('a')) - 10),
        else => unreachable,
    };
}

const BufPrintContext = struct {
    remaining: []u8,
};

fn bufPrintWrite(context: *BufPrintContext, bytes: []const u8) !void {
    if (context.remaining.len < bytes.len) return error.BufferTooSmall;
    mem.copy(u8, context.remaining, bytes);
    context.remaining = context.remaining[bytes.len..];
}

pub fn bufPrint(buf: []u8, comptime fmt: []const u8, args: ...) ![]u8 {
    var context = BufPrintContext{ .remaining = buf };
    try format(&context, error{BufferTooSmall}, bufPrintWrite, fmt, args);
    return buf[0 .. buf.len - context.remaining.len];
}

pub const AllocPrintError = error{OutOfMemory};

pub fn allocPrint(allocator: *mem.Allocator, comptime fmt: []const u8, args: ...) AllocPrintError![]u8 {
    var size: usize = 0;
    format(&size, error{}, countSize, fmt, args) catch |err| switch (err) {};
    const buf = try allocator.alloc(u8, size);
    return bufPrint(buf, fmt, args) catch |err| switch (err) {
        error.BufferTooSmall => unreachable, // we just counted the size above
    };
}

fn countSize(size: *usize, bytes: []const u8) (error{}!void) {
    size.* += bytes.len;
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
        if (err == error.InvalidCharacter) return;
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
        const value: ?i32 = 1234;
        try testFmt("optional: 1234\n", "optional: {}\n", value);
    }
    {
        const value: ?i32 = null;
        try testFmt("optional: null\n", "optional: {}\n", value);
    }
    {
        const value: anyerror!i32 = 1234;
        try testFmt("error union: 1234\n", "error union: {}\n", value);
    }
    {
        const value: anyerror!i32 = error.InvalidChar;
        try testFmt("error union: error.InvalidChar\n", "error union: {}\n", value);
    }
    {
        const value: u3 = 0b101;
        try testFmt("u3: 5\n", "u3: {}\n", value);
    }
    {
        const value: u8 = 'a';
        try testFmt("u8: a\n", "u8: {c}\n", value);
    }
    {
        const value: u8 = 0b1100;
        try testFmt("u8: 0b1100\n", "u8: 0b{b}\n", value);
    }
    {
        const value: [3]u8 = "abc";
        try testFmt("array: abc\n", "array: {}\n", value);
        try testFmt("array: abc\n", "array: {}\n", &value);

        var buf: [100]u8 = undefined;
        try testFmt(
            try bufPrint(buf[0..], "array: [3]u8@{x}\n", @ptrToInt(&value)),
            "array: {*}\n",
            &value,
        );
    }
    {
        const value: []const u8 = "abc";
        try testFmt("slice: abc\n", "slice: {}\n", value);
    }
    {
        const value = @intToPtr(*i32, 0xdeadbeef);
        try testFmt("pointer: i32@deadbeef\n", "pointer: {}\n", value);
        try testFmt("pointer: i32@deadbeef\n", "pointer: {*}\n", value);
    }
    try testFmt("buf: Test \n", "buf: {s5}\n", "Test");
    try testFmt("buf: Test\n Other text", "buf: {s}\n Other text", "Test");
    try testFmt("cstr: Test C\n", "cstr: {s}\n", c"Test C");
    try testFmt("cstr: Test C    \n", "cstr: {s10}\n", c"Test C");
    try testFmt("file size: 63MiB\n", "file size: {Bi}\n", usize(63 * 1024 * 1024));
    try testFmt("file size: 66.06MB\n", "file size: {B2}\n", usize(63 * 1024 * 1024));
    {
        const Struct = struct {
            field: u8,
        };
        const value = Struct{ .field = 42 };
        try testFmt("struct: Struct{ .field = 42 }\n", "struct: {}\n", value);
        try testFmt("struct: Struct{ .field = 42 }\n", "struct: {}\n", &value);
    }
    {
        const Struct = struct {
            a: u0,
            b: u1,
        };
        const value = Struct{ .a = 0, .b = 1 };
        try testFmt("struct: Struct{ .a = 0, .b = 1 }\n", "struct: {}\n", value);
    }
    {
        const Enum = enum {
            One,
            Two,
        };
        const value = Enum.Two;
        try testFmt("enum: Enum.Two\n", "enum: {}\n", value);
        try testFmt("enum: Enum.Two\n", "enum: {}\n", &value);
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f32 = 1.34;
        const result = try bufPrint(buf1[0..], "f32: {e}\n", value);
        assert(mem.eql(u8, result, "f32: 1.34000003e+00\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f32 = 12.34;
        const result = try bufPrint(buf1[0..], "f32: {e}\n", value);
        assert(mem.eql(u8, result, "f32: 1.23400001e+01\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = -12.34e10;
        const result = try bufPrint(buf1[0..], "f64: {e}\n", value);
        assert(mem.eql(u8, result, "f64: -1.234e+11\n"));
    }
    {
        // This fails on release due to a minor rounding difference.
        // --release-fast outputs 9.999960000000001e-40 vs. the expected.
        // TODO fix this, it should be the same in Debug and ReleaseFast
        if (builtin.mode == builtin.Mode.Debug) {
            var buf1: [32]u8 = undefined;
            const value: f64 = 9.999960e-40;
            const result = try bufPrint(buf1[0..], "f64: {e}\n", value);
            assert(mem.eql(u8, result, "f64: 9.99996e-40\n"));
        }
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 1.409706e-42;
        const result = try bufPrint(buf1[0..], "f64: {e5}\n", value);
        assert(mem.eql(u8, result, "f64: 1.40971e-42\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = @bitCast(f32, u32(814313563));
        const result = try bufPrint(buf1[0..], "f64: {e5}\n", value);
        assert(mem.eql(u8, result, "f64: 1.00000e-09\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = @bitCast(f32, u32(1006632960));
        const result = try bufPrint(buf1[0..], "f64: {e5}\n", value);
        assert(mem.eql(u8, result, "f64: 7.81250e-03\n"));
    }
    {
        // libc rounds 1.000005e+05 to 1.00000e+05 but zig does 1.00001e+05.
        // In fact, libc doesn't round a lot of 5 cases up when one past the precision point.
        var buf1: [32]u8 = undefined;
        const value: f64 = @bitCast(f32, u32(1203982400));
        const result = try bufPrint(buf1[0..], "f64: {e5}\n", value);
        assert(mem.eql(u8, result, "f64: 1.00001e+05\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const result = try bufPrint(buf1[0..], "f64: {}\n", math.nan_f64);
        assert(mem.eql(u8, result, "f64: nan\n"));
    }
    if (builtin.arch != builtin.Arch.armv8) {
        // negative nan is not defined by IEE 754,
        // and ARM thus normalizes it to positive nan
        var buf1: [32]u8 = undefined;
        const result = try bufPrint(buf1[0..], "f64: {}\n", -math.nan_f64);
        assert(mem.eql(u8, result, "f64: -nan\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const result = try bufPrint(buf1[0..], "f64: {}\n", math.inf_f64);
        assert(mem.eql(u8, result, "f64: inf\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const result = try bufPrint(buf1[0..], "f64: {}\n", -math.inf_f64);
        assert(mem.eql(u8, result, "f64: -inf\n"));
    }
    {
        var buf1: [64]u8 = undefined;
        const value: f64 = 1.52314e+29;
        const result = try bufPrint(buf1[0..], "f64: {.}\n", value);
        assert(mem.eql(u8, result, "f64: 152314000000000000000000000000\n"));
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
        assert(mem.eql(u8, result, "f32: 1234.57\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f32 = -11.1234;
        const result = try bufPrint(buf1[0..], "f32: {.4}\n", value);
        // -11.1234 is converted to f64 -11.12339... internally (errol3() function takes f64).
        // -11.12339... is rounded back up to -11.1234
        assert(mem.eql(u8, result, "f32: -11.1234\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f32 = 91.12345;
        const result = try bufPrint(buf1[0..], "f32: {.5}\n", value);
        assert(mem.eql(u8, result, "f32: 91.12345\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 91.12345678901235;
        const result = try bufPrint(buf1[0..], "f64: {.10}\n", value);
        assert(mem.eql(u8, result, "f64: 91.1234567890\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 0.0;
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 0.00000\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 5.700;
        const result = try bufPrint(buf1[0..], "f64: {.0}\n", value);
        assert(mem.eql(u8, result, "f64: 6\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 9.999;
        const result = try bufPrint(buf1[0..], "f64: {.1}\n", value);
        assert(mem.eql(u8, result, "f64: 10.0\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 1.0;
        const result = try bufPrint(buf1[0..], "f64: {.3}\n", value);
        assert(mem.eql(u8, result, "f64: 1.000\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 0.0003;
        const result = try bufPrint(buf1[0..], "f64: {.8}\n", value);
        assert(mem.eql(u8, result, "f64: 0.00030000\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 1.40130e-45;
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 0.00000\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = 9.999960e-40;
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 0.00000\n"));
    }
    // libc checks
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = f64(@bitCast(f32, u32(916964781)));
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 0.00001\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = f64(@bitCast(f32, u32(925353389)));
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 0.00001\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = f64(@bitCast(f32, u32(1036831278)));
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 0.10000\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = f64(@bitCast(f32, u32(1065353133)));
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 1.00000\n"));
    }
    {
        var buf1: [32]u8 = undefined;
        const value: f64 = f64(@bitCast(f32, u32(1092616192)));
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 10.00000\n"));
    }
    // libc differences
    {
        var buf1: [32]u8 = undefined;
        // This is 0.015625 exactly according to gdb. We thus round down,
        // however glibc rounds up for some reason. This occurs for all
        // floats of the form x.yyyy25 on a precision point.
        const value: f64 = f64(@bitCast(f32, u32(1015021568)));
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 0.01563\n"));
    }
    // std-windows-x86_64-Debug-bare test case fails
    {
        // errol3 rounds to ... 630 but libc rounds to ...632. Grisu3
        // also rounds to 630 so I'm inclined to believe libc is not
        // optimal here.
        var buf1: [32]u8 = undefined;
        const value: f64 = f64(@bitCast(f32, u32(1518338049)));
        const result = try bufPrint(buf1[0..], "f64: {.5}\n", value);
        assert(mem.eql(u8, result, "f64: 18014400656965630.00000\n"));
    }
    //custom type format
    {
        const Vec2 = struct {
            const SelfType = @This();
            x: f32,
            y: f32,

            pub fn format(
                self: SelfType,
                comptime fmt: []const u8,
                context: var,
                comptime Errors: type,
                output: fn (@typeOf(context), []const u8) Errors!void,
            ) Errors!void {
                switch (fmt.len) {
                    0 => return std.fmt.format(context, Errors, output, "({.3},{.3})", self.x, self.y),
                    1 => switch (fmt[0]) {
                        //point format
                        'p' => return std.fmt.format(context, Errors, output, "({.3},{.3})", self.x, self.y),
                        //dimension format
                        'd' => return std.fmt.format(context, Errors, output, "{.3}x{.3}", self.x, self.y),
                        else => unreachable,
                    },
                    else => unreachable,
                }
            }
        };

        var buf1: [32]u8 = undefined;
        var value = Vec2{
            .x = 10.2,
            .y = 2.22,
        };
        try testFmt("point: (10.200,2.220)\n", "point: {}\n", &value);
        try testFmt("dim: 10.200x2.220\n", "dim: {d}\n", &value);

        // same thing but not passing a pointer
        try testFmt("point: (10.200,2.220)\n", "point: {}\n", value);
        try testFmt("dim: 10.200x2.220\n", "dim: {d}\n", value);
    }
    //struct format
    {
        const S = struct {
            a: u32,
            b: anyerror,
        };

        const inst = S{
            .a = 456,
            .b = error.Unused,
        };

        try testFmt("S{ .a = 456, .b = error.Unused }", "{}", inst);
    }
    //union format
    {
        const TU = union(enum) {
            float: f32,
            int: u32,
        };

        const UU = union {
            float: f32,
            int: u32,
        };

        const EU = extern union {
            float: f32,
            int: u32,
        };

        const tu_inst = TU{ .int = 123 };
        const uu_inst = UU{ .int = 456 };
        const eu_inst = EU{ .float = 321.123 };

        try testFmt("TU{ .int = 123 }", "{}", tu_inst);

        var buf: [100]u8 = undefined;
        const uu_result = try bufPrint(buf[0..], "{}", uu_inst);
        debug.assert(mem.eql(u8, uu_result[0..3], "UU@"));

        const eu_result = try bufPrint(buf[0..], "{}", eu_inst);
        debug.assert(mem.eql(u8, uu_result[0..3], "EU@"));
    }
    //enum format
    {
        const E = enum {
            One,
            Two,
            Three,
        };

        const inst = E.Two;

        try testFmt("E.Two", "{}", inst);
    }
    //print bytes as hex
    {
        const some_bytes = "\xCA\xFE\xBA\xBE";
        try testFmt("lowercase: cafebabe\n", "lowercase: {x}\n", some_bytes);
        try testFmt("uppercase: CAFEBABE\n", "uppercase: {X}\n", some_bytes);
        //Test Slices
        try testFmt("uppercase: CAFE\n", "uppercase: {X}\n", some_bytes[0..2]);
        try testFmt("lowercase: babe\n", "lowercase: {x}\n", some_bytes[2..]);
        const bytes_with_zeros = "\x00\x0E\xBA\xBE";
        try testFmt("lowercase: 000ebabe\n", "lowercase: {x}\n", bytes_with_zeros);
    }
}

fn testFmt(expected: []const u8, comptime template: []const u8, args: ...) !void {
    var buf: [100]u8 = undefined;
    const result = try bufPrint(buf[0..], template, args);
    if (mem.eql(u8, result, expected)) return;

    std.debug.warn("\n====== expected this output: =========\n");
    std.debug.warn("{}", expected);
    std.debug.warn("\n======== instead found this: =========\n");
    std.debug.warn("{}", result);
    std.debug.warn("\n======================================\n");
    return error.TestFailed;
}

pub fn trim(buf: []const u8) []const u8 {
    var start: usize = 0;
    while (start < buf.len and isWhiteSpace(buf[start])) : (start += 1) {}

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

pub fn hexToBytes(out: []u8, input: []const u8) !void {
    if (out.len * 2 < input.len)
        return error.InvalidLength;

    var in_i: usize = 0;
    while (in_i != input.len) : (in_i += 2) {
        const hi = try charToDigit(input[in_i], 16);
        const lo = try charToDigit(input[in_i + 1], 16);
        out[in_i / 2] = (hi << 4) | lo;
    }
}

test "fmt.hexToBytes" {
    const test_hex_str = "909A312BB12ED1F819B3521AC4C1E896F2160507FFC1C8381E3B07BB16BD1706";
    var pb: [32]u8 = undefined;
    try hexToBytes(pb[0..], test_hex_str);
    try testFmt(test_hex_str, "{X}", pb);
}
