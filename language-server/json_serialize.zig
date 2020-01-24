const std = @import("std");

const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const json = std.json;
const expect = std.testing.expect;

pub fn MaybeDefined(comptime T: type) type {
    return union(enum) {
        NotDefined,
        Defined: T,

        const __maybe_defined = void;
    };
}

fn getMaybeDefinedChildType(comptime T: type) ?type {
    switch (@typeInfo(T)) {
        .Union => |unionInfo| {
            if (unionInfo.decls.len == 1 and comptime mem.eql(u8, unionInfo.decls[0].name, "__maybe_defined")) {
                return unionInfo.fields[1].field_type;
            } else {
                return null;
            }
        },
        else => return null,
    }
}

pub const Structured = union(enum) {
    Array: json.Array,
    Object: json.ObjectMap,
};

pub const Primitive = union(enum) {
    Bool: bool,
    Integer: i64,
    Float: f64,
    String: []const u8,
};

pub const Number = union(enum) {
    Integer: i64,
    Float: f64,
};

/// jsonStream must be a pointer to std.json.WriteStream
pub fn serialize(value: var, jsonStream: var) !void {
    comptime const valueType = @TypeOf(value);
    comptime const info = @typeInfo(valueType);

    if (valueType == json.Value) {
        try jsonStream.emitJson(value);
        return;
    }

    switch (info) {
        .Null => {
            try jsonStream.emitNull();
        },
        .Int, .ComptimeInt, .Float, .ComptimeFloat => {
            try jsonStream.emitNumber(value);
        },
        .Bool => {
            try jsonStream.emitBool(value);
        },
        .Pointer => |ptrInfo| {
            if (ptrInfo.child == u8) {
                try jsonStream.emitString(value);
            } else {
                try jsonStream.beginArray();
                for (value) |item, index| {
                    try jsonStream.arrayElem();
                    try serialize(item, jsonStream);
                }
                try jsonStream.endArray();
            }
        },
        .Struct => |structInfo| {
            try jsonStream.beginObject();

            inline for (structInfo.fields) |field, index| {
                if (getMaybeDefinedChildType(field.field_type) != null) {
                    if (@field(value, field.name) == .Defined) {
                        try jsonStream.objectField(field.name);
                        try serialize(@field(value, field.name).Defined, jsonStream);
                    }
                } else {
                    try jsonStream.objectField(field.name);
                    try serialize(@field(value, field.name), jsonStream);
                }
            }
            try jsonStream.endObject();
        },
        .Optional => {
            if (value) |notNull| {
                try serialize(notNull, jsonStream);
            } else {
                try jsonStream.emitNull();
            }
        },
        .Union => |unionInfo| {
            if (unionInfo.tag_type) |tagType| {
                inline for (unionInfo.fields) |field| {
                    if (@enumToInt(@as(tagType, value)) == field.enum_field.?.value) {
                        return try serialize(@field(value, field.name), jsonStream);
                    }
                }
                unreachable;
            } else {
                @compileError("JSON serialize: Unsupported untagged union type: " ++ @typeName(T));
            }
        },
        else => {
            @compileError("JSON serialize: Unsupported type: " ++ @typeName(valueType));
        },
    }
}

pub fn serialize2(value: var, alloc: *mem.Allocator) mem.Allocator.Error!json.ValueTree {
    var arena = heap.ArenaAllocator.init(alloc);
    errdefer arena.deinit();

    return json.ValueTree{
        .root = try serialize2Impl(value, &arena.allocator),
        .arena = arena,
    };
}

