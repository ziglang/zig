const std = @import("std");

const debug = std.debug;
const mem = std.mem;
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
    switch(@typeInfo(T)){
        .Union => |unionInfo| {
            if(unionInfo.decls.len == 1 and comptime mem.eql(u8, unionInfo.decls[0].name, "__maybe_defined")){
                return unionInfo.fields[1].field_type;
            } else {
                return null;
            }
        },
        else => return null
    }
}

pub fn serialize(value: var, stream: var) !void {
    comptime const valueType = @typeOf(value);
    comptime const info = @typeInfo(valueType);
    
    if(valueType == json.Value){
        try value.dumpStream(stream, 1024);
        return;
    }

    switch(info){
        .Null => {
            try stream.write("null");
        },
        .Int, .ComptimeInt, .Float, .ComptimeFloat, .Bool => {
            try stream.print("{}", value);
        },
        .Pointer => |ptrInfo| {
            if(ptrInfo.child == u8){
                try stream.print("\"{}\"", value);
            } else {
                try stream.write("[");
                for(value) |item, index| {
                    try serialize(item, stream);
                    if(index != value.len - 1){
                        try stream.write(",");
                    }
                }
                try stream.write("]");
            }
        },
        .Struct => |structInfo| {
            try stream.write("{");
            var firstProp: bool = true;
            inline for(structInfo.fields) |field, index| {
                if(getMaybeDefinedChildType(field.field_type) != null) {
                    if(@field(value, field.name) == .Defined) {
                        if(!firstProp){
                            try stream.write(",");
                        }

                        try stream.write("\"" ++ field.name ++ "\":");
                        try serialize(@field(value, field.name).Defined, stream);
                        firstProp = false;
                    }
                } else {
                    if(!firstProp){
                        try stream.write(",");
                    }

                    try stream.write("\"" ++ field.name ++ "\":");
                    try serialize(@field(value, field.name), stream);
                    firstProp = false;
                }
            }
            try stream.write("}");
        },
        .Optional => {
            if(value == null){
                try stream.write("null");
            } else {
                try serialize(value.?, stream);
            }
        },
        else => {
            @compileError("JSON serialize: Unsupported type: " ++ @typeName(valueType));
        },
    }
}


pub fn serialize2(value: var, alloc: *mem.Allocator) mem.Allocator.Error!json.Value {
    comptime const valueType = @typeOf(value);
    comptime const info = @typeInfo(valueType);
    
    if(valueType == json.Value){
        return value;
    }

    switch(info){
        .Null => {
            return json.Value{.Null={}};
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
            if(ptrInfo.size != .Slice){
                @compileError("JSON deserialize: Unsupported pointer type: " ++ @typeName(T));
            }
            if(ptrInfo.child == u8){
                return json.Value{ .String = value };
            } else {
                var arr = json.Value{ .Array = json.Array.init(alloc) };
                for(value) |item, index| {
                    try arr.Array.append(try serialize2(item, alloc));
                }
                return arr;
            }
        },
        .Struct => |structInfo| {
            var obj = json.Value{ .Object = json.ObjectMap.init(alloc) };
            inline for(structInfo.fields) |field, index| {
                if(getMaybeDefinedChildType(field.field_type) != null) {
                    if(@field(value, field.name) == .Defined) {
                        try obj.Object.putNoClobber(field.name, try serialize2(@field(value, field.name).Defined, alloc));
                    }
                } else {
                    try obj.Object.putNoClobber(field.name, try serialize2(@field(value, field.name), alloc));
                }
            }
            return obj;
        },
        .Optional => {
            if(value == null){
                return json.Value{.Null={}};
            } else {
                return try serialize2(value.?, alloc);
            }
        },
        else => {
            @compileError("JSON serialize: Unsupported type: " ++ @typeName(valueType));
        },
    }
}

pub const DeserializeError = error{
    InvalidType,
    MissingField
} || mem.Allocator.Error;

pub fn deserialize(comptime T: type, value: json.Value, alloc: *mem.Allocator) DeserializeError!T {
    comptime const info = @typeInfo(T);

    if(T == json.Value){
        return value;
    }

    switch(info){
        .Int => {
            if(value != .Integer){
                return error.InvalidType;
            }
            return value.Integer;
        },
        .Float => {
            if(value != .Float){
                return error.InvalidType;
            }
            return value.Float;
        },
        .Bool => {
            if(value != .Bool){
                return error.InvalidType;
            }
            return value.Bool;
        },
        .Pointer => |ptrInfo| {
            if(ptrInfo.size != .Slice){
                @compileError("JSON deserialize: Unsupported pointer type: " ++ @typeName(T));
            }
            if(ptrInfo.child == u8 and ptrInfo.is_const){
                if(value != .String){
                    return error.InvalidType;
                }
                return value.String;
            } else {
                if(value != .Array){
                    return error.InvalidType;
                }
                var arr: T = try alloc.alloc(ptrInfo.child, value.Array.len);
                for(value.Array.toSlice()) |item, index| {
                    arr[index] = try deserialize(ptrInfo.child, item, alloc);
                }
                return arr;
            }
        },
        .Struct => |structInfo| {
            if(value != .Object){
                return error.InvalidType;
            }
            var obj: T = undefined;
            inline for(structInfo.fields) |field, index| {
                if(getMaybeDefinedChildType(field.field_type)) |childType| {
                    if(value.Object.getValue(field.name)) |fieldVal| {
                        @field(obj, field.name) = MaybeDefined(childType){ .Defined = try deserialize(childType, fieldVal, alloc) };
                    } else {
                        @field(obj, field.name) = MaybeDefined(childType).NotDefined;
                    }
                } else {
                    @field(obj, field.name) = try deserialize(field.field_type, value.Object.getValue(field.name) orelse return error.MissingField, alloc);
                }
            }
            return obj;
        },
        .Optional => |optionalInfo| {
            if(value == .Null){
                return null;
            } else {
                return try deserialize(optionalInfo.child, value, alloc);
            }
        },
        else => {
            @compileError("JSON deserialize: Unsupported type: " ++ @typeName(T));
        },
    }
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
        maybeNull3: MaybeDefined(?i64)
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

    debug.warn("\n{}, arr = ", testOut);
    for(testOut.arr) |b| {
        debug.warn("{}, ", b);
    }
    debug.warn("\n");

    expect(testOut.maybeNull1.Defined.? == 42);
    expect(testOut.maybeNull2.Defined == null);
    expect(testOut.maybeNull3 == .NotDefined);

    _ = try serialize2(testOut, debug.global_allocator);
}
