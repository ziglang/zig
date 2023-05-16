const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Scanner = @import("./scanner.zig").Scanner;
const Token = @import("./scanner.zig").Token;
const AllocWhen = @import("./scanner.zig").AllocWhen;
const default_max_value_len = @import("./scanner.zig").default_max_value_len;
const isNumberFormattedLikeAnInteger = @import("./scanner.zig").isNumberFormattedLikeAnInteger;

pub const ParseOptions = struct {
    /// Behaviour when a duplicate field is encountered.
    duplicate_field_behavior: enum {
        use_first,
        @"error",
        use_last,
    } = .@"error",

    /// If false, finding an unknown field returns an error.
    ignore_unknown_fields: bool = false,

    /// Passed to json.Scanner.nextAllocMax() or json.Reader.nextAllocMax().
    /// The default for parseFromSlice() or parseFromTokenSource() with a *json.Scanner input
    /// is the length of the input slice, which means error.ValueTooLong will never be returned.
    /// The default for parseFromTokenSource() with a *json.Reader is default_max_value_len.
    max_value_len: ?usize = null,
};

/// Parses the json document from s and returns the result.
/// The provided allocator is used both for temporary allocations during parsing the document,
/// and also to allocate any pointer values in the return type.
/// If T contains any pointers, free the memory with `std.json.parseFree`.
/// Note that `error.BufferUnderrun` is not actually possible to return from this function.
pub fn parseFromSlice(comptime T: type, allocator: Allocator, s: []const u8, options: ParseOptions) ParseError(T, Scanner)!T {
    var scanner = Scanner.initCompleteInput(allocator, s);
    defer scanner.deinit();

    return parseFromTokenSource(T, allocator, &scanner, options);
}

/// `scanner_or_reader` must be either a `*std.json.Scanner` with complete input or a `*std.json.Reader`.
/// allocator is used to allocate the data of T if necessary,
/// such as if T is `*u32` or `[]u32`.
/// If T contains any pointers, free the memory with `std.json.parseFree`.
/// If T contains no pointers, the allocator may sometimes be used for temporary allocations,
/// but no call to `std.json.parseFree` will be necessary;
/// all temporary allocations will be freed before this function returns.
/// Note that `error.BufferUnderrun` is not actually possible to return from this function.
pub fn parseFromTokenSource(comptime T: type, allocator: Allocator, scanner_or_reader: anytype, options: ParseOptions) ParseError(T, @TypeOf(scanner_or_reader.*))!T {
    if (@TypeOf(scanner_or_reader.*) == Scanner) {
        assert(scanner_or_reader.is_end_of_input);
    }

    var resolved_options = options;
    if (resolved_options.max_value_len == null) {
        if (@TypeOf(scanner_or_reader.*) == Scanner) {
            resolved_options.max_value_len = scanner_or_reader.input.len;
        } else {
            resolved_options.max_value_len = default_max_value_len;
        }
    }

    const r = try parseInternal(T, allocator, scanner_or_reader, resolved_options);
    errdefer parseFree(T, allocator, r);

    assert(.end_of_document == try scanner_or_reader.next());

    return r;
}

/// The error set that will be returned from parsing T from *Source.
/// Note that this may contain error.BufferUnderrun, but that error will never actually be returned.
pub fn ParseError(comptime T: type, comptime Source: type) type {
    // `inferred_types` is used to avoid infinite recursion for recursive type definitions.
    const inferred_types = [_]type{};
    // A few of these will either always be present or present enough of the time that
    // omitting them is more confusing than always including them.
    return error{UnexpectedToken} || Source.NextError || Source.PeekError ||
        ParseInternalErrorImpl(T, Source, &inferred_types);
}

