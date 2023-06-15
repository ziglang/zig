const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
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

pub fn Parsed(comptime T: type) type {
    return struct {
        arena: *ArenaAllocator,
        value: T,

        pub fn deinit(self: @This()) void {
            const allocator = self.arena.child_allocator;
            self.arena.deinit();
            allocator.destroy(self.arena);
        }
    };
}

/// Parses the json document from `s` and returns the result packaged in a `std.json.Parsed`.
/// You must call `deinit()` of the returned object to clean up allocated resources.
/// Note that `error.BufferUnderrun` is not actually possible to return from this function.
pub fn parseFromSlice(
    comptime T: type,
    allocator: Allocator,
    s: []const u8,
    options: ParseOptions,
) ParseError(Scanner)!Parsed(T) {
    var scanner = Scanner.initCompleteInput(allocator, s);
    defer scanner.deinit();

    return parseFromTokenSource(T, allocator, &scanner, options);
}

/// Parses the json document from `s` and returns the result.
/// Allocations made during this operation are not carefully tracked and may not be possible to individually clean up.
/// It is recommended to use a `std.heap.ArenaAllocator` or similar.
pub fn parseFromSliceLeaky(
    comptime T: type,
    allocator: Allocator,
    s: []const u8,
    options: ParseOptions,
) ParseError(Scanner)!T {
    var scanner = Scanner.initCompleteInput(allocator, s);
    defer scanner.deinit();

    return parseFromTokenSourceLeaky(T, allocator, &scanner, options);
}

/// `scanner_or_reader` must be either a `*std.json.Scanner` with complete input or a `*std.json.Reader`.
/// Note that `error.BufferUnderrun` is not actually possible to return from this function.
pub fn parseFromTokenSource(
    comptime T: type,
    allocator: Allocator,
    scanner_or_reader: anytype,
    options: ParseOptions,
) ParseError(@TypeOf(scanner_or_reader.*))!Parsed(T) {
    var parsed = Parsed(T){
        .arena = try allocator.create(ArenaAllocator),
        .value = undefined,
    };
    errdefer allocator.destroy(parsed.arena);
    parsed.arena.* = ArenaAllocator.init(allocator);
    errdefer parsed.arena.deinit();

    parsed.value = try parseFromTokenSourceLeaky(T, parsed.arena.allocator(), scanner_or_reader, options);

    return parsed;
}

/// `scanner_or_reader` must be either a `*std.json.Scanner` with complete input or a `*std.json.Reader`.
/// Allocations made during this operation are not carefully tracked and may not be possible to individually clean up.
/// It is recommended to use a `std.heap.ArenaAllocator` or similar.
pub fn parseFromTokenSourceLeaky(
    comptime T: type,
    allocator: Allocator,
    scanner_or_reader: anytype,
    options: ParseOptions,
) ParseError(@TypeOf(scanner_or_reader.*))!T {
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

    const value = try parseInternal(T, allocator, scanner_or_reader, resolved_options);

    assert(.end_of_document == try scanner_or_reader.next());

    return value;
}

/// The error set that will be returned when parsing from `*Source`.
/// Note that this may contain `error.BufferUnderrun`, but that error will never actually be returned.
pub fn ParseError(comptime Source: type) type {
    // A few of these will either always be present or present enough of the time that
    // omitting them is more confusing than always including them.
    return error{
        UnexpectedToken,
        InvalidNumber,
        Overflow,
        InvalidEnumTag,
        DuplicateField,
        UnknownField,
        MissingField,
        LengthMismatch,
    } ||
        std.fmt.ParseIntError || std.fmt.ParseFloatError ||
        Source.NextError || Source.PeekError || Source.AllocError;
}

fn parseInternal(
    comptime T: type,
    allocator: Allocator,
    source: anytype,
    options: ParseOptions,
) ParseError(@TypeOf(source.*))!T {
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
                inline .number, .allocated_number, .string, .allocated_string => |slice| slice,
                else => return error.UnexpectedToken,
            };
            return try std.fmt.parseFloat(T, slice);
        },
        .Int, .ComptimeInt => {
            const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
            defer freeAllocated(allocator, token);
            const slice = switch (token) {
                inline .number, .allocated_number, .string, .allocated_string => |slice| slice,
                else => return error.UnexpectedToken,
            };
            if (isNumberFormattedLikeAnInteger(slice))
                return std.fmt.parseInt(T, slice, 10);
            // Try to coerce a float to an integer.
            const float = try std.fmt.parseFloat(f128, slice);
            if (@round(float) != float) return error.InvalidNumber;
            if (float > std.math.maxInt(T) or float < std.math.minInt(T)) return error.Overflow;
            return @intFromFloat(T, float);
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
            if (comptime std.meta.trait.hasFn("jsonParse")(T)) {
                return T.jsonParse(allocator, source, options);
            }

            const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
            defer freeAllocated(allocator, token);
            const slice = switch (token) {
                inline .number, .allocated_number, .string, .allocated_string => |slice| slice,
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
            if (comptime std.meta.trait.hasFn("jsonParse")(T)) {
                return T.jsonParse(allocator, source, options);
            }

            if (unionInfo.tag_type == null) @compileError("Unable to parse into untagged union '" ++ @typeName(T) ++ "'");

            if (.object_begin != try source.next()) return error.UnexpectedToken;

            var result: ?T = null;
            var name_token: ?Token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
            const field_name = switch (name_token.?) {
                inline .string, .allocated_string => |slice| slice,
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
                inline for (0..structInfo.fields.len) |i| {
                    r[i] = try parseInternal(structInfo.fields[i].type, allocator, source, options);
                    fields_seen = i + 1;
                }

                if (.array_end != try source.next()) return error.UnexpectedToken;

                return r;
            }

            if (comptime std.meta.trait.hasFn("jsonParse")(T)) {
                return T.jsonParse(allocator, source, options);
            }

            if (.object_begin != try source.next()) return error.UnexpectedToken;

            var r: T = undefined;
            var fields_seen = [_]bool{false} ** structInfo.fields.len;

            while (true) {
                var name_token: ?Token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
                const field_name = switch (name_token.?) {
                    .object_end => break, // No more fields.
                    inline .string, .allocated_string => |slice| slice,
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
                                    // Parse and ignore the redundant value.
                                    // We don't want to skip the value, because we want type checking.
                                    _ = try parseInternal(field.type, allocator, source, options);
                                    break;
                                },
                                .@"error" => return error.DuplicateField,
                                .use_last => {},
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
                    r.* = try parseInternal(ptrInfo.child, allocator, source, options);
                    return r;
                },
                .Slice => {
                    switch (try source.peekNextTokenType()) {
                        .array_begin => {
                            _ = try source.next();

                            // Typical array.
                            var arraylist = ArrayList(ptrInfo.child).init(allocator);
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
                                _ = try source.allocNextIntoArrayList(&value_list, .alloc_always);
                                return try value_list.toOwnedSliceSentinel(@ptrCast(*const u8, sentinel_ptr).*);
                            }
                            if (ptrInfo.is_const) {
                                switch (try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?)) {
                                    inline .string, .allocated_string => |slice| return slice,
                                    else => unreachable,
                                }
                            } else {
                                // Have to allocate to get a mutable copy.
                                switch (try source.nextAllocMax(allocator, .alloc_always, options.max_value_len.?)) {
                                    .allocated_string => |slice| return slice,
                                    else => unreachable,
                                }
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

test {
    _ = @import("./static_test.zig");
}
