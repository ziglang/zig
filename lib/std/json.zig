// JSON parser conforming to RFC8259.
//
// https://tools.ietf.org/html/rfc8259

const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const maxInt = std.math.maxInt;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;

pub const WriteStream = @import("json/write_stream.zig").WriteStream;
pub const writeStream = @import("json/write_stream.zig").writeStream;

pub const JsonError = @import("json/scanner.zig").JsonError;
pub const jsonReader = @import("json/scanner.zig").jsonReader;
pub const default_buffer_size = @import("json/scanner.zig").default_buffer_size;
pub const Token = @import("json/scanner.zig").Token;
pub const JsonReader = @import("json/scanner.zig").JsonReader;
pub const JsonScanner = @import("json/scanner.zig").JsonScanner;

/// Validate a JSON string. This does not limit number precision so a decoder may not necessarily
/// be able to decode the string even if this returns true.
pub fn validate(allocator: Allocator, s: []const u8) bool {
    var scanner = JsonScanner.initCompleteInput(allocator, s);
    while (true) {
        const token = scanner.next() catch return false;
        if (token == .end_of_document) break;
    }
    return true;
}

pub const ValueTree = struct {
    arena: *ArenaAllocator,
    root: Value,

    pub fn deinit(self: *ValueTree) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};

pub const ObjectMap = StringArrayHashMap(Value);
pub const Array = ArrayList(Value);

/// Represents a JSON value
/// Currently only supports numbers that fit into i64 or f64.
pub const Value = union(enum) {
    Null,
    Bool: bool,
    Integer: i64,
    Float: f64,
    NumberString: []const u8,
    String: []const u8,
    Array: Array,
    Object: ObjectMap,

    pub fn jsonStringify(
        value: @This(),
        options: StringifyOptions,
        out_stream: anytype,
    ) @TypeOf(out_stream).Error!void {
        switch (value) {
            .Null => try stringify(null, options, out_stream),
            .Bool => |inner| try stringify(inner, options, out_stream),
            .Integer => |inner| try stringify(inner, options, out_stream),
            .Float => |inner| try stringify(inner, options, out_stream),
            .NumberString => |inner| try out_stream.writeAll(inner),
            .String => |inner| try stringify(inner, options, out_stream),
            .Array => |inner| try stringify(inner.items, options, out_stream),
            .Object => |inner| {
                try out_stream.writeByte('{');
                var field_output = false;
                var child_options = options;
                if (child_options.whitespace) |*child_whitespace| {
                    child_whitespace.indent_level += 1;
                }
                var it = inner.iterator();
                while (it.next()) |entry| {
                    if (!field_output) {
                        field_output = true;
                    } else {
                        try out_stream.writeByte(',');
                    }
                    if (child_options.whitespace) |child_whitespace| {
                        try child_whitespace.outputIndent(out_stream);
                    }

                    try stringify(entry.key_ptr.*, options, out_stream);
                    try out_stream.writeByte(':');
                    if (child_options.whitespace) |child_whitespace| {
                        if (child_whitespace.separator) {
                            try out_stream.writeByte(' ');
                        }
                    }
                    try stringify(entry.value_ptr.*, child_options, out_stream);
                }
                if (field_output) {
                    if (options.whitespace) |whitespace| {
                        try whitespace.outputIndent(out_stream);
                    }
                }
                try out_stream.writeByte('}');
            },
        }
    }

    pub fn dump(self: Value) void {
        std.debug.getStderrMutex().lock();
        defer std.debug.getStderrMutex().unlock();

        const stderr = std.io.getStdErr().writer();
        stringify(self, StringifyOptions{ .whitespace = null }, stderr) catch return;
    }
};

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