fn ParseInternalErrorImpl(comptime T: type, comptime Source: type, comptime inferred_types: []const type) type {
    for (inferred_types) |ty| {
        if (T == ty) return error{};
    }

    switch (@typeInfo(T)) {
        .Bool => return error{},
        .Float, .ComptimeFloat => return Source.AllocError || std.fmt.ParseFloatError,
        .Int, .ComptimeInt => {
            return Source.AllocError || error{ InvalidNumber, Overflow } ||
                std.fmt.ParseIntError || std.fmt.ParseFloatError;
        },
        .Optional => |optional_info| return ParseInternalErrorImpl(optional_info.child, Source, inferred_types ++ [_]type{T}),
        .Enum => return Source.AllocError || error{InvalidEnumTag},
        .Union => |unionInfo| {
            if (unionInfo.tag_type) |_| {
                var errors = Source.AllocError || error{UnknownField};
                for (unionInfo.fields) |u_field| {
                    errors = errors || ParseInternalErrorImpl(u_field.type, Source, inferred_types ++ [_]type{T});
                }
                return errors;
            } else {
                @compileError("Unable to parse into untagged union '" ++ @typeName(T) ++ "'");
            }
        },
        .Struct => |structInfo| {
            var errors = Scanner.AllocError || error{
                DuplicateField,
                UnknownField,
                MissingField,
            };
            for (structInfo.fields) |field| {
                errors = errors || ParseInternalErrorImpl(field.type, Source, inferred_types ++ [_]type{T});
            }
            return errors;
        },
        .Array => |arrayInfo| {
            return error{LengthMismatch} ||
                ParseInternalErrorImpl(arrayInfo.child, Source, inferred_types ++ [_]type{T});
        },
        .Vector => |vecInfo| {
            return error{LengthMismatch} ||
                ParseInternalErrorImpl(vecInfo.child, Source, inferred_types ++ [_]type{T});
        },
        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .One, .Slice => {
                    return ParseInternalErrorImpl(ptrInfo.child, Source, inferred_types ++ [_]type{T});
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
    allocator: Allocator,
    source: anytype,
    options: ParseOptions,
) ParseError(T, @TypeOf(source.*))!T {
    switch (@typeInfo(T)) {
        .Bool => {
            return switch (try source.next()) {
                .true => true,
                .false => false,
                else => error.UnexpectedToken,
            };
        },
        .Float, .ComptimeFloat => {
            const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
            defer freeAllocated(allocator, token);
            const slice = switch (token) {
                .number, .string => |slice| slice,
                .allocated_number, .allocated_string => |slice| slice,
                else => return error.UnexpectedToken,
            };
            return try std.fmt.parseFloat(T, slice);
        },
        .Int, .ComptimeInt => {
            const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
            defer freeAllocated(allocator, token);
            const slice = switch (token) {
                .number, .string => |slice| slice,
                .allocated_number, .allocated_string => |slice| slice,
                else => return error.UnexpectedToken,
            };
            if (isNumberFormattedLikeAnInteger(slice))
                return std.fmt.parseInt(T, slice, 10);
            // Try to coerce a float to an integer.
            const float = try std.fmt.parseFloat(f128, slice);
            if (@round(float) != float) return error.InvalidNumber;
            if (float > std.math.maxInt(T) or float < std.math.minInt(T)) return error.Overflow;
            return @floatToInt(T, float);
        },
        .Optional => |optionalInfo| {
            switch (try source.peekNextTokenType()) {
                .null => {
                    _ = try source.next();
                    return null;
                },
                else => {
                    return try parseInternal(optionalInfo.child, allocator, source, options);
                },
            }
        },
        .Enum => |enumInfo| {
            const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
            defer freeAllocated(allocator, token);
            const slice = switch (token) {
                .number, .string => |slice| slice,
                .allocated_number, .allocated_string => |slice| slice,
                else => return error.UnexpectedToken,
            };
            // Check for a named value.
            if (std.meta.stringToEnum(T, slice)) |value| return value;
            // Check for a numeric value.
            if (!isNumberFormattedLikeAnInteger(slice)) return error.InvalidEnumTag;
            const n = std.fmt.parseInt(enumInfo.tag_type, slice, 10) catch return error.InvalidEnumTag;
            return try std.meta.intToEnum(T, n);
        },
        .Union => |unionInfo| {
            const UnionTagType = unionInfo.tag_type orelse @compileError("Unable to parse into untagged union '" ++ @typeName(T) ++ "'");

            if (.object_begin != try source.next()) return error.UnexpectedToken;

            var result: ?T = null;
            errdefer {
                if (result) |r| {
                    inline for (unionInfo.fields) |u_field| {
                        if (r == @field(UnionTagType, u_field.name)) {
                            parseFree(u_field.type, allocator, @field(r, u_field.name));
                        }
                    }
                }
            }

            var name_token: ?Token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
            errdefer {
                if (name_token) |t| {
                    freeAllocated(allocator, t);
                }
            }
            const field_name = switch (name_token.?) {
                .string => |slice| slice,
                .allocated_string => |slice| slice,
                else => return error.UnexpectedToken,
            };

            inline for (unionInfo.fields) |u_field| {
                if (std.mem.eql(u8, u_field.name, field_name)) {
                    // Free the name token now in case we're using an allocator that optimizes freeing the last allocated object.
                    // (Recursing into parseInternal() might trigger more allocations.)
                    freeAllocated(allocator, name_token.?);
                    name_token = null;

                    if (u_field.type == void) {
                        // void isn't really a json type, but we can support void payload union tags with {} as a value.
                        if (.object_begin != try source.next()) return error.UnexpectedToken;
                        if (.object_end != try source.next()) return error.UnexpectedToken;
                        result = @unionInit(T, u_field.name, {});
                    } else {
                        // Recurse.
                        result = @unionInit(T, u_field.name, try parseInternal(u_field.type, allocator, source, options));
                    }
                    break;
                }
            } else {
                // Didn't match anything.
                return error.UnknownField;
            }

            if (.object_end != try source.next()) return error.UnexpectedToken;

            return result.?;
        },

        .Struct => |structInfo| {
            if (structInfo.is_tuple) {
                if (.array_begin != try source.next()) return error.UnexpectedToken;

                var r: T = undefined;
                var fields_seen: usize = 0;
                errdefer {
                    inline for (0..structInfo.fields.len) |i| {
                        if (i < fields_seen) {
                            parseFree(structInfo.fields[i].type, allocator, r[i]);
                        }
                    }
                }
                inline for (0..structInfo.fields.len) |i| {
                    r[i] = try parseInternal(structInfo.fields[i].type, allocator, source, options);
                    fields_seen = i + 1;
                }

                if (.array_end != try source.next()) return error.UnexpectedToken;

                return r;
            }

            if (.object_begin != try source.next()) return error.UnexpectedToken;

            var r: T = undefined;
            var fields_seen = [_]bool{false} ** structInfo.fields.len;
            errdefer {
                inline for (structInfo.fields, 0..) |field, i| {
                    if (fields_seen[i]) {
                        parseFree(field.type, allocator, @field(r, field.name));
                    }
                }
            }

            while (true) {
                var name_token: ?Token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
                errdefer {
                    if (name_token) |t| {
                        freeAllocated(allocator, t);
                    }
                }
                const field_name = switch (name_token.?) {
                    .object_end => break, // No more fields.
                    .string => |slice| slice,
                    .allocated_string => |slice| slice,
                    else => return error.UnexpectedToken,
                };

                inline for (structInfo.fields, 0..) |field, i| {
                    if (field.is_comptime) @compileError("comptime fields are not supported: " ++ @typeName(T) ++ "." ++ field.name);
                    if (std.mem.eql(u8, field.name, field_name)) {
                        // Free the name token now in case we're using an allocator that optimizes freeing the last allocated object.
                        // (Recursing into parseInternal() might trigger more allocations.)
                        freeAllocated(allocator, name_token.?);
                        name_token = null;

                        if (fields_seen[i]) {
                            switch (options.duplicate_field_behavior) {
                                .use_first => {
                                    // Parse and then delete the redundant value.
                                    // We don't want to skip the value, because we want type checking.
                                    const ignored_value = try parseInternal(field.type, allocator, source, options);
                                    parseFree(field.type, allocator, ignored_value);
                                    break;
                                },
                                .@"error" => return error.DuplicateField,
                                .use_last => {
                                    // Delete the stale value. We're about to get a new one.
                                    parseFree(field.type, allocator, @field(r, field.name));
                                    fields_seen[i] = false;
                                },
                            }
                        }
                        @field(r, field.name) = try parseInternal(field.type, allocator, source, options);
                        fields_seen[i] = true;
                        break;
                    }
                } else {
                    // Didn't match anything.
                    freeAllocated(allocator, name_token.?);
                    if (options.ignore_unknown_fields) {
                        try source.skipValue();
                    } else {
                        return error.UnknownField;
                    }
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
            switch (try source.peekNextTokenType()) {
                .array_begin => {
                    // Typical array.
                    return parseInternalArray(T, arrayInfo.child, arrayInfo.len, allocator, source, options);
                },
                .string => {
                    if (arrayInfo.child != u8) return error.UnexpectedToken;
                    // Fixed-length string.

                    var r: T = undefined;
                    var i: usize = 0;
                    while (true) {
                        switch (try source.next()) {
                            .string => |slice| {
                                if (i + slice.len != r.len) return error.LengthMismatch;
                                @memcpy(r[i..][0..slice.len], slice);
                                break;
                            },
                            .partial_string => |slice| {
                                if (i + slice.len > r.len) return error.LengthMismatch;
                                @memcpy(r[i..][0..slice.len], slice);
                                i += slice.len;
                            },
                            .partial_string_escaped_1 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                @memcpy(r[i..][0..arr.len], arr[0..]);
                                i += arr.len;
                            },
                            .partial_string_escaped_2 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                @memcpy(r[i..][0..arr.len], arr[0..]);
                                i += arr.len;
                            },
                            .partial_string_escaped_3 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                @memcpy(r[i..][0..arr.len], arr[0..]);
                                i += arr.len;
                            },
                            .partial_string_escaped_4 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                @memcpy(r[i..][0..arr.len], arr[0..]);
                                i += arr.len;
                            },
                            else => unreachable,
                        }
                    }

                    return r;
                },

                else => return error.UnexpectedToken,
            }
        },

        .Vector => |vecInfo| {
            switch (try source.peekNextTokenType()) {
                .array_begin => {
                    return parseInternalArray(T, vecInfo.child, vecInfo.len, allocator, source, options);
                },
                else => return error.UnexpectedToken,
            }
        },

        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .One => {
                    const r: *ptrInfo.child = try allocator.create(ptrInfo.child);
                    errdefer allocator.destroy(r);
                    r.* = try parseInternal(ptrInfo.child, allocator, source, options);
                    return r;
                },
                .Slice => {
                    switch (try source.peekNextTokenType()) {
                        .array_begin => {
                            _ = try source.next();

                            // Typical array.
                            var arraylist = ArrayList(ptrInfo.child).init(allocator);
                            errdefer {
                                while (arraylist.popOrNull()) |v| {
                                    parseFree(ptrInfo.child, allocator, v);
                                }
                                arraylist.deinit();
                            }

                            while (true) {
                                switch (try source.peekNextTokenType()) {
                                    .array_end => {
                                        _ = try source.next();
                                        break;
                                    },
                                    else => {},
                                }

                                try arraylist.ensureUnusedCapacity(1);
                                arraylist.appendAssumeCapacity(try parseInternal(ptrInfo.child, allocator, source, options));
                            }

                            if (ptrInfo.sentinel) |some| {
                                const sentinel_value = @ptrCast(*align(1) const ptrInfo.child, some).*;
                                return try arraylist.toOwnedSliceSentinel(sentinel_value);
                            }

                            return try arraylist.toOwnedSlice();
                        },
                        .string => {
                            if (ptrInfo.child != u8) return error.UnexpectedToken;

                            // Dynamic length string.
                            if (ptrInfo.sentinel) |sentinel_ptr| {
                                // Use our own array list so we can append the sentinel.
                                var value_list = ArrayList(u8).init(allocator);
                                errdefer value_list.deinit();
                                _ = try source.allocNextIntoArrayList(&value_list, .alloc_always);
                                return try value_list.toOwnedSliceSentinel(@ptrCast(*const u8, sentinel_ptr).*);
                            }
                            switch (try source.nextAllocMax(allocator, .alloc_always, options.max_value_len.?)) {
                                .allocated_string => |slice| return slice,
                                else => unreachable,
                            }
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

fn parseInternalArray(
    comptime T: type,
    comptime Child: type,
    comptime len: comptime_int,
    allocator: Allocator,
    source: anytype,
    options: ParseOptions,
) !T {
    assert(.array_begin == try source.next());

    var r: T = undefined;
    var i: usize = 0;
    errdefer {
        // Without the len check `r[i]` is not allowed
        if (len > 0) while (true) : (i -= 1) {
            parseFree(Child, allocator, r[i]);
            if (i == 0) break;
        };
    }
    while (i < len) : (i += 1) {
        r[i] = try parseInternal(Child, allocator, source, options);
    }

    if (.array_end != try source.next()) return error.UnexpectedToken;

    return r;
}

fn freeAllocated(allocator: Allocator, token: Token) void {
    switch (token) {
        .allocated_number, .allocated_string => |slice| {
            allocator.free(slice);
        },
        else => {},
    }
}

/// Releases resources created by parseFromSlice() or parseFromTokenSource().
pub fn parseFree(comptime T: type, allocator: Allocator, value: T) void {
    switch (@typeInfo(T)) {
        .Bool, .Float, .ComptimeFloat, .Int, .ComptimeInt, .Enum => {},
        .Optional => {
            if (value) |v| {
                return parseFree(@TypeOf(v), allocator, v);
            }
        },
        .Union => |unionInfo| {
            if (unionInfo.tag_type) |UnionTagType| {
                inline for (unionInfo.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        parseFree(u_field.type, allocator, @field(value, u_field.name));
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
                    parseFree(field.type, allocator, @field(value, field.name));
                }
            }
        },
        .Array => |arrayInfo| {
            for (value) |v| {
                parseFree(arrayInfo.child, allocator, v);
            }
        },
        .Vector => |vecInfo| {
            var i: usize = 0;
            while (i < vecInfo.len) : (i += 1) {
                parseFree(vecInfo.child, allocator, value[i]);
            }
        },
        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .One => {
                    parseFree(ptrInfo.child, allocator, value.*);
                    allocator.destroy(value);
                },
                .Slice => {
                    for (value) |v| {
                        parseFree(ptrInfo.child, allocator, v);
                    }
                    allocator.free(value);
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

test {
    _ = @import("./static_test.zig");
}
