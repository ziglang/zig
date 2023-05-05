const std = @import("std");
const mem = std.mem;

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const JsonScanner = @import("./scanner.zig").JsonScanner;
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

    /// Passed to JsonScanner.nextAllocMax() or JsonReader.nextAllocMax().
    /// The default for parseFromSlice() or parseFromTokenSource() with a *JsonScanner input
    /// is the length of the input slice, which means error.ValueTooLong will never be returned.
    /// The default for parseFromTokenSource() with a *JsonReader is default_max_value_len.
    max_value_len: ?usize = null,
};

pub fn parseFromSlice(comptime T: type, allocator: Allocator, s: []const u8, options: ParseOptions) ParseError(T, JsonScanner)!T {
    var scanner = JsonScanner.initCompleteInput(allocator, s);
    defer scanner.deinit();

    return parseFromTokenSource(T, allocator, &scanner, options);
}
/// scanner_or_reader must be either a *JsonScanner with complete input or a *JsonReader.
/// allocator is used to allocate the data of T if necessary,
/// such as if T is *u32 or []u32.
/// If T contains no pointers, the allocator is never used.
pub fn parseFromTokenSource(comptime T: type, allocator: Allocator, scanner_or_reader: anytype, options: ParseOptions) ParseError(T, @TypeOf(scanner_or_reader.*))!T {
    if (@TypeOf(scanner_or_reader.*) == JsonScanner) {
        assert(scanner_or_reader.is_end_of_input);
    }

    var resolved_options = options;
    if (resolved_options.max_value_len == null) {
        if (@TypeOf(scanner_or_reader.*) == JsonScanner) {
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

fn ParseError(comptime T: type, comptime Source: type) type {
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
            var errors = JsonScanner.AllocError || error{
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
            const token = try source.nextAlloc(allocator, .alloc_if_needed);
            defer freeAllocated(allocator, token);
            const slice = switch (token) {
                .number, .string => |slice| slice,
                .allocated_number, .allocated_string => |slice| slice,
                else => return error.UnexpectedToken,
            };
            return try std.fmt.parseFloat(T, slice);
        },
        .Int, .ComptimeInt => {
            const token = try source.nextAlloc(allocator, .alloc_if_needed);
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
            const token = try source.nextAlloc(allocator, .alloc_if_needed);
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

            var name_token: ?Token = try source.nextAlloc(allocator, .alloc_if_needed);
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
                if (mem.eql(u8, u_field.name, field_name)) {
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
                var name_token: ?Token = try source.nextAlloc(allocator, .alloc_if_needed);
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
                    if (mem.eql(u8, field.name, field_name)) {
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
                    _ = try source.next();

                    // Typical array.
                    var r: T = undefined;
                    var i: usize = 0;
                    errdefer {
                        // Without the r.len check `r[i]` is not allowed
                        if (r.len > 0) while (true) : (i -= 1) {
                            parseFree(arrayInfo.child, allocator, r[i]);
                            if (i == 0) break;
                        };
                    }
                    while (i < r.len) : (i += 1) {
                        r[i] = try parseInternal(arrayInfo.child, allocator, source, options);
                    }

                    if (.array_end != try source.next()) return error.UnexpectedToken;

                    return r;
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
                                std.mem.copy(u8, r[i..], slice);
                                break;
                            },
                            .partial_string => |slice| {
                                if (i + slice.len > r.len) return error.LengthMismatch;
                                std.mem.copy(u8, r[i..], slice);
                                i += slice.len;
                            },
                            .partial_string_escaped_1 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                std.mem.copy(u8, r[i..], arr[0..]);
                                i += arr.len;
                            },
                            .partial_string_escaped_2 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                std.mem.copy(u8, r[i..], arr[0..]);
                                i += arr.len;
                            },
                            .partial_string_escaped_3 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                std.mem.copy(u8, r[i..], arr[0..]);
                                i += arr.len;
                            },
                            .partial_string_escaped_4 => |arr| {
                                if (i + arr.len > r.len) return error.LengthMismatch;
                                std.mem.copy(u8, r[i..], arr[0..]);
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
                            switch (try source.nextAlloc(allocator, .alloc_always)) {
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

fn freeAllocated(allocator: Allocator, token: Token) void {
    switch (token) {
        .allocated_number, .allocated_string => |slice| {
            allocator.free(slice);
        },
        else => {},
    }
}

/// Releases resources created by `parse`.
/// Should be called with the same type and `ParseOptions` that were passed to `parse`
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

const testing = std.testing;

test "parse" {
    try testing.expectEqual(false, try parseFromSlice(bool, testing.allocator, "false", .{}));
    try testing.expectEqual(true, try parseFromSlice(bool, testing.allocator, "true", .{}));
    try testing.expectEqual(@as(u1, 1), try parseFromSlice(u1, testing.allocator, "1", .{}));
    try testing.expectError(error.Overflow, parseFromSlice(u1, testing.allocator, "50", .{}));
    try testing.expectEqual(@as(u64, 42), try parseFromSlice(u64, testing.allocator, "42", .{}));
    try testing.expectEqual(@as(f64, 42), try parseFromSlice(f64, testing.allocator, "42.0", .{}));
    try testing.expectEqual(@as(?bool, null), try parseFromSlice(?bool, testing.allocator, "null", .{}));
    try testing.expectEqual(@as(?bool, true), try parseFromSlice(?bool, testing.allocator, "true", .{}));

    try testing.expectEqual(@as([3]u8, "foo".*), try parseFromSlice([3]u8, testing.allocator, "\"foo\"", .{}));
    try testing.expectEqual(@as([3]u8, "foo".*), try parseFromSlice([3]u8, testing.allocator, "[102, 111, 111]", .{}));
    try testing.expectEqual(@as([0]u8, undefined), try parseFromSlice([0]u8, testing.allocator, "[]", .{}));

    try testing.expectEqual(@as(u64, 12345678901234567890), try parseFromSlice(u64, testing.allocator, "\"12345678901234567890\"", .{}));
    try testing.expectEqual(@as(f64, 123.456), try parseFromSlice(f64, testing.allocator, "\"123.456\"", .{}));
}

test "parse into enum" {
    const T = enum(u32) {
        Foo = 42,
        Bar,
        @"with\\escape",
    };
    try testing.expectEqual(@as(T, .Foo), try parseFromSlice(T, testing.allocator, "\"Foo\"", .{}));
    try testing.expectEqual(@as(T, .Foo), try parseFromSlice(T, testing.allocator, "42", .{}));
    try testing.expectEqual(@as(T, .@"with\\escape"), try parseFromSlice(T, testing.allocator, "\"with\\\\escape\"", .{}));
    try testing.expectError(error.InvalidEnumTag, parseFromSlice(T, testing.allocator, "5", .{}));
    try testing.expectError(error.InvalidEnumTag, parseFromSlice(T, testing.allocator, "\"Qux\"", .{}));
}

test "parse into that allocates a slice" {
    {
        // string as string
        const r = try parseFromSlice([]u8, testing.allocator, "\"foo\"", .{});
        defer parseFree([]u8, testing.allocator, r);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        // string as array of u8 integers
        const r = try parseFromSlice([]u8, testing.allocator, "[102, 111, 111]", .{});
        defer parseFree([]u8, testing.allocator, r);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        const r = try parseFromSlice([]u8, testing.allocator, "\"with\\\\escape\"", .{});
        defer parseFree([]u8, testing.allocator, r);
        try testing.expectEqualSlices(u8, "with\\escape", r);
    }
}

test "parse into sentinel slice" {
    const result = try parseFromSlice([:0]const u8, testing.allocator, "\"\\n\"", .{});
    defer parseFree([:0]const u8, testing.allocator, result);
    try testing.expect(mem.eql(u8, result, "\n"));
}

test "parse into tagged union" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    try testing.expectEqual(T{ .float = 1.5 }, try parseFromSlice(T, testing.allocator, "{\"float\":1.5}", .{}));
    try testing.expectEqual(T{ .int = 1 }, try parseFromSlice(T, testing.allocator, "{\"int\":1}", .{}));
    try testing.expectEqual(T{ .nothing = {} }, try parseFromSlice(T, testing.allocator, "{\"nothing\":{}}", .{}));
}

test "parse into tagged union errors" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "42", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{}", .{}));
    try testing.expectError(error.UnknownField, parseFromSlice(T, testing.allocator, "{\"bogus\":1}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"int\":1, \"int\":1", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"int\":1, \"float\":1.0}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"nothing\":null}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"nothing\":{\"no\":0}}", .{}));

    // Allocator failure
    var fail_alloc = testing.FailingAllocator.init(testing.allocator, 0);
    const failing_allocator = fail_alloc.allocator();
    try testing.expectError(error.OutOfMemory, parseFromSlice(T, failing_allocator, "{\"string\"\"foo\"}", .{}));
}

test "parseFree descends into tagged union" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    const r = try parseFromSlice(T, testing.allocator, "{\"string\":\"foo\"}", .{});
    try testing.expectEqualSlices(u8, "foo", r.string);
    parseFree(T, testing.allocator, r);
}

test "parse into struct with no fields" {
    const T = struct {};
    try testing.expectEqual(T{}, try parseFromSlice(T, testing.allocator, "{}", .{}));
}

const test_const_value: usize = 123;

test "parse into struct with default const pointer field" {
    const T = struct { a: *const usize = &test_const_value };
    try testing.expectEqual(T{}, try parseFromSlice(T, testing.allocator, "{}", .{}));
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

    const parsed = try parseFromSlice(T, testing.allocator, "{}", .{});
    try testing.expectEqual(T{}, parsed);
    // This will panic if it tries to free global constants:
    parseFree(T, testing.allocator, parsed);
}

test "parse into struct where destination and source lengths mismatch" {
    const T = struct { a: [2]u8 };
    try testing.expectError(error.LengthMismatch, parseFromSlice(T, testing.allocator, "{\"a\": \"bbb\"}", .{}));
}

test "parse into struct with misc fields" {
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
    var document_str =
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
    ;
    const r = try parseFromSlice(T, testing.allocator, document_str, .{});
    defer parseFree(T, testing.allocator, r);
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
    const T = struct {
        language: [:0]const u8,
        language_without_sentinel: []const u8,
        data: [:99]const i32,
        simple_data: []const i32,
    };
    var document_str =
        \\{
        \\  "language": "zig",
        \\  "language_without_sentinel": "zig again!",
        \\  "data": [1, 2, 3],
        \\  "simple_data": [4, 5, 6]
        \\}
    ;
    const r = try parseFromSlice(T, testing.allocator, document_str, .{});
    defer parseFree(T, testing.allocator, r);

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

    const options_first = ParseOptions{ .duplicate_field_behavior = .use_first };
    const options_last = ParseOptions{ .duplicate_field_behavior = .use_last };

    const str = "{ \"a\": 1, \"a\": 0.25 }";

    const T1 = struct { a: *u64 };
    // both .use_first and .use_last should fail because second "a" value isn't a u64
    try testing.expectError(error.InvalidNumber, parseFromSlice(T1, testing.allocator, str, options_first));
    try testing.expectError(error.InvalidNumber, parseFromSlice(T1, testing.allocator, str, options_last));

    const T2 = struct { a: f64 };
    try testing.expectEqual(T2{ .a = 1.0 }, try parseFromSlice(T2, testing.allocator, str, options_first));
    try testing.expectEqual(T2{ .a = 0.25 }, try parseFromSlice(T2, testing.allocator, str, options_last));
}

test "parse into struct ignoring unknown fields" {
    const T = struct {
        int: i64,
        language: []const u8,
    };

    var str =
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
        \\  "a_union": {
        \\    "float": 100000
        \\  },
        \\  "language": "zig"
        \\}
    ;
    const r = try parseFromSlice(T, testing.allocator, str, .{ .ignore_unknown_fields = true });
    defer parseFree(T, testing.allocator, r);

    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectEqualSlices(u8, "zig", r.language);
}

test "parse into tuple" {
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
    var str =
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
    ;
    const r = try parseFromSlice(T, testing.allocator, str, .{});
    defer parseFree(T, testing.allocator, r);
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

    const r = try parseFromSlice(T, testing.allocator, "{\"values\":{\"array\":[{\"integer\":58}]}}", .{});
    defer parseFree(T, testing.allocator, r);

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

    const r = try parseFromSlice(T, testing.allocator, "{\"values\":{\"array\":[{\"array\":[{\"integer\":58}]}]}}", .{});
    defer parseFree(T, testing.allocator, r);

    try testing.expectEqual(@as(i64, 58), r.values.array[0].array[0].integer);
}

test "parse exponential into int" {
    const T = struct { int: i64 };
    const r = try parseFromSlice(T, testing.allocator, "{ \"int\": 4.2e2 }", .{});
    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectError(error.InvalidNumber, parseFromSlice(T, testing.allocator, "{ \"int\": 0.042e2 }", .{}));
    try testing.expectError(error.Overflow, parseFromSlice(T, testing.allocator, "{ \"int\": 18446744073709551616.0 }", .{}));
}