/// A non-stream JSON parser which constructs a tree of Value's.
pub const Parser = struct {
    allocator: Allocator,
    state: State,
    copy_strings: bool,
    // Stores parent nodes and un-combined Values.
    stack: Array,

    const State = enum {
        ObjectKey,
        ObjectValue,
        ArrayValue,
        Simple,
    };

    pub fn init(allocator: Allocator, copy_strings: bool) Parser {
        return Parser{
            .allocator = allocator,
            .state = .Simple,
            .copy_strings = copy_strings,
            .stack = Array.init(allocator),
        };
    }

    pub fn deinit(p: *Parser) void {
        p.stack.deinit();
    }

    pub fn reset(p: *Parser) void {
        p.state = .Simple;
        p.stack.shrinkRetainingCapacity(0);
    }

    pub fn parse(p: *Parser, input: []const u8) !ValueTree {
        var s = TokenStream.init(input);

        var arena = try p.allocator.create(ArenaAllocator);
        errdefer p.allocator.destroy(arena);

        arena.* = ArenaAllocator.init(p.allocator);
        errdefer arena.deinit();

        const allocator = arena.allocator();

        while (try s.next()) |token| {
            try p.transition(allocator, input, s.i - 1, token);
        }

        debug.assert(p.stack.items.len == 1);

        return ValueTree{
            .arena = arena,
            .root = p.stack.items[0],
        };
    }

    // Even though p.allocator exists, we take an explicit allocator so that allocation state
    // can be cleaned up on error correctly during a `parse` on call.
    fn transition(p: *Parser, allocator: Allocator, input: []const u8, i: usize, token: Token) !void {
        switch (p.state) {
            .ObjectKey => switch (token) {
                .ObjectEnd => {
                    if (p.stack.items.len == 1) {
                        return;
                    }

                    var value = p.stack.pop();
                    try p.pushToParent(&value);
                },
                .String => |s| {
                    try p.stack.append(try p.parseString(allocator, s, input, i));
                    p.state = .ObjectValue;
                },
                else => {
                    // The streaming parser would return an error eventually.
                    // To prevent invalid state we return an error now.
                    // TODO make the streaming parser return an error as soon as it encounters an invalid object key
                    return error.InvalidLiteral;
                },
            },
            .ObjectValue => {
                var object = &p.stack.items[p.stack.items.len - 2].Object;
                var key = p.stack.items[p.stack.items.len - 1].String;

                switch (token) {
                    .ObjectBegin => {
                        try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                        p.state = .ObjectKey;
                    },
                    .ArrayBegin => {
                        try p.stack.append(Value{ .Array = Array.init(allocator) });
                        p.state = .ArrayValue;
                    },
                    .String => |s| {
                        try object.put(key, try p.parseString(allocator, s, input, i));
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .Number => |n| {
                        try object.put(key, try p.parseNumber(n, input, i));
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .True => {
                        try object.put(key, Value{ .Bool = true });
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .False => {
                        try object.put(key, Value{ .Bool = false });
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .Null => {
                        try object.put(key, Value.Null);
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .ObjectEnd, .ArrayEnd => {
                        unreachable;
                    },
                }
            },
            .ArrayValue => {
                var array = &p.stack.items[p.stack.items.len - 1].Array;

                switch (token) {
                    .ArrayEnd => {
                        if (p.stack.items.len == 1) {
                            return;
                        }

                        var value = p.stack.pop();
                        try p.pushToParent(&value);
                    },
                    .ObjectBegin => {
                        try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                        p.state = .ObjectKey;
                    },
                    .ArrayBegin => {
                        try p.stack.append(Value{ .Array = Array.init(allocator) });
                        p.state = .ArrayValue;
                    },
                    .String => |s| {
                        try array.append(try p.parseString(allocator, s, input, i));
                    },
                    .Number => |n| {
                        try array.append(try p.parseNumber(n, input, i));
                    },
                    .True => {
                        try array.append(Value{ .Bool = true });
                    },
                    .False => {
                        try array.append(Value{ .Bool = false });
                    },
                    .Null => {
                        try array.append(Value.Null);
                    },
                    .ObjectEnd => {
                        unreachable;
                    },
                }
            },
            .Simple => switch (token) {
                .ObjectBegin => {
                    try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                    p.state = .ObjectKey;
                },
                .ArrayBegin => {
                    try p.stack.append(Value{ .Array = Array.init(allocator) });
                    p.state = .ArrayValue;
                },
                .String => |s| {
                    try p.stack.append(try p.parseString(allocator, s, input, i));
                },
                .Number => |n| {
                    try p.stack.append(try p.parseNumber(n, input, i));
                },
                .True => {
                    try p.stack.append(Value{ .Bool = true });
                },
                .False => {
                    try p.stack.append(Value{ .Bool = false });
                },
                .Null => {
                    try p.stack.append(Value.Null);
                },
                .ObjectEnd, .ArrayEnd => {
                    unreachable;
                },
            },
        }
    }

    fn pushToParent(p: *Parser, value: *const Value) !void {
        switch (p.stack.items[p.stack.items.len - 1]) {
            // Object Parent -> [ ..., object, <key>, value ]
            Value.String => |key| {
                _ = p.stack.pop();

                var object = &p.stack.items[p.stack.items.len - 1].Object;
                try object.put(key, value.*);
                p.state = .ObjectKey;
            },
            // Array Parent -> [ ..., <array>, value ]
            Value.Array => |*array| {
                try array.append(value.*);
                p.state = .ArrayValue;
            },
            else => {
                unreachable;
            },
        }
    }

    fn parseString(p: *Parser, allocator: Allocator, s: std.meta.TagPayload(Token, Token.String), input: []const u8, i: usize) !Value {
        const slice = s.slice(input, i);
        switch (s.escapes) {
            .None => return Value{ .String = if (p.copy_strings) try allocator.dupe(u8, slice) else slice },
            .Some => {
                const output = try allocator.alloc(u8, s.decodedLength());
                errdefer allocator.free(output);
                try unescapeValidString(output, slice);
                return Value{ .String = output };
            },
        }
    }

    fn parseNumber(p: *Parser, n: std.meta.TagPayload(Token, Token.Number), input: []const u8, i: usize) !Value {
        _ = p;
        return if (n.is_integer)
            Value{
                .Integer = std.fmt.parseInt(i64, n.slice(input, i), 10) catch |e| switch (e) {
                    error.Overflow => return Value{ .NumberString = n.slice(input, i) },
                    error.InvalidCharacter => |err| return err,
                },
            }
        else
            Value{ .Float = try std.fmt.parseFloat(f64, n.slice(input, i)) };
    }
};

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

pub const StringifyOptions = struct {
    pub const Whitespace = struct {
        /// How many indentation levels deep are we?
        indent_level: usize = 0,

        /// What character(s) should be used for indentation?
        indent: union(enum) {
            Space: u8,
            Tab: void,
            None: void,
        } = .{ .Space = 4 },

        /// After a colon, should whitespace be inserted?
        separator: bool = true,

        pub fn outputIndent(
            whitespace: @This(),
            out_stream: anytype,
        ) @TypeOf(out_stream).Error!void {
            var char: u8 = undefined;
            var n_chars: usize = undefined;
            switch (whitespace.indent) {
                .Space => |n_spaces| {
                    char = ' ';
                    n_chars = n_spaces;
                },
                .Tab => {
                    char = '\t';
                    n_chars = 1;
                },
                .None => return,
            }
            try out_stream.writeByte('\n');
            n_chars *= whitespace.indent_level;
            try out_stream.writeByteNTimes(char, n_chars);
        }
    };

    /// Controls the whitespace emitted
    whitespace: ?Whitespace = null,

    /// Should optional fields with null value be written?
    emit_null_optional_fields: bool = true,

    string: StringOptions = StringOptions{ .String = .{} },

    /// Should []u8 be serialised as a string? or an array?
    pub const StringOptions = union(enum) {
        Array,
        String: StringOutputOptions,

        /// String output options
        const StringOutputOptions = struct {
            /// Should '/' be escaped in strings?
            escape_solidus: bool = false,

            /// Should unicode characters be escaped in strings?
            escape_unicode: bool = false,
        };
    };
};

fn outputUnicodeEscape(
    codepoint: u21,
    out_stream: anytype,
) !void {
    if (codepoint <= 0xFFFF) {
        // If the character is in the Basic Multilingual Plane (U+0000 through U+FFFF),
        // then it may be represented as a six-character sequence: a reverse solidus, followed
        // by the lowercase letter u, followed by four hexadecimal digits that encode the character's code point.
        try out_stream.writeAll("\\u");
        try std.fmt.formatIntValue(codepoint, "x", std.fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
    } else {
        assert(codepoint <= 0x10FFFF);
        // To escape an extended character that is not in the Basic Multilingual Plane,
        // the character is represented as a 12-character sequence, encoding the UTF-16 surrogate pair.
        const high = @intCast(u16, (codepoint - 0x10000) >> 10) + 0xD800;
        const low = @intCast(u16, codepoint & 0x3FF) + 0xDC00;
        try out_stream.writeAll("\\u");
        try std.fmt.formatIntValue(high, "x", std.fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
        try out_stream.writeAll("\\u");
        try std.fmt.formatIntValue(low, "x", std.fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
    }
}

/// Write `string` to `writer` as a JSON encoded string.
pub fn encodeJsonString(string: []const u8, options: StringifyOptions, writer: anytype) !void {
    try writer.writeByte('\"');
    try encodeJsonStringChars(string, options, writer);
    try writer.writeByte('\"');
}

/// Write `chars` to `writer` as JSON encoded string characters.
pub fn encodeJsonStringChars(chars: []const u8, options: StringifyOptions, writer: anytype) !void {
    var i: usize = 0;
    while (i < chars.len) : (i += 1) {
        switch (chars[i]) {
            // normal ascii character
            0x20...0x21, 0x23...0x2E, 0x30...0x5B, 0x5D...0x7F => |c| try writer.writeByte(c),
            // only 2 characters that *must* be escaped
            '\\' => try writer.writeAll("\\\\"),
            '\"' => try writer.writeAll("\\\""),
            // solidus is optional to escape
            '/' => {
                if (options.string.String.escape_solidus) {
                    try writer.writeAll("\\/");
                } else {
                    try writer.writeByte('/');
                }
            },
            // control characters with short escapes
            // TODO: option to switch between unicode and 'short' forms?
            0x8 => try writer.writeAll("\\b"),
            0xC => try writer.writeAll("\\f"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                const ulen = std.unicode.utf8ByteSequenceLength(chars[i]) catch unreachable;
                // control characters (only things left with 1 byte length) should always be printed as unicode escapes
                if (ulen == 1 or options.string.String.escape_unicode) {
                    const codepoint = std.unicode.utf8Decode(chars[i .. i + ulen]) catch unreachable;
                    try outputUnicodeEscape(codepoint, writer);
                } else {
                    try writer.writeAll(chars[i .. i + ulen]);
                }
                i += ulen - 1;
            },
        }
    }
}

pub fn stringify(
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .Float, .ComptimeFloat => {
            return std.fmt.formatFloatScientific(value, std.fmt.FormatOptions{}, out_stream);
        },
        .Int, .ComptimeInt => {
            return std.fmt.formatIntValue(value, "", std.fmt.FormatOptions{}, out_stream);
        },
        .Bool => {
            return out_stream.writeAll(if (value) "true" else "false");
        },
        .Null => {
            return out_stream.writeAll("null");
        },
        .Optional => {
            if (value) |payload| {
                return try stringify(payload, options, out_stream);
            } else {
                return try stringify(null, options, out_stream);
            }
        },
        .Enum => {
            if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            @compileError("Unable to stringify enum '" ++ @typeName(T) ++ "'");
        },
        .Union => {
            if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            const info = @typeInfo(T).Union;
            if (info.tag_type) |UnionTagType| {
                try out_stream.writeByte('{');
                var child_options = options;
                if (child_options.whitespace) |*whitespace| {
                    whitespace.indent_level += 1;
                }
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        if (child_options.whitespace) |child_whitespace| {
                            try child_whitespace.outputIndent(out_stream);
                        }
                        try encodeJsonString(u_field.name, options, out_stream);
                        try out_stream.writeByte(':');
                        if (child_options.whitespace) |child_whitespace| {
                            if (child_whitespace.separator) {
                                try out_stream.writeByte(' ');
                            }
                        }
                        if (u_field.type == void) {
                            try out_stream.writeAll("{}");
                        } else {
                            try stringify(@field(value, u_field.name), child_options, out_stream);
                        }
                        break;
                    }
                } else {
                    unreachable; // No active tag?
                }
                if (options.whitespace) |whitespace| {
                    try whitespace.outputIndent(out_stream);
                }
                try out_stream.writeByte('}');
                return;
            } else {
                @compileError("Unable to stringify untagged union '" ++ @typeName(T) ++ "'");
            }
        },
        .Struct => |S| {
            if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            try out_stream.writeByte(if (S.is_tuple) '[' else '{');
            var field_output = false;
            var child_options = options;
            if (child_options.whitespace) |*child_whitespace| {
                child_whitespace.indent_level += 1;
            }
            inline for (S.fields) |Field| {
                // don't include void fields
                if (Field.type == void) continue;

                var emit_field = true;

                // don't include optional fields that are null when emit_null_optional_fields is set to false
                if (@typeInfo(Field.type) == .Optional) {
                    if (options.emit_null_optional_fields == false) {
                        if (@field(value, Field.name) == null) {
                            emit_field = false;
                        }
                    }
                }

                if (emit_field) {
                    if (!field_output) {
                        field_output = true;
                    } else {
                        try out_stream.writeByte(',');
                    }
                    if (child_options.whitespace) |child_whitespace| {
                        try child_whitespace.outputIndent(out_stream);
                    }
                    if (!S.is_tuple) {
                        try encodeJsonString(Field.name, options, out_stream);
                        try out_stream.writeByte(':');
                        if (child_options.whitespace) |child_whitespace| {
                            if (child_whitespace.separator) {
                                try out_stream.writeByte(' ');
                            }
                        }
                    }
                    try stringify(@field(value, Field.name), child_options, out_stream);
                }
            }
            if (field_output) {
                if (options.whitespace) |whitespace| {
                    try whitespace.outputIndent(out_stream);
                }
            }
            try out_stream.writeByte(if (S.is_tuple) ']' else '}');
            return;
        },
        .ErrorSet => return stringify(@as([]const u8, @errorName(value)), options, out_stream),
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .One => switch (@typeInfo(ptr_info.child)) {
                .Array => {
                    const Slice = []const std.meta.Elem(ptr_info.child);
                    return stringify(@as(Slice, value), options, out_stream);
                },
                else => {
                    // TODO: avoid loops?
                    return stringify(value.*, options, out_stream);
                },
            },
            .Many, .Slice => {
                if (ptr_info.size == .Many and ptr_info.sentinel == null)
                    @compileError("unable to stringify type '" ++ @typeName(T) ++ "' without sentinel");
                const slice = if (ptr_info.size == .Many) mem.span(value) else value;

                if (ptr_info.child == u8 and options.string == .String and std.unicode.utf8ValidateSlice(slice)) {
                    try encodeJsonString(slice, options, out_stream);
                    return;
                }

                try out_stream.writeByte('[');
                var child_options = options;
                if (child_options.whitespace) |*whitespace| {
                    whitespace.indent_level += 1;
                }
                for (slice, 0..) |x, i| {
                    if (i != 0) {
                        try out_stream.writeByte(',');
                    }
                    if (child_options.whitespace) |child_whitespace| {
                        try child_whitespace.outputIndent(out_stream);
                    }
                    try stringify(x, child_options, out_stream);
                }
                if (slice.len != 0) {
                    if (options.whitespace) |whitespace| {
                        try whitespace.outputIndent(out_stream);
                    }
                }
                try out_stream.writeByte(']');
                return;
            },
            else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
        },
        .Array => return stringify(&value, options, out_stream),
        .Vector => |info| {
            const array: [info.len]info.child = value;
            return stringify(&array, options, out_stream);
        },
        else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

// Same as `stringify` but accepts an Allocator and stores result in dynamically allocated memory instead of using a Writer.
// Caller owns returned memory.
pub fn stringifyAlloc(allocator: std.mem.Allocator, value: anytype, options: StringifyOptions) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    try stringify(value, options, list.writer());
    return list.toOwnedSlice();
}

test {
    _ = @import("json/test.zig");
    _ = @import("json/scanner.zig");
    _ = @import("json/write_stream.zig");
}

const testing = std.testing;

test "stringify null optional fields" {
    const MyStruct = struct {
        optional: ?[]const u8 = null,
        required: []const u8 = "something",
        another_optional: ?[]const u8 = null,
        another_required: []const u8 = "something else",
    };
    try teststringify(
        \\{"optional":null,"required":"something","another_optional":null,"another_required":"something else"}
    ,
        MyStruct{},
        StringifyOptions{},
    );
    try teststringify(
        \\{"required":"something","another_required":"something else"}
    ,
        MyStruct{},
        StringifyOptions{ .emit_null_optional_fields = false },
    );
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

test "stringify basic types" {
    try teststringify("false", false, StringifyOptions{});
    try teststringify("true", true, StringifyOptions{});
    try teststringify("null", @as(?u8, null), StringifyOptions{});
    try teststringify("null", @as(?*u32, null), StringifyOptions{});
    try teststringify("42", 42, StringifyOptions{});
    try teststringify("4.2e+01", 42.0, StringifyOptions{});
    try teststringify("42", @as(u8, 42), StringifyOptions{});
    try teststringify("42", @as(u128, 42), StringifyOptions{});
    try teststringify("4.2e+01", @as(f32, 42), StringifyOptions{});
    try teststringify("4.2e+01", @as(f64, 42), StringifyOptions{});
    try teststringify("\"ItBroke\"", @as(anyerror, error.ItBroke), StringifyOptions{});
}

test "stringify string" {
    try teststringify("\"hello\"", "hello", StringifyOptions{});
    try teststringify("\"with\\nescapes\\r\"", "with\nescapes\r", StringifyOptions{});
    try teststringify("\"with\\nescapes\\r\"", "with\nescapes\r", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\\u0001\"", "with unicode\u{1}", StringifyOptions{});
    try teststringify("\"with unicode\\u0001\"", "with unicode\u{1}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{80}\"", "with unicode\u{80}", StringifyOptions{});
    try teststringify("\"with unicode\\u0080\"", "with unicode\u{80}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{FF}\"", "with unicode\u{FF}", StringifyOptions{});
    try teststringify("\"with unicode\\u00ff\"", "with unicode\u{FF}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{100}\"", "with unicode\u{100}", StringifyOptions{});
    try teststringify("\"with unicode\\u0100\"", "with unicode\u{100}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{800}\"", "with unicode\u{800}", StringifyOptions{});
    try teststringify("\"with unicode\\u0800\"", "with unicode\u{800}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{8000}\"", "with unicode\u{8000}", StringifyOptions{});
    try teststringify("\"with unicode\\u8000\"", "with unicode\u{8000}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{D799}\"", "with unicode\u{D799}", StringifyOptions{});
    try teststringify("\"with unicode\\ud799\"", "with unicode\u{D799}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{10000}\"", "with unicode\u{10000}", StringifyOptions{});
    try teststringify("\"with unicode\\ud800\\udc00\"", "with unicode\u{10000}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{10FFFF}\"", "with unicode\u{10FFFF}", StringifyOptions{});
    try teststringify("\"with unicode\\udbff\\udfff\"", "with unicode\u{10FFFF}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"/\"", "/", StringifyOptions{});
    try teststringify("\"\\/\"", "/", StringifyOptions{ .string = .{ .String = .{ .escape_solidus = true } } });
}

test "stringify many-item sentinel-terminated string" {
    try teststringify("\"hello\"", @as([*:0]const u8, "hello"), StringifyOptions{});
    try teststringify("\"with\\nescapes\\r\"", @as([*:0]const u8, "with\nescapes\r"), StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\\u0001\"", @as([*:0]const u8, "with unicode\u{1}"), StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
}

test "stringify tagged unions" {
    const T = union(enum) {
        nothing,
        foo: u32,
        bar: bool,
    };
    try teststringify("{\"nothing\":{}}", T{ .nothing = {}}, StringifyOptions{});
    try teststringify("{\"foo\":42}", T{ .foo = 42 }, StringifyOptions{});
    try teststringify("{\"bar\":true}", T{ .bar = true }, StringifyOptions{});
}

test "stringify struct" {
    try teststringify("{\"foo\":42}", struct {
        foo: u32,
    }{ .foo = 42 }, StringifyOptions{});
}

test "stringify struct with string as array" {
    try teststringify("{\"foo\":\"bar\"}", .{ .foo = "bar" }, StringifyOptions{});
    try teststringify("{\"foo\":[98,97,114]}", .{ .foo = "bar" }, StringifyOptions{ .string = .Array });
}

test "stringify struct with indentation" {
    try teststringify(
        \\{
        \\    "foo": 42,
        \\    "bar": [
        \\        1,
        \\        2,
        \\        3
        \\    ]
        \\}
    ,
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        StringifyOptions{
            .whitespace = .{},
        },
    );
    try teststringify(
        "{\n\t\"foo\":42,\n\t\"bar\":[\n\t\t1,\n\t\t2,\n\t\t3\n\t]\n}",
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        StringifyOptions{
            .whitespace = .{
                .indent = .Tab,
                .separator = false,
            },
        },
    );
    try teststringify(
        \\{"foo":42,"bar":[1,2,3]}
    ,
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        StringifyOptions{
            .whitespace = .{
                .indent = .None,
                .separator = false,
            },
        },
    );
}

test "stringify struct with void field" {
    try teststringify("{\"foo\":42}", struct {
        foo: u32,
        bar: void = {},
    }{ .foo = 42 }, StringifyOptions{});
}

test "stringify array of structs" {
    const MyStruct = struct {
        foo: u32,
    };
    try teststringify("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
        MyStruct{ .foo = 42 },
        MyStruct{ .foo = 100 },
        MyStruct{ .foo = 1000 },
    }, StringifyOptions{});
}

test "stringify struct with custom stringifier" {
    try teststringify("[\"something special\",42]", struct {
        foo: u32,
        const Self = @This();
        pub fn jsonStringify(
            value: Self,
            options: StringifyOptions,
            out_stream: anytype,
        ) !void {
            _ = value;
            try out_stream.writeAll("[\"something special\",");
            try stringify(42, options, out_stream);
            try out_stream.writeByte(']');
        }
    }{ .foo = 42 }, StringifyOptions{});
}

test "stringify vector" {
    try teststringify("[1,1]", @splat(2, @as(u32, 1)), StringifyOptions{});
}

test "stringify tuple" {
    try teststringify("[\"foo\",42]", std.meta.Tuple(&.{ []const u8, usize }){ "foo", 42 }, StringifyOptions{});
}

fn teststringify(expected: []const u8, value: anytype, options: StringifyOptions) !void {
    const ValidationWriter = struct {
        const Self = @This();
        pub const Writer = std.io.Writer(*Self, Error, write);
        pub const Error = error{
            TooMuchData,
            DifferentData,
        };

        expected_remaining: []const u8,

        fn init(exp: []const u8) Self {
            return .{ .expected_remaining = exp };
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        fn write(self: *Self, bytes: []const u8) Error!usize {
            if (self.expected_remaining.len < bytes.len) {
                std.debug.print(
                    \\====== expected this output: =========
                    \\{s}
                    \\======== instead found this: =========
                    \\{s}
                    \\======================================
                , .{
                    self.expected_remaining,
                    bytes,
                });
                return error.TooMuchData;
            }
            if (!mem.eql(u8, self.expected_remaining[0..bytes.len], bytes)) {
                std.debug.print(
                    \\====== expected this output: =========
                    \\{s}
                    \\======== instead found this: =========
                    \\{s}
                    \\======================================
                , .{
                    self.expected_remaining[0..bytes.len],
                    bytes,
                });
                return error.DifferentData;
            }
            self.expected_remaining = self.expected_remaining[bytes.len..];
            return bytes.len;
        }
    };

    var vos = ValidationWriter.init(expected);
    try stringify(value, options, vos.writer());
    if (vos.expected_remaining.len > 0) return error.NotEnoughData;
}

test "encodesTo" {
    // same
    try testing.expectEqual(true, encodesTo("false", "false"));
    // totally different
    try testing.expectEqual(false, encodesTo("false", "true"));
    // different lengths
    try testing.expectEqual(false, encodesTo("false", "other"));
    // with escape
    try testing.expectEqual(true, encodesTo("\\", "\\\\"));
    try testing.expectEqual(true, encodesTo("with\nescape", "with\\nescape"));
    // with unicode
    try testing.expectEqual(true, encodesTo("ą", "\\u0105"));
    try testing.expectEqual(true, encodesTo("😂", "\\ud83d\\ude02"));
    try testing.expectEqual(true, encodesTo("withąunicode😂", "with\\u0105unicode\\ud83d\\ude02"));
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

test "stringify struct with custom stringify that returns a custom error" {
    var ret = stringify(struct {
        field: Field = .{},

        pub const Field = struct {
            field: ?[]*Field = null,

            const Self = @This();
            pub fn jsonStringify(_: Self, _: StringifyOptions, _: anytype) error{CustomError}!void {
                return error.CustomError;
            }
        };
    }{}, StringifyOptions{}, std.io.null_writer);

    try std.testing.expectError(error.CustomError, ret);
}
