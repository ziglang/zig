const std = @import("std");
const mem = std.mem;

pub const ParseOptions = struct {
    allocator: ?Allocator = null,

    /// Behaviour when a duplicate field is encountered.
    duplicate_field_behavior: enum {
        UseFirst,
        Error,
        UseLast,
    } = .Error,

    /// If false, finding an unknown field returns an error.
    ignore_unknown_fields: bool = false,

    allow_trailing_data: bool = false,
};

const SkipValueError = error{UnexpectedJsonDepth} || TokenStream.Error;

fn skipValue(tokens: *TokenStream) SkipValueError!void {
    const original_depth = tokens.stackUsed();

    // Return an error if no value is found
    _ = try tokens.next();
    if (tokens.stackUsed() < original_depth) return error.UnexpectedJsonDepth;
    if (tokens.stackUsed() == original_depth) return;

    while (try tokens.next()) |_| {
        if (tokens.stackUsed() == original_depth) return;
    }
}

fn ParseInternalError(comptime T: type) type {
    // `inferred_types` is used to avoid infinite recursion for recursive type definitions.
    const inferred_types = [_]type{};
    return ParseInternalErrorImpl(T, &inferred_types);
}

fn ParseInternalErrorImpl(comptime T: type, comptime inferred_types: []const type) type {
    for (inferred_types) |ty| {
        if (T == ty) return error{};
    }

    switch (@typeInfo(T)) {
        .Bool => return error{UnexpectedToken},
        .Float, .ComptimeFloat => return error{UnexpectedToken} || std.fmt.ParseFloatError,
        .Int, .ComptimeInt => {
            return error{ UnexpectedToken, InvalidNumber, Overflow } ||
                std.fmt.ParseIntError || std.fmt.ParseFloatError;
        },
        .Optional => |optionalInfo| {
            return ParseInternalErrorImpl(optionalInfo.child, inferred_types ++ [_]type{T});
        },
        .Enum => return error{ UnexpectedToken, InvalidEnumTag } || std.fmt.ParseIntError ||
            std.meta.IntToEnumError || std.meta.IntToEnumError,
        .Union => |unionInfo| {
            if (unionInfo.tag_type) |_| {
                var errors = error{
                    ConflictingUnionFields,
                    UnknownField,
                    UnexpectedToken,
                    MissingField,
                } || TokenStream.Error;
                for (unionInfo.fields) |u_field| {
                    errors = errors || ParseInternalErrorImpl(u_field.type, inferred_types ++ [_]type{T});
                }
                return errors;
            } else {
                @compileError("Unable to parse into untagged union '" ++ @typeName(T) ++ "'");
            }
        },
        .Struct => |structInfo| {
            var errors = error{
                DuplicateJSONField,
                UnexpectedEndOfJson,
                UnexpectedToken,
                UnexpectedValue,
                UnknownField,
                MissingField,
            } || SkipValueError || TokenStream.Error;
            for (structInfo.fields) |field| {
                errors = errors || ParseInternalErrorImpl(field.type, inferred_types ++ [_]type{T});
            }
            return errors;
        },
        .Array => |arrayInfo| {
            return error{ UnexpectedEndOfJson, UnexpectedToken, LengthMismatch } || TokenStream.Error ||
                UnescapeValidStringError ||
                ParseInternalErrorImpl(arrayInfo.child, inferred_types ++ [_]type{T});
        },
        .Pointer => |ptrInfo| {
            var errors = error{AllocatorRequired} || std.mem.Allocator.Error;
            switch (ptrInfo.size) {
                .One => {
                    return errors || ParseInternalErrorImpl(ptrInfo.child, inferred_types ++ [_]type{T});
                },
                .Slice => {
                    return errors || error{ UnexpectedEndOfJson, UnexpectedToken } ||
                        ParseInternalErrorImpl(ptrInfo.child, inferred_types ++ [_]type{T}) ||
                        UnescapeValidStringError || TokenStream.Error;
                },
                else => @compileError("Unable to parse into type '" ++ @typeName(T) ++ "'"),
            }
        },
        else => return error{},
    }
    unreachable;
}

