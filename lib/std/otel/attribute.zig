const attribute = @This();

pub const Attribute = union(enum) {
    standard: attribute.Standard,
    dynamic: attribute.Dynamic,

    pub const Type = attribute.Type;
    pub const Dynamic = attribute.Dynamic;
    pub const Standard = attribute.Standard;

    pub fn listFromStruct(attributes: anytype) [@typeInfo(@TypeOf(attributes)).@"struct".fields.len]Attribute {
        const struct_info = @typeInfo(@TypeOf(attributes)).@"struct";
        const num_attributes = struct_info.fields.len;

        var attrs: [num_attributes]Attribute = undefined;
        inline for (attrs[0..], struct_info.fields) |*attr, field| {
            if (@hasField(attribute.Standard, field.name)) {
                attr.* = .{ .standard = @unionInit(attribute.Standard, field.name, @field(attributes, field.name)) };
            } else {
                attr.* = .{ .dynamic = .{
                    .key = field.name,
                    .value = attribute.Dynamic.Value.fromType(field.type, @field(attributes, field.name)),
                } };
            }
        }

        return attrs;
    }

    pub fn listFromSourceLocation(src: std.builtin.SourceLocation) [4]Attribute {
        return [4]Attribute{
            .{ .standard = .{ .@"code.filepath" = src.file } },
            .{ .standard = .{ .@"code.function" = src.fn_name } },
            .{ .standard = .{ .@"code.lineno" = src.line } },
            .{ .standard = .{ .@"code.column" = src.column } },
        };
    }

    pub fn jsonStringify(this: @This(), jw: anytype) !void {
        switch (this) {
            .dynamic => |dyn| try jw.write(dyn),
            .standard => |standard| try standard.jsonStringify(jw),
        }
    }
};

pub const Type = enum {
    // ------ primitive types ------

    string,
    boolean,
    double,
    integer,

    // --- primitive array types ---

    string_array,
    boolean_array,
    double_array,
    integer_array,
};

/// This type makes no claims about data ownership. See attribute.Set for a type that owns its data.
pub const Dynamic = struct {
    key: []const u8,
    value: Value,

    pub const Value = union(Type) {
        // ------ primitive types ------

        string: []const u8,
        boolean: bool,
        double: f64,
        integer: i64,

        // --- primitive array types ---

        string_array: []const []const u8,
        boolean_array: []const bool,
        double_array: []const f64,
        integer_array: []const i64,

        pub fn fromType(T: type, val: T) @This() {
            switch (T) {
                []const u8 => return .{ .string = val },
                bool => return .{ .boolean = val },
                f16, f32, f64, comptime_float => return .{ .double = val },
                i32, i64, comptime_int => return .{ .integer = val },

                []const []const u8 => return .{ .string_array = val },
                []const bool => return .{ .boolean_array = val },
                []const f64 => return .{ .double_array = val },
                []const i64, []const comptime_int => return .{ .integer_array = val },
                else => switch (@typeInfo(T)) {
                    // enums are string encoded
                    .@"enum" => return .{ .string = @tagName(val) },
                    .int => |int_info| if ((int_info.signedness == .signed and int_info.bits <= 64) or (int_info.signedness == .unsigned and int_info.bits <= 63)) {
                        return .{ .integer = val };
                    } else @compileError("unsupported integer " ++ @typeName(T) ++ ", must fit into an i64"),

                    else => @compileError("unsupported type " ++ @typeName(T)),
                },
            }
        }

        pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            switch (value) {
                .string => |s| try writer.print("{}", .{std.zig.fmtEscapes(s)}),
                .boolean => |b| try writer.print("{}", .{b}),
                .double => |d| try writer.print("{e}", .{d}),
                .integer => |i| try writer.print("{}", .{i}),

                .string_array => |array| {
                    try writer.writeAll("{");
                    for (array) |string| {
                        try writer.print(" \"{}\"", .{std.zig.fmtEscapes(string)});
                    }
                    try writer.writeAll(" }");
                },
                .boolean_array => |array| {
                    try writer.writeAll("{");
                    for (array) |boolean| {
                        try writer.print(" {}", .{boolean});
                    }
                    try writer.writeAll(" }");
                },
                .double_array => |array| {
                    try writer.writeAll("{");
                    for (array) |double| {
                        try writer.print(" {e}", .{double});
                    }
                    try writer.writeAll(" }");
                },
                .integer_array => |array| {
                    try writer.writeAll("{");
                    for (array) |integer| {
                        try writer.print(" {d}", .{integer});
                    }
                    try writer.writeAll(" }");
                },
            }
        }

        pub fn jsonStringify(this: @This(), jw: anytype) !void {
            try jw.beginObject();
            switch (this) {
                .string => |s| {
                    try jw.objectField("stringValue");
                    try jw.write(s);
                },
                .boolean => |b| {
                    try jw.objectField("boolValue");
                    try jw.write(b);
                },
                .double => |d| {
                    try jw.objectField("doubleValue");
                    try jw.write(d);
                },
                .integer => |i| {
                    try jw.objectField("intValue");
                    try jw.write(i);
                },
                .string_array => |array| {
                    try jw.objectField("arrayValue");
                    try jw.beginObject();
                    try jw.objectField("values");
                    try jw.beginArray();
                    for (array) |string| {
                        try jw.write(Value{ .string = string });
                    }
                    try jw.endArray();
                    try jw.endObject();
                },
                .boolean_array => |array| {
                    try jw.objectField("arrayValue");
                    try jw.beginObject();
                    try jw.objectField("values");
                    try jw.beginArray();
                    for (array) |boolean| {
                        try jw.write(Value{ .boolean = boolean });
                    }
                    try jw.endArray();
                    try jw.endObject();
                },
                .double_array => |array| {
                    try jw.objectField("arrayValue");
                    try jw.beginObject();
                    try jw.objectField("values");
                    try jw.beginArray();
                    for (array) |double| {
                        try jw.write(Value{ .double = double });
                    }
                    try jw.endArray();
                    try jw.endObject();
                },
                .integer_array => |array| {
                    try jw.objectField("arrayValue");
                    try jw.beginObject();
                    try jw.objectField("values");
                    try jw.beginArray();
                    for (array) |integer| {
                        try jw.write(Value{ .integer = integer });
                    }
                    try jw.endArray();
                    try jw.endObject();
                },
            }
            try jw.endObject();
        }
    };

    pub fn format(attr: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}={}", .{ attr.key, attr.value });
    }
};