fn serialize2Impl(value: var, alloc: *mem.Allocator) mem.Allocator.Error!json.Value {
    comptime const valueType = @TypeOf(value);
    comptime const info = @typeInfo(valueType);

    if (valueType == json.Value) {
        return value;
    }

    switch (info) {
        .Null => {
            return json.Value{ .Null = {} };
        },
        .Int, .ComptimeInt => {
            return json.Value{ .Integer = value };
        },
        .Float, .ComptimeFloat => {
            return json.Value{ .Float = value };
        },
        .Bool => {
            return json.Value{ .Bool = value };
        },
        .Pointer => |ptrInfo| {
            if (ptrInfo.size != .Slice) {
                @compileError("JSON deserialize: Unsupported pointer type: " ++ @typeName(T));
            }
            if (ptrInfo.child == u8) {
                return json.Value{ .String = value };
            } else {
                var arr = json.Value{ .Array = json.Array.init(alloc) };
                for (value) |item, index| {
                    try arr.Array.append(try serialize2Impl(item, alloc));
                }
                return arr;
            }
        },
        .Struct => |structInfo| {
            var obj = json.Value{ .Object = json.ObjectMap.init(alloc) };
            inline for (structInfo.fields) |field, index| {
                if (getMaybeDefinedChildType(field.field_type) != null) {
                    if (@field(value, field.name) == .Defined) {
                        try obj.Object.putNoClobber(field.name, try serialize2Impl(@field(value, field.name).Defined, alloc));
                    }
                } else {
                    try obj.Object.putNoClobber(field.name, try serialize2Impl(@field(value, field.name), alloc));
                }
            }
            return obj;
        },
        .Optional => {
            if (value) |notNull| {
                return try serialize2Impl(notNull, alloc);
            } else {
                return json.Value{ .Null = {} };
            }
        },
        .Union => |unionInfo| {
            if (unionInfo.tag_type) |tagType| {
                inline for (unionInfo.fields) |field| {
                    if (@enumToInt(@as(tagType, value)) == field.enum_field.?.value) {
                        return try serialize2Impl(@field(value, field.name), alloc);
                    }
                }
                unreachable;
            } else {
                @compileError("JSON serialize: Unsupported untagged union type: " ++ @typeName(T));
            }
        },
        else => {
            @compileError("JSON serialize: Unsupported type: " ++ @typeName(valueType));
        },
    }
}

pub const DeserializeError = error{
    InvalidType,
    MissingField,
} || mem.Allocator.Error;

pub const DeserializeOptions = struct {
    copyStrings: bool,
    undefinedToNull: bool,
    allowExtraFields: bool,
};

pub fn DeserializeResult(comptime T: type) type {
    return struct {
        result: T,
        arena: heap.ArenaAllocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
        }
    };
}

/// Unions are tried to be filled with first matching json.Value type
pub fn deserialize(comptime T: type, value: json.Value, alloc: *mem.Allocator) DeserializeError!DeserializeResult(T) {
    var arena = heap.ArenaAllocator.init(alloc);
    errdefer arena.deinit();

    return DeserializeResult(T){
        .result = try deserializeImpl(T, value, &arena.allocator),
        .arena = arena,
    };
}

