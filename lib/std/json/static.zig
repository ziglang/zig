
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