/// Standard Attribute names.
///
/// Is a 31-bit integer for `Attribute.Set`. This allows using one bit of a 32-bit integer to both
/// reference standard attribute names and index into a string table for custom attribute names.
pub const Standard = union(enum(u31)) {
    pub const Name = std.meta.Tag(Standard);

    // --- service group (stable) ---
    @"service.name": []const u8,
    @"service.version": []const u8,

    // --- telemetry group (stable) ---

    @"telemetry.sdk.language": []const u8,
    @"telemetry.sdk.name": []const u8,
    @"telemetry.sdk.version": []const u8,

    // --- server group (stable) ---
    @"server.address": []const u8,
    @"server.port": i64,

    // --- client group (stable) ---

    @"client.address": []const u8,
    @"client.port": i64,

    // --- network group (stable) ---

    @"network.local.address": []const u8,
    @"network.local.port": i64,
    @"network.peer.address": []const u8,
    @"network.peer.port": i64,
    @"network.protocol.name": []const u8,
    @"network.protocol.version": []const u8,
    /// Should be serialized as a string.
    @"network.transport": enum {
        pipe,
        tcp,
        udp,
        unix,
    },
    @"network.type": enum {
        ipv4,
        ipv6,
    },

    // ---- code group (experimental) ----

    /// (experimental) The source code file name that identifies the code unit as
    /// uniquely as possible (preferably an absolute file path).
    @"code.filepath": []const u8,
    /// (experimental)
    @"code.function": []const u8,
    /// (experimental) The line number in code.filepath best representing the operation.
    /// It SHOULD point within the code unit named in code.function.
    @"code.lineno": i64,
    /// (experimental) The column number in code.filepath best representing the
    /// operation. It SHOULD point within the code unit named in code.function.
    @"code.column": i64,
    /// (experimental)
    @"code.namespace": []const u8,
    /// (experimental)
    @"code.stacktrace": []const u8,

    // ------ error group ------

    @"error.type": []const u8,

    // ------ exception group ------

    /// The exception message.
    @"exception.message": []const u8,
    /// The exceptions type. We use the error for this in Zig.
    @"exception.type": []const u8,
    @"exception.escaped": bool,
    /// SHOULD be set to true if the exception event is recorded at a point where it is
    /// known that the exception is escaping the scope of the span.
    ///
    /// An exception is considered to have escaped (or left) the scope of a span, if that
    /// span is ended while the exception is still logically “in flight”. This may be
    /// actually “in flight” in some languages (e.g. if the exception is passed to a
    /// Context manager’s __exit__ method in Python) but will usually be caught at the
    /// point of recording the exception in most languages.
    @"exception.stacktrace": []const u8,

    // ------ http group ------

    /// Should be serialized as a string. "_OTHER" is used for unknown http methods.
    @"http.request.method": std.http.Method,
    @"http.request.method_original": []const u8,
    /// [HTTP response status code](https://datatracker.ietf.org/doc/html/rfc7231#section-6)
    @"http.request.status_code": i64,
    @"http.request.resend_count": i64,

    // ------ url group ------

    @"url.full": []const u8,
    @"url.scheme": []const u8,
    @"url.path": []const u8,
    @"url.query": []const u8,
    @"url.fragment": []const u8,

    // ------ user_agent group ------

    @"user_agent.original": []const u8,

    pub fn asDynamicValue(this: @This()) Dynamic.Value {
        switch (this) {
            inline else => |val| return Dynamic.Value.fromType(@TypeOf(val), val),
        }
    }

    pub fn jsonStringify(this: @This(), jw: anytype) !void {
        try jw.beginObject();

        try jw.objectField("key");
        try jw.write(@tagName(this));

        try jw.objectField("value");
        try jw.write(this.asDynamicValue());

        try jw.endObject();
    }
};

const std = @import("../std.zig");