fn deserializeImpl(comptime T: type, value: json.Value, alloc: *mem.Allocator) DeserializeError!T {
    comptime const info = @typeInfo(T);

    if (T == json.Value) {
        return value;
    }

    switch (info) {
        .Int => {
            if (value != .Integer) {
                return error.InvalidType;
            }
            return value.Integer;
        },
        .Float => {
            if (value != .Float) {
                return error.InvalidType;
            }
            return value.Float;
        },
        .Bool => {
            if (value != .Bool) {
                return error.InvalidType;
            }
            return value.Bool;
        },
        .Pointer => |ptrInfo| {
            if (ptrInfo.size != .Slice) {
                @compileError("JSON deserialize: Unsupported pointer type: " ++ @typeName(T));
            }
            if (ptrInfo.child == u8 and ptrInfo.is_const) {
                if (value != .String) {
                    return error.InvalidType;
                }
                return value.String;
            } else {
                if (value != .Array) {
                    return error.InvalidType;
                }
                var arr: T = try alloc.alloc(ptrInfo.child, value.Array.len);
                for (value.Array.toSlice()) |item, index| {
                    arr[index] = try deserializeImpl(ptrInfo.child, item, alloc);
                }
                return arr;
            }
        },
        .Struct => |structInfo| {
            if (value != .Object) {
                return error.InvalidType;
            }
            var obj: T = undefined;
            inline for (structInfo.fields) |field, index| {
                if (getMaybeDefinedChildType(field.field_type)) |childType| {
                    if (value.Object.getValue(field.name)) |fieldVal| {
                        @field(obj, field.name) = MaybeDefined(childType){ .Defined = try deserializeImpl(childType, fieldVal, alloc) };
                    } else {
                        @field(obj, field.name) = MaybeDefined(childType).NotDefined;
                    }
                } else {
                    @field(obj, field.name) = try deserializeImpl(field.field_type, value.Object.getValue(field.name) orelse return error.MissingField, alloc);
                }
            }
            return obj;
        },
        .Optional => |optionalInfo| {
            if (value == .Null) {
                return null;
            } else {
                return try deserializeImpl(optionalInfo.child, value, alloc);
            }
        },
        .Union => |unionInfo| {
            if (unionInfo.tag_type) |_| {
                inline for (unionInfo.fields) |field| {
                    if (typesMatch(field.field_type, value)) {
                        const successOrError = deserializeImpl(field.field_type, value, alloc);

                        if (successOrError) |success| {
                            return @unionInit(T, field.enum_field.?.name, success);
                        } else |err| {
                            // if it's just a type error try the next type in the union
                            if (err != error.InvalidType and err != error.MissingField) {
                                return err;
                            }
                        }
                    }
                }
                return error.InvalidType;
            } else {
                @compileError("JSON deserialize: Unsupported untagged union type: " ++ @typeName(T));
            }
        },
        else => {
            @compileError("JSON deserialize: Unsupported type: " ++ @typeName(T));
        },
    }
}

fn typesMatch(comptime fieldType: type, jsonTag: @TagType(json.Value)) bool {
    const info = @typeInfo(fieldType);

    switch (jsonTag) {
        .Null => unreachable, // null is handled by optionals
        .Bool => {
            return info == .Bool;
        },
        .Integer => {
            return info == .Int;
        },
        .Float => {
            return info == .Float;
        },
        .String => {
            return isStringType(fieldType);
        },
        .Array => {
            return info == .Pointer and info.Pointer.size == .Slice and !isStringType(fieldType);
        },
        .Object => {
            return info == .Struct;
        },
    }
}

fn isStringType(comptime fieldType: type) bool {
    return switch (@typeInfo(fieldType)) {
        .Pointer => |ptr| ptr.size == .Slice and ptr.child == u8 and ptr.is_const,
        else => false,
    };
}

test "deserialize" {
    const Test = struct {
        int: i64,
        arr: []?bool,
        str: []const u8,
        maybe1: MaybeDefined(i64),
        maybe2: MaybeDefined(i64),
        maybeNull1: MaybeDefined(?i64),
        maybeNull2: MaybeDefined(?i64),
        maybeNull3: MaybeDefined(?i64),
    };

    const in =
        \\{
        \\    "int": 8,
        \\    "somethingUnexpected": 12,
        \\    "arr": [null, true, false],
        \\    "str": "str",
        \\    "maybe1": 42,
        \\    "maybeNull1": 42,
        \\    "maybeNull2": null
        \\}
    ;

    var parser = json.Parser.init(debug.global_allocator, false);
    defer parser.deinit();

    var tree = try parser.parse(in);
    defer tree.deinit();

    const testOut = try deserialize(Test, tree.root, debug.global_allocator);

    expect(testOut.maybeNull1.Defined.? == 42);
    expect(testOut.maybeNull2.Defined == null);
    expect(testOut.maybeNull3 == .NotDefined);

    _ = try serialize2(testOut, debug.global_allocator);
}