fn parseInternal(
    comptime T: type,
    token: Token,
    tokens: *TokenStream,
    options: ParseOptions,
) ParseInternalError(T)!T {
    switch (@typeInfo(T)) {
        .Bool => {
            return switch (token) {
                .True => true,
                .False => false,
                else => error.UnexpectedToken,
            };
        },
        .Float, .ComptimeFloat => {
            switch (token) {
                .Number => |numberToken| return try std.fmt.parseFloat(T, numberToken.slice(tokens.slice, tokens.i - 1)),
                .String => |stringToken| return try std.fmt.parseFloat(T, stringToken.slice(tokens.slice, tokens.i - 1)),
                else => return error.UnexpectedToken,
            }
        },
        .Int, .ComptimeInt => {
            switch (token) {
                .Number => |numberToken| {
                    if (numberToken.is_integer)
                        return try std.fmt.parseInt(T, numberToken.slice(tokens.slice, tokens.i - 1), 10);
                    const float = try std.fmt.parseFloat(f128, numberToken.slice(tokens.slice, tokens.i - 1));
                    if (@round(float) != float) return error.InvalidNumber;
                    if (float > std.math.maxInt(T) or float < std.math.minInt(T)) return error.Overflow;
                    return @floatToInt(T, float);
                },
                .String => |stringToken| {
                    return std.fmt.parseInt(T, stringToken.slice(tokens.slice, tokens.i - 1), 10) catch |err| {
                        switch (err) {
                            error.Overflow => return err,
                            error.InvalidCharacter => {
                                const float = try std.fmt.parseFloat(f128, stringToken.slice(tokens.slice, tokens.i - 1));
                                if (@round(float) != float) return error.InvalidNumber;
                                if (float > std.math.maxInt(T) or float < std.math.minInt(T)) return error.Overflow;
                                return @floatToInt(T, float);
                            },
                        }
                    };
                },
                else => return error.UnexpectedToken,
            }
        },
        .Optional => |optionalInfo| {
            if (token == .Null) {
                return null;
            } else {
                return try parseInternal(optionalInfo.child, token, tokens, options);
            }
        },
        .Enum => |enumInfo| {
            switch (token) {
                .Number => |numberToken| {
                    if (!numberToken.is_integer) return error.UnexpectedToken;
                    const n = try std.fmt.parseInt(enumInfo.tag_type, numberToken.slice(tokens.slice, tokens.i - 1), 10);
                    return try std.meta.intToEnum(T, n);
                },
                .String => |stringToken| {
                    const source_slice = stringToken.slice(tokens.slice, tokens.i - 1);
                    switch (stringToken.escapes) {
                        .None => return std.meta.stringToEnum(T, source_slice) orelse return error.InvalidEnumTag,
                        .Some => {
                            inline for (enumInfo.fields) |field| {
                                if (field.name.len == stringToken.decodedLength() and encodesTo(field.name, source_slice)) {
                                    return @field(T, field.name);
                                }
                            }
                            return error.InvalidEnumTag;
                        },
                    }
                },
                else => return error.UnexpectedToken,
            }
        },
        .Union => |unionInfo| {
            const UnionTagType = unionInfo.tag_type orelse @compileError("Unable to parse into untagged union '" ++ @typeName(T) ++ "'");
            switch (token) {
                .ObjectBegin => {},
                else => return error.UnexpectedToken,
            }

            var r: T = undefined;
            var seen_any_value = false;
            errdefer {
                if (seen_any_value) {
                    inline for (unionInfo.fields) |u_field| {
                        if (r == @field(UnionTagType, u_field.name)) {
                            parseFree(u_field.type, @field(r, u_field.name), options);
                        }
                    }
                }
            }
            while (true) {
                switch ((try tokens.next()) orelse return error.UnexpectedEndOfJson) {
                    .ObjectEnd => break,
                    .String => |stringToken| {
                        if (seen_any_value) return error.ConflictingUnionFields;
                        const key_source_slice = stringToken.slice(tokens.slice, tokens.i - 1);
                        var child_options = options;
                        child_options.allow_trailing_data = true;
                        inline for (unionInfo.fields) |u_field| {
                            if (switch (stringToken.escapes) {
                                .None => mem.eql(u8, u_field.name, key_source_slice),
                                .Some => (u_field.name.len == stringToken.decodedLength() and encodesTo(u_field.name, key_source_slice)),
                            }) {
                                if (u_field.type == void) {
                                    // void isn't really a json type, but we can support void payload union tags with {} as a value.
                                    if (.ObjectBegin != (try tokens.next()) orelse return error.UnexpectedEndOfJson) return error.UnexpectedToken;
                                    if (.ObjectEnd != (try tokens.next()) orelse return error.UnexpectedEndOfJson) return error.UnexpectedToken;
                                    r = @unionInit(T, u_field.name, {});
                                } else {
                                    r = @unionInit(T, u_field.name, try parse(u_field.type, tokens, child_options));
                                }
                                seen_any_value = true;
                                break;
                            }
                        } else {
                            // Didn't match anything.
                            return error.UnknownField;
                        }
                    },
                    else => return error.UnexpectedToken,
                }
            }
            if (!seen_any_value) return error.MissingField;
            return r;
        },
        .Struct => |structInfo| {
            if (structInfo.is_tuple) {
                switch (token) {
                    .ArrayBegin => {},
                    else => return error.UnexpectedToken,
                }
                var r: T = undefined;
                var child_options = options;
                child_options.allow_trailing_data = true;
                var fields_seen: usize = 0;
                errdefer {
                    inline for (0..structInfo.fields.len) |i| {
                        if (i < fields_seen) {
                            parseFree(structInfo.fields[i].type, r[i], options);
                        }
                    }
                }
                inline for (0..structInfo.fields.len) |i| {
                    r[i] = try parse(structInfo.fields[i].type, tokens, child_options);
                    fields_seen = i + 1;
                }
                const tok = (try tokens.next()) orelse return error.UnexpectedEndOfJson;
                switch (tok) {
                    .ArrayEnd => {},
                    else => return error.UnexpectedToken,
                }
                return r;
            }

            switch (token) {
                .ObjectBegin => {},
                else => return error.UnexpectedToken,
            }
            var r: T = undefined;
            var fields_seen = [_]bool{false} ** structInfo.fields.len;
            errdefer {
                inline for (structInfo.fields, 0..) |field, i| {
                    if (fields_seen[i]) {
                        parseFree(field.type, @field(r, field.name), options);
                    }
                }
            }

            while (true) {
                switch ((try tokens.next()) orelse return error.UnexpectedEndOfJson) {
                    .ObjectEnd => break,
                    .String => |stringToken| {
                        const key_source_slice = stringToken.slice(tokens.slice, tokens.i - 1);
                        var child_options = options;
                        child_options.allow_trailing_data = true;
                        var found = false;
                        inline for (structInfo.fields, 0..) |field, i| {
                            if (field.is_comptime) @compileError("comptime fields are not supported: " ++ @typeName(T) ++ "." ++ field.name);
                            if (switch (stringToken.escapes) {
                                .None => mem.eql(u8, field.name, key_source_slice),
                                .Some => (field.name.len == stringToken.decodedLength() and encodesTo(field.name, key_source_slice)),
                            }) {
                                if (fields_seen[i]) {
                                    switch (options.duplicate_field_behavior) {
                                        .UseFirst => {
                                            // unconditonally ignore value. for comptime fields, this skips check against default_value
                                            parseFree(field.type, try parse(field.type, tokens, child_options), child_options);
                                            found = true;
                                            break;
                                        },
                                        .Error => return error.DuplicateJSONField,
                                        .UseLast => {
                                            parseFree(field.type, @field(r, field.name), child_options);
                                            fields_seen[i] = false;
                                        },
                                    }
                                }
                                @field(r, field.name) = try parse(field.type, tokens, child_options);
                                fields_seen[i] = true;
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            if (options.ignore_unknown_fields) {
                                try skipValue(tokens);
                                continue;
                            } else {
                                return error.UnknownField;
                            }
                        }
                    },
                    else => return error.UnexpectedToken,
                }
            }
            inline for (structInfo.fields, 0..) |field, i| {
                if (!fields_seen[i]) {
                    if (field.default_value) |default_ptr| {
                        const default = @ptrCast(*align(1) const field.type, default_ptr).*;
                        @field(r, field.name) = default;
                    } else {
                        return error.MissingField;
                    }
                }
            }
            return r;
        },
        .Array => |arrayInfo| {
            switch (token) {
                .ArrayBegin => {
                    var r: T = undefined;
                    var i: usize = 0;
                    var child_options = options;
                    child_options.allow_trailing_data = true;
                    errdefer {
                        // Without the r.len check `r[i]` is not allowed
                        if (r.len > 0) while (true) : (i -= 1) {
                            parseFree(arrayInfo.child, r[i], options);
                            if (i == 0) break;
                        };
                    }
                    while (i < r.len) : (i += 1) {
                        r[i] = try parse(arrayInfo.child, tokens, child_options);
                    }
                    const tok = (try tokens.next()) orelse return error.UnexpectedEndOfJson;
                    switch (tok) {
                        .ArrayEnd => {},
                        else => return error.UnexpectedToken,
                    }
                    return r;
                },
                .String => |stringToken| {
                    if (arrayInfo.child != u8) return error.UnexpectedToken;
                    var r: T = undefined;
                    const source_slice = stringToken.slice(tokens.slice, tokens.i - 1);
                    if (r.len != stringToken.decodedLength()) return error.LengthMismatch;
                    switch (stringToken.escapes) {
                        .None => mem.copy(u8, &r, source_slice),
                        .Some => try unescapeValidString(&r, source_slice),
                    }
                    return r;
                },
                else => return error.UnexpectedToken,
            }
        },
        .Pointer => |ptrInfo| {
            const allocator = options.allocator orelse return error.AllocatorRequired;
            switch (ptrInfo.size) {
                .One => {
                    const r: *ptrInfo.child = try allocator.create(ptrInfo.child);
                    errdefer allocator.destroy(r);
                    r.* = try parseInternal(ptrInfo.child, token, tokens, options);
                    return r;
                },
                .Slice => {
                    switch (token) {
                        .ArrayBegin => {
                            var arraylist = std.ArrayList(ptrInfo.child).init(allocator);
                            errdefer {
                                while (arraylist.popOrNull()) |v| {
                                    parseFree(ptrInfo.child, v, options);
                                }
                                arraylist.deinit();
                            }

                            while (true) {
                                const tok = (try tokens.next()) orelse return error.UnexpectedEndOfJson;
                                switch (tok) {
                                    .ArrayEnd => break,
                                    else => {},
                                }

                                try arraylist.ensureUnusedCapacity(1);
                                const v = try parseInternal(ptrInfo.child, tok, tokens, options);
                                arraylist.appendAssumeCapacity(v);
                            }

                            if (ptrInfo.sentinel) |some| {
                                const sentinel_value = @ptrCast(*align(1) const ptrInfo.child, some).*;
                                return try arraylist.toOwnedSliceSentinel(sentinel_value);
                            }

                            return try arraylist.toOwnedSlice();
                        },
                        .String => |stringToken| {
                            if (ptrInfo.child != u8) return error.UnexpectedToken;
                            const source_slice = stringToken.slice(tokens.slice, tokens.i - 1);
                            const len = stringToken.decodedLength();
                            const output = if (ptrInfo.sentinel) |sentinel_ptr|
                                try allocator.allocSentinel(u8, len, @ptrCast(*const u8, sentinel_ptr).*)
                            else
                                try allocator.alloc(u8, len);
                            errdefer allocator.free(output);
                            switch (stringToken.escapes) {
                                .None => mem.copy(u8, output, source_slice),
                                .Some => try unescapeValidString(output, source_slice),
                            }

                            return output;
                        },
                        else => return error.UnexpectedToken,
                    }
                },
                else => @compileError("Unable to parse into type '" ++ @typeName(T) ++ "'"),
            }
        },
        else => @compileError("Unable to parse into type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

pub fn ParseError(comptime T: type) type {
    return ParseInternalError(T) || error{UnexpectedEndOfJson} || TokenStream.Error;
}

pub fn parse(comptime T: type, tokens: *TokenStream, options: ParseOptions) ParseError(T)!T {
    const token = (try tokens.next()) orelse return error.UnexpectedEndOfJson;
    const r = try parseInternal(T, token, tokens, options);
    errdefer parseFree(T, r, options);
    if (!options.allow_trailing_data) {
        if ((try tokens.next()) != null) unreachable;
        assert(tokens.i >= tokens.slice.len);
    }
    return r;
}

/// Releases resources created by `parse`.
/// Should be called with the same type and `ParseOptions` that were passed to `parse`
pub fn parseFree(comptime T: type, value: T, options: ParseOptions) void {
    switch (@typeInfo(T)) {
        .Bool, .Float, .ComptimeFloat, .Int, .ComptimeInt, .Enum => {},
        .Optional => {
            if (value) |v| {
                return parseFree(@TypeOf(v), v, options);
            }
        },
        .Union => |unionInfo| {
            if (unionInfo.tag_type) |UnionTagType| {
                inline for (unionInfo.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        parseFree(u_field.type, @field(value, u_field.name), options);
                        break;
                    }
                }
            } else {
                unreachable;
            }
        },
        .Struct => |structInfo| {
            inline for (structInfo.fields) |field| {
                var should_free = true;
                if (field.default_value) |default| {
                    switch (@typeInfo(field.type)) {
                        // We must not attempt to free pointers to struct default values
                        .Pointer => |fieldPtrInfo| {
                            const field_value = @field(value, field.name);
                            const field_ptr = switch (fieldPtrInfo.size) {
                                .One => field_value,
                                .Slice => field_value.ptr,
                                else => unreachable, // Other pointer types are not parseable
                            };
                            const field_addr = @ptrToInt(field_ptr);

                            const casted_default = @ptrCast(*const field.type, @alignCast(@alignOf(field.type), default)).*;
                            const default_ptr = switch (fieldPtrInfo.size) {
                                .One => casted_default,
                                .Slice => casted_default.ptr,
                                else => unreachable, // Other pointer types are not parseable
                            };
                            const default_addr = @ptrToInt(default_ptr);

                            if (field_addr == default_addr) {
                                should_free = false;
                            }
                        },
                        else => {},
                    }
                }
                if (should_free) {
                    parseFree(field.type, @field(value, field.name), options);
                }
            }
        },
        .Array => |arrayInfo| {
            for (value) |v| {
                parseFree(arrayInfo.child, v, options);
            }
        },
        .Pointer => |ptrInfo| {
            const allocator = options.allocator orelse unreachable;
            switch (ptrInfo.size) {
                .One => {
                    parseFree(ptrInfo.child, value.*, options);
                    allocator.destroy(value);
                },
                .Slice => {
                    for (value) |v| {
                        parseFree(ptrInfo.child, v, options);
                    }
                    allocator.free(value);
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

pub const UnescapeValidStringError = error{InvalidUnicodeHexSymbol};

/// Unescape a JSON string
/// Only to be used on strings already validated by the parser
/// (note the unreachable statements and lack of bounds checking)
pub fn unescapeValidString(output: []u8, input: []const u8) UnescapeValidStringError!void {
    var inIndex: usize = 0;
    var outIndex: usize = 0;

    while (inIndex < input.len) {
        if (input[inIndex] != '\\') {
            // not an escape sequence
            output[outIndex] = input[inIndex];
            inIndex += 1;
            outIndex += 1;
        } else if (input[inIndex + 1] != 'u') {
            // a simple escape sequence
            output[outIndex] = @as(u8, switch (input[inIndex + 1]) {
                '\\' => '\\',
                '/' => '/',
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                'f' => 12,
                'b' => 8,
                '"' => '"',
                else => unreachable,
            });
            inIndex += 2;
            outIndex += 1;
        } else {
            // a unicode escape sequence
            const firstCodeUnit = std.fmt.parseInt(u16, input[inIndex + 2 .. inIndex + 6], 16) catch unreachable;

            // guess optimistically that it's not a surrogate pair
            if (std.unicode.utf8Encode(firstCodeUnit, output[outIndex..])) |byteCount| {
                outIndex += byteCount;
                inIndex += 6;
            } else |err| {
                // it might be a surrogate pair
                if (err != error.Utf8CannotEncodeSurrogateHalf) {
                    return error.InvalidUnicodeHexSymbol;
                }
                // check if a second code unit is present
                if (inIndex + 7 >= input.len or input[inIndex + 6] != '\\' or input[inIndex + 7] != 'u') {
                    return error.InvalidUnicodeHexSymbol;
                }

                const secondCodeUnit = std.fmt.parseInt(u16, input[inIndex + 8 .. inIndex + 12], 16) catch unreachable;

                const utf16le_seq = [2]u16{
                    mem.nativeToLittle(u16, firstCodeUnit),
                    mem.nativeToLittle(u16, secondCodeUnit),
                };
                if (std.unicode.utf16leToUtf8(output[outIndex..], &utf16le_seq)) |byteCount| {
                    outIndex += byteCount;
                    inIndex += 12;
                } else |_| {
                    return error.InvalidUnicodeHexSymbol;
                }
            }
        }
    }
    assert(outIndex == output.len);
}

test "skipValue" {
    var ts = TokenStream.init("false");
    try skipValue(&ts);
    ts = TokenStream.init("true");
    try skipValue(&ts);
    ts = TokenStream.init("null");
    try skipValue(&ts);
    ts = TokenStream.init("42");
    try skipValue(&ts);
    ts = TokenStream.init("42.0");
    try skipValue(&ts);
    ts = TokenStream.init("\"foo\"");
    try skipValue(&ts);
    ts = TokenStream.init("[101, 111, 121]");
    try skipValue(&ts);
    ts = TokenStream.init("{}");
    try skipValue(&ts);
    ts = TokenStream.init("{\"foo\": \"bar\"}");
    try skipValue(&ts);

    { // An absurd number of nestings
        const nestings = StreamingParser.default_max_nestings + 1;

        ts = TokenStream.init("[" ** nestings ++ "]" ** nestings);
        try testing.expectError(error.TooManyNestedItems, skipValue(&ts));
    }

    { // Would a number token cause problems in a deeply-nested array?
        const nestings = StreamingParser.default_max_nestings;
        const deeply_nested_array = "[" ** nestings ++ "0.118, 999, 881.99, 911.9, 725, 3" ++ "]" ** nestings;

        ts = TokenStream.init(deeply_nested_array);
        try skipValue(&ts);

        ts = TokenStream.init("[" ++ deeply_nested_array ++ "]");
        try testing.expectError(error.TooManyNestedItems, skipValue(&ts));
    }

    // Mismatched brace/square bracket
    ts = TokenStream.init("[102, 111, 111}");
    try testing.expectError(error.UnexpectedClosingBrace, skipValue(&ts));

    { // should fail if no value found (e.g. immediate close of object)
        var empty_object = TokenStream.init("{}");
        assert(.ObjectBegin == (try empty_object.next()).?);
        try testing.expectError(error.UnexpectedJsonDepth, skipValue(&empty_object));

        var empty_array = TokenStream.init("[]");
        assert(.ArrayBegin == (try empty_array.next()).?);
        try testing.expectError(error.UnexpectedJsonDepth, skipValue(&empty_array));
    }
}

test "deserializing string with escape sequence into sentinel slice" {
    const json = "\"\\n\"";
    var token_stream = TokenStream.init(json);
    const options = ParseOptions{ .allocator = std.testing.allocator };

    // Pre-fix, this line would panic:
    const result = try parse([:0]const u8, &token_stream, options);
    defer parseFree([:0]const u8, result, options);

    // Double-check that we're getting the right result
    try testing.expect(mem.eql(u8, result, "\n"));
}

test "parse" {
    var ts = TokenStream.init("false");
    try testing.expectEqual(false, try parse(bool, &ts, ParseOptions{}));
    ts = TokenStream.init("true");
    try testing.expectEqual(true, try parse(bool, &ts, ParseOptions{}));
    ts = TokenStream.init("1");
    try testing.expectEqual(@as(u1, 1), try parse(u1, &ts, ParseOptions{}));
    ts = TokenStream.init("50");
    try testing.expectError(error.Overflow, parse(u1, &ts, ParseOptions{}));
    ts = TokenStream.init("42");
    try testing.expectEqual(@as(u64, 42), try parse(u64, &ts, ParseOptions{}));
    ts = TokenStream.init("42.0");
    try testing.expectEqual(@as(f64, 42), try parse(f64, &ts, ParseOptions{}));
    ts = TokenStream.init("null");
    try testing.expectEqual(@as(?bool, null), try parse(?bool, &ts, ParseOptions{}));
    ts = TokenStream.init("true");
    try testing.expectEqual(@as(?bool, true), try parse(?bool, &ts, ParseOptions{}));

    ts = TokenStream.init("\"foo\"");
    try testing.expectEqual(@as([3]u8, "foo".*), try parse([3]u8, &ts, ParseOptions{}));
    ts = TokenStream.init("[102, 111, 111]");
    try testing.expectEqual(@as([3]u8, "foo".*), try parse([3]u8, &ts, ParseOptions{}));
    ts = TokenStream.init("[]");
    try testing.expectEqual(@as([0]u8, undefined), try parse([0]u8, &ts, ParseOptions{}));

    ts = TokenStream.init("\"12345678901234567890\"");
    try testing.expectEqual(@as(u64, 12345678901234567890), try parse(u64, &ts, ParseOptions{}));
    ts = TokenStream.init("\"123.456\"");
    try testing.expectEqual(@as(f64, 123.456), try parse(f64, &ts, ParseOptions{}));
}

test "parse into enum" {
    const T = enum(u32) {
        Foo = 42,
        Bar,
        @"with\\escape",
    };
    var ts = TokenStream.init("\"Foo\"");
    try testing.expectEqual(@as(T, .Foo), try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("42");
    try testing.expectEqual(@as(T, .Foo), try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("\"with\\\\escape\"");
    try testing.expectEqual(@as(T, .@"with\\escape"), try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("5");
    try testing.expectError(error.InvalidEnumTag, parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("\"Qux\"");
    try testing.expectError(error.InvalidEnumTag, parse(T, &ts, ParseOptions{}));
}

test "parse with trailing data" {
    var ts = TokenStream.init("falsed");
    try testing.expectEqual(false, try parse(bool, &ts, ParseOptions{ .allow_trailing_data = true }));
    ts = TokenStream.init("falsed");
    try testing.expectError(error.InvalidTopLevelTrailing, parse(bool, &ts, ParseOptions{ .allow_trailing_data = false }));
    // trailing whitespace is okay
    ts = TokenStream.init("false \n");
    try testing.expectEqual(false, try parse(bool, &ts, ParseOptions{ .allow_trailing_data = false }));
}

test "parse into that allocates a slice" {
    var ts = TokenStream.init("\"foo\"");
    try testing.expectError(error.AllocatorRequired, parse([]u8, &ts, ParseOptions{}));

    const options = ParseOptions{ .allocator = testing.allocator };
    {
        ts = TokenStream.init("\"foo\"");
        const r = try parse([]u8, &ts, options);
        defer parseFree([]u8, r, options);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        ts = TokenStream.init("[102, 111, 111]");
        const r = try parse([]u8, &ts, options);
        defer parseFree([]u8, r, options);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        ts = TokenStream.init("\"with\\\\escape\"");
        const r = try parse([]u8, &ts, options);
        defer parseFree([]u8, r, options);
        try testing.expectEqualSlices(u8, "with\\escape", r);
    }
}

test "parse into tagged union" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    var ts = TokenStream.init("{\"float\":1.5}");
    try testing.expectEqual(T{ .float = 1.5 }, try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("{\"int\":1}");
    try testing.expectEqual(T{ .int = 1 }, try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("{\"nothing\":{}}");
    try testing.expectEqual(T{ .nothing = {} }, try parse(T, &ts, ParseOptions{}));
}

test "parse into tagged union errors" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    var ts = TokenStream.init("42");
    try testing.expectError(error.UnexpectedToken, parse(T, &ts, ParseOptions{}));

    ts = TokenStream.init("{}");
    try testing.expectError(error.MissingField, parse(T, &ts, ParseOptions{}));

    ts = TokenStream.init("{\"bogus\":1}");
    try testing.expectError(error.UnknownField, parse(T, &ts, ParseOptions{}));

    ts = TokenStream.init("{\"int\":1, \"int\":1}");
    try testing.expectError(error.ConflictingUnionFields, parse(T, &ts, ParseOptions{}));

    ts = TokenStream.init("{\"int\":1, \"float\":1.0}");
    try testing.expectError(error.ConflictingUnionFields, parse(T, &ts, ParseOptions{}));

    ts = TokenStream.init("{\"string\":\"foo\"}");
    try testing.expectError(error.AllocatorRequired, parse(T, &ts, ParseOptions{}));

    ts = TokenStream.init("{\"nothing\":null}");
    try testing.expectError(error.UnexpectedToken, parse(T, &ts, ParseOptions{}));

    ts = TokenStream.init("{\"nothing\":{\"no\":0}}");
    try testing.expectError(error.UnexpectedToken, parse(T, &ts, ParseOptions{}));
}

test "parseFree descends into tagged union" {
    var fail_alloc = testing.FailingAllocator.init(testing.allocator, 1);
    const options = ParseOptions{ .allocator = fail_alloc.allocator() };
    const T = union(enum) {
        int: i32,
        float: f64,
        string: []const u8,
    };
    // use a string with unicode escape so we know result can't be a reference to global constant
    var ts = TokenStream.init("{\"string\":\"with\\u0105unicode\"}");
    const r = try parse(T, &ts, options);
    try testing.expectEqual(std.meta.Tag(T).string, @as(std.meta.Tag(T), r));
    try testing.expectEqualSlices(u8, "withąunicode", r.string);
    try testing.expectEqual(@as(usize, 0), fail_alloc.deallocations);
    parseFree(T, r, options);
    try testing.expectEqual(@as(usize, 1), fail_alloc.deallocations);
}

test "parse into struct with no fields" {
    const T = struct {};
    var ts = TokenStream.init("{}");
    try testing.expectEqual(T{}, try parse(T, &ts, ParseOptions{}));
}

const test_const_value: usize = 123;

test "parse into struct with default const pointer field" {
    const T = struct { a: *const usize = &test_const_value };
    var ts = TokenStream.init("{}");
    try testing.expectEqual(T{}, try parse(T, &ts, .{}));
}

const test_default_usize: usize = 123;
const test_default_usize_ptr: *align(1) const usize = &test_default_usize;
const test_default_str: []const u8 = "test str";
const test_default_str_slice: [2][]const u8 = [_][]const u8{
    "test1",
    "test2",
};

test "freeing parsed structs with pointers to default values" {
    const T = struct {
        int: *const usize = &test_default_usize,
        int_ptr: *allowzero align(1) const usize = test_default_usize_ptr,
        str: []const u8 = test_default_str,
        str_slice: []const []const u8 = &test_default_str_slice,
    };

    var ts = json.TokenStream.init("{}");
    const options = .{ .allocator = std.heap.page_allocator };
    const parsed = try json.parse(T, &ts, options);

    try testing.expectEqual(T{}, parsed);

    json.parseFree(T, parsed, options);
}

test "parse into struct where destination and source lengths mismatch" {
    const T = struct { a: [2]u8 };
    var ts = TokenStream.init("{\"a\": \"bbb\"}");
    try testing.expectError(error.LengthMismatch, parse(T, &ts, ParseOptions{}));
}

test "parse into struct with misc fields" {
    @setEvalBranchQuota(10000);
    const options = ParseOptions{ .allocator = testing.allocator };
    const T = struct {
        int: i64,
        float: f64,
        @"with\\escape": bool,
        @"withąunicode😂": bool,
        language: []const u8,
        optional: ?bool,
        default_field: i32 = 42,
        static_array: [3]f64,
        dynamic_array: []f64,

        complex: struct {
            nested: []const u8,
        },

        veryComplex: []struct {
            foo: []const u8,
        },

        a_union: Union,
        const Union = union(enum) {
            x: u8,
            float: f64,
            string: []const u8,
        };
    };
    var ts = TokenStream.init(
        \\{
        \\  "int": 420,
        \\  "float": 3.14,
        \\  "with\\escape": true,
        \\  "with\u0105unicode\ud83d\ude02": false,
        \\  "language": "zig",
        \\  "optional": null,
        \\  "static_array": [66.6, 420.420, 69.69],
        \\  "dynamic_array": [66.6, 420.420, 69.69],
        \\  "complex": {
        \\    "nested": "zig"
        \\  },
        \\  "veryComplex": [
        \\    {
        \\      "foo": "zig"
        \\    }, {
        \\      "foo": "rocks"
        \\    }
        \\  ],
        \\  "a_union": {
        \\    "float": 100000
        \\  }
        \\}
    );
    const r = try parse(T, &ts, options);
    defer parseFree(T, r, options);
    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectEqual(@as(f64, 3.14), r.float);
    try testing.expectEqual(true, r.@"with\\escape");
    try testing.expectEqual(false, r.@"withąunicode😂");
    try testing.expectEqualSlices(u8, "zig", r.language);
    try testing.expectEqual(@as(?bool, null), r.optional);
    try testing.expectEqual(@as(i32, 42), r.default_field);
    try testing.expectEqual(@as(f64, 66.6), r.static_array[0]);
    try testing.expectEqual(@as(f64, 420.420), r.static_array[1]);
    try testing.expectEqual(@as(f64, 69.69), r.static_array[2]);
    try testing.expectEqual(@as(usize, 3), r.dynamic_array.len);
    try testing.expectEqual(@as(f64, 66.6), r.dynamic_array[0]);
    try testing.expectEqual(@as(f64, 420.420), r.dynamic_array[1]);
    try testing.expectEqual(@as(f64, 69.69), r.dynamic_array[2]);
    try testing.expectEqualSlices(u8, r.complex.nested, "zig");
    try testing.expectEqualSlices(u8, "zig", r.veryComplex[0].foo);
    try testing.expectEqualSlices(u8, "rocks", r.veryComplex[1].foo);
    try testing.expectEqual(T.Union{ .float = 100000 }, r.a_union);
}

test "parse into struct with strings and arrays with sentinels" {
    @setEvalBranchQuota(10000);
    const options = ParseOptions{ .allocator = testing.allocator };
    const T = struct {
        language: [:0]const u8,
        language_without_sentinel: []const u8,
        data: [:99]const i32,
        simple_data: []const i32,
    };
    var ts = TokenStream.init(
        \\{
        \\  "language": "zig",
        \\  "language_without_sentinel": "zig again!",
        \\  "data": [1, 2, 3],
        \\  "simple_data": [4, 5, 6]
        \\}
    );
    const r = try parse(T, &ts, options);
    defer parseFree(T, r, options);

    try testing.expectEqualSentinel(u8, 0, "zig", r.language);

    const data = [_:99]i32{ 1, 2, 3 };
    try testing.expectEqualSentinel(i32, 99, data[0..data.len], r.data);

    // Make sure that arrays who aren't supposed to have a sentinel still parse without one.
    try testing.expectEqual(@as(?i32, null), std.meta.sentinel(@TypeOf(r.simple_data)));
    try testing.expectEqual(@as(?u8, null), std.meta.sentinel(@TypeOf(r.language_without_sentinel)));
}

test "parse into struct with duplicate field" {
    // allow allocator to detect double frees by keeping bucket in use
    const ballast = try testing.allocator.alloc(u64, 1);
    defer testing.allocator.free(ballast);

    const options_first = ParseOptions{ .allocator = testing.allocator, .duplicate_field_behavior = .UseFirst };

    const options_last = ParseOptions{
        .allocator = testing.allocator,
        .duplicate_field_behavior = .UseLast,
    };

    const str = "{ \"a\": 1, \"a\": 0.25 }";

    const T1 = struct { a: *u64 };
    // both .UseFirst and .UseLast should fail because second "a" value isn't a u64
    var ts = TokenStream.init(str);
    try testing.expectError(error.InvalidNumber, parse(T1, &ts, options_first));
    ts = TokenStream.init(str);
    try testing.expectError(error.InvalidNumber, parse(T1, &ts, options_last));

    const T2 = struct { a: f64 };
    ts = TokenStream.init(str);
    try testing.expectEqual(T2{ .a = 1.0 }, try parse(T2, &ts, options_first));
    ts = TokenStream.init(str);
    try testing.expectEqual(T2{ .a = 0.25 }, try parse(T2, &ts, options_last));
}

test "parse into struct ignoring unknown fields" {
    const T = struct {
        int: i64,
        language: []const u8,
    };

    const ops = ParseOptions{
        .allocator = testing.allocator,
        .ignore_unknown_fields = true,
    };

    var ts = TokenStream.init(
        \\{
        \\  "int": 420,
        \\  "float": 3.14,
        \\  "with\\escape": true,
        \\  "with\u0105unicode\ud83d\ude02": false,
        \\  "optional": null,
        \\  "static_array": [66.6, 420.420, 69.69],
        \\  "dynamic_array": [66.6, 420.420, 69.69],
        \\  "complex": {
        \\    "nested": "zig"
        \\  },
        \\  "veryComplex": [
        \\    {
        \\      "foo": "zig"
        \\    }, {
        \\      "foo": "rocks"
        \\    }
        \\  ],
        \\  "a_union": 100000,
        \\  "language": "zig"
        \\}
    );
    const r = try parse(T, &ts, ops);
    defer parseFree(T, r, ops);

    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectEqualSlices(u8, "zig", r.language);
}

test "parse into tuple" {
    const options = ParseOptions{ .allocator = testing.allocator };
    const Union = union(enum) {
        char: u8,
        float: f64,
        string: []const u8,
    };
    const T = std.meta.Tuple(&.{
        i64,
        f64,
        bool,
        []const u8,
        ?bool,
        struct {
            foo: i32,
            bar: []const u8,
        },
        std.meta.Tuple(&.{ u8, []const u8, u8 }),
        Union,
    });
    var ts = TokenStream.init(
        \\[
        \\  420,
        \\  3.14,
        \\  true,
        \\  "zig",
        \\  null,
        \\  {
        \\    "foo": 1,
        \\    "bar": "zero"
        \\  },
        \\  [4, "två", 42],
        \\  {"float": 12.34}
        \\]
    );
    const r = try parse(T, &ts, options);
    defer parseFree(T, r, options);
    try testing.expectEqual(@as(i64, 420), r[0]);
    try testing.expectEqual(@as(f64, 3.14), r[1]);
    try testing.expectEqual(true, r[2]);
    try testing.expectEqualSlices(u8, "zig", r[3]);
    try testing.expectEqual(@as(?bool, null), r[4]);
    try testing.expectEqual(@as(i32, 1), r[5].foo);
    try testing.expectEqualSlices(u8, "zero", r[5].bar);
    try testing.expectEqual(@as(u8, 4), r[6][0]);
    try testing.expectEqualSlices(u8, "två", r[6][1]);
    try testing.expectEqual(@as(u8, 42), r[6][2]);
    try testing.expectEqual(Union{ .float = 12.34 }, r[7]);
}

const ParseIntoRecursiveUnionDefinitionValue = union(enum) {
    integer: i64,
    array: []const ParseIntoRecursiveUnionDefinitionValue,
};

test "parse into recursive union definition" {
    const T = struct {
        values: ParseIntoRecursiveUnionDefinitionValue,
    };
    const ops = ParseOptions{ .allocator = testing.allocator };

    var ts = TokenStream.init("{\"values\":{\"array\":[{\"integer\":58}]}}");
    const r = try parse(T, &ts, ops);
    defer parseFree(T, r, ops);

    try testing.expectEqual(@as(i64, 58), r.values.array[0].integer);
}

const ParseIntoDoubleRecursiveUnionValueFirst = union(enum) {
    integer: i64,
    array: []const ParseIntoDoubleRecursiveUnionValueSecond,
};

const ParseIntoDoubleRecursiveUnionValueSecond = union(enum) {
    boolean: bool,
    array: []const ParseIntoDoubleRecursiveUnionValueFirst,
};

test "parse into double recursive union definition" {
    const T = struct {
        values: ParseIntoDoubleRecursiveUnionValueFirst,
    };
    const ops = ParseOptions{ .allocator = testing.allocator };

    var ts = TokenStream.init("{\"values\":{\"array\":[{\"array\":[{\"integer\":58}]}]}}");
    const r = try parse(T, &ts, ops);
    defer parseFree(T, r, ops);

    try testing.expectEqual(@as(i64, 58), r.values.array[0].array[0].integer);
}

test "parse exponential into int" {
    const T = struct { int: i64 };
    var ts = TokenStream.init("{ \"int\": 4.2e2 }");
    const r = try parse(T, &ts, ParseOptions{});
    try testing.expectEqual(@as(i64, 420), r.int);
    ts = TokenStream.init("{ \"int\": 0.042e2 }");
    try testing.expectError(error.InvalidNumber, parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("{ \"int\": 18446744073709551616.0 }");
    try testing.expectError(error.Overflow, parse(T, &ts, ParseOptions{}));
}
