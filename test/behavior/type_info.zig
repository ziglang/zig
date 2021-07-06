const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;

const TypeInfo = std.builtin.TypeInfo;
const TypeId = std.builtin.TypeId;

const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

test "type info: tag type, void info" {
    try testBasic();
    comptime try testBasic();
}

fn testBasic() !void {
    try expectEqual(@typeInfo(TypeInfo).Union.tag_type, TypeId);
    const void_info = @typeInfo(void);
    try expectEqual(void_info, TypeId.Void);
    try expectEqual(void_info.Void, {});
}

test "type info: integer, floating point type info" {
    try testIntFloat();
    comptime try testIntFloat();
}

fn testIntFloat() !void {
    const u8_info = @typeInfo(u8);
    try expectEqual(u8_info, .Int);
    try expectEqual(u8_info.Int.signedness, .unsigned);
    try expectEqual(u8_info.Int.bits, 8);

    const f64_info = @typeInfo(f64);
    try expectEqual(f64_info, .Float);
    try expectEqual(f64_info.Float.bits, 64);
}

test "type info: pointer type info" {
    try testPointer();
    comptime try testPointer();
}

fn testPointer() !void {
    const u32_ptr_info = @typeInfo(*u32);
    try expectEqual(u32_ptr_info, .Pointer);
    try expectEqual(u32_ptr_info.Pointer.size, TypeInfo.Pointer.Size.One);
    try expectEqual(u32_ptr_info.Pointer.is_const, false);
    try expectEqual(u32_ptr_info.Pointer.is_volatile, false);
    try expectEqual(u32_ptr_info.Pointer.alignment, @alignOf(u32));
    try expectEqual(u32_ptr_info.Pointer.child, u32);
    try expectEqual(u32_ptr_info.Pointer.sentinel, null);
}

test "type info: unknown length pointer type info" {
    try testUnknownLenPtr();
    comptime try testUnknownLenPtr();
}

fn testUnknownLenPtr() !void {
    const u32_ptr_info = @typeInfo([*]const volatile f64);
    try expectEqual(u32_ptr_info, .Pointer);
    try expectEqual(u32_ptr_info.Pointer.size, TypeInfo.Pointer.Size.Many);
    try expectEqual(u32_ptr_info.Pointer.is_const, true);
    try expectEqual(u32_ptr_info.Pointer.is_volatile, true);
    try expectEqual(u32_ptr_info.Pointer.sentinel, null);
    try expectEqual(u32_ptr_info.Pointer.alignment, @alignOf(f64));
    try expectEqual(u32_ptr_info.Pointer.child, f64);
}

test "type info: null terminated pointer type info" {
    try testNullTerminatedPtr();
    comptime try testNullTerminatedPtr();
}

fn testNullTerminatedPtr() !void {
    const ptr_info = @typeInfo([*:0]u8);
    try expectEqual(ptr_info, .Pointer);
    try expectEqual(ptr_info.Pointer.size, TypeInfo.Pointer.Size.Many);
    try expectEqual(ptr_info.Pointer.is_const, false);
    try expectEqual(ptr_info.Pointer.is_volatile, false);
    try expectEqual(ptr_info.Pointer.sentinel.?, 0);

    try expect(@typeInfo([:0]u8).Pointer.sentinel != null);
}

test "type info: C pointer type info" {
    try testCPtr();
    comptime try testCPtr();
}

fn testCPtr() !void {
    const ptr_info = @typeInfo([*c]align(4) const i8);
    try expectEqual(ptr_info, .Pointer);
    try expectEqual(ptr_info.Pointer.size, .C);
    try expect(ptr_info.Pointer.is_const);
    try expect(!ptr_info.Pointer.is_volatile);
    try expectEqual(ptr_info.Pointer.alignment, 4);
    try expectEqual(ptr_info.Pointer.child, i8);
}

test "type info: slice type info" {
    try testSlice();
    comptime try testSlice();
}

fn testSlice() !void {
    const u32_slice_info = @typeInfo([]u32);
    try expectEqual(u32_slice_info, .Pointer);
    try expectEqual(u32_slice_info.Pointer.size, .Slice);
    try expectEqual(u32_slice_info.Pointer.is_const, false);
    try expectEqual(u32_slice_info.Pointer.is_volatile, false);
    try expectEqual(u32_slice_info.Pointer.alignment, 4);
    try expectEqual(u32_slice_info.Pointer.child, u32);
}

test "type info: array type info" {
    try testArray();
    comptime try testArray();
}

fn testArray() !void {
    {
        const info = @typeInfo([42]u8);
        try expectEqual(info, .Array);
        try expectEqual(info.Array.len, 42);
        try expectEqual(info.Array.child, u8);
        try expectEqual(info.Array.sentinel, null);
    }

    {
        const info = @typeInfo([10:0]u8);
        try expectEqual(info.Array.len, 10);
        try expectEqual(info.Array.child, u8);
        try expectEqual(info.Array.sentinel.?, @as(u8, 0));
        try expectEqual(@sizeOf([10:0]u8), info.Array.len + 1);
    }
}

test "type info: optional type info" {
    try testOptional();
    comptime try testOptional();
}

fn testOptional() !void {
    const null_info = @typeInfo(?void);
    try expectEqual(null_info, .Optional);
    try expectEqual(null_info.Optional.child, void);
}

test "type info: error set, error union info" {
    try testErrorSet();
    comptime try testErrorSet();
}

fn testErrorSet() !void {
    const TestErrorSet = error{
        First,
        Second,
        Third,
    };

    const error_set_info = @typeInfo(TestErrorSet);
    try expectEqual(error_set_info, .ErrorSet);
    try expectEqual(error_set_info.ErrorSet.?.len, 3);
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "First"));

    const error_union_info = @typeInfo(TestErrorSet!usize);
    try expectEqual(error_union_info, .ErrorUnion);
    try expectEqual(error_union_info.ErrorUnion.error_set, TestErrorSet);
    try expectEqual(error_union_info.ErrorUnion.payload, usize);

    const global_info = @typeInfo(anyerror);
    try expectEqual(global_info, .ErrorSet);
    try expectEqual(global_info.ErrorSet, null);
}

test "type info: enum info" {
    try testEnum();
    comptime try testEnum();
}

fn testEnum() !void {
    const Os = enum {
        Windows,
        Macos,
        Linux,
        FreeBSD,
    };

    const os_info = @typeInfo(Os);
    try expectEqual(os_info, .Enum);
    try expectEqual(os_info.Enum.layout, .Auto);
    try expectEqual(os_info.Enum.fields.len, 4);
    try expect(mem.eql(u8, os_info.Enum.fields[1].name, "Macos"));
    try expectEqual(os_info.Enum.fields[3].value, 3);
    try expectEqual(os_info.Enum.tag_type, u2);
    try expectEqual(os_info.Enum.decls.len, 0);
}

test "type info: union info" {
    try testUnion();
    comptime try testUnion();
}

fn testUnion() !void {
    const typeinfo_info = @typeInfo(TypeInfo);
    try expectEqual(typeinfo_info, .Union);
    try expectEqual(typeinfo_info.Union.layout, .Auto);
    try expectEqual(typeinfo_info.Union.tag_type.?, TypeId);
    try expectEqual(typeinfo_info.Union.fields.len, 25);
    try expectEqual(typeinfo_info.Union.fields[4].field_type, @TypeOf(@typeInfo(u8).Int));
    try expectEqual(typeinfo_info.Union.decls.len, 22);

    const TestNoTagUnion = union {
        Foo: void,
        Bar: u32,
    };

    const notag_union_info = @typeInfo(TestNoTagUnion);
    try expectEqual(notag_union_info, .Union);
    try expectEqual(notag_union_info.Union.tag_type, null);
    try expectEqual(notag_union_info.Union.layout, .Auto);
    try expectEqual(notag_union_info.Union.fields.len, 2);
    try expectEqual(notag_union_info.Union.fields[0].alignment, @alignOf(void));
    try expectEqual(notag_union_info.Union.fields[1].field_type, u32);
    try expectEqual(notag_union_info.Union.fields[1].alignment, @alignOf(u32));

    const TestExternUnion = extern union {
        foo: *c_void,
    };

    const extern_union_info = @typeInfo(TestExternUnion);
    try expectEqual(extern_union_info.Union.layout, .Extern);
    try expectEqual(extern_union_info.Union.tag_type, null);
    try expectEqual(extern_union_info.Union.fields[0].field_type, *c_void);
}

test "type info: struct info" {
    try testStruct();
    comptime try testStruct();
}

fn testStruct() !void {
    const unpacked_struct_info = @typeInfo(TestUnpackedStruct);
    try expectEqual(unpacked_struct_info.Struct.is_tuple, false);
    try expectEqual(unpacked_struct_info.Struct.fields[0].alignment, @alignOf(u32));
    try expectEqual(unpacked_struct_info.Struct.fields[0].default_value.?, 4);
    try expectEqualStrings("foobar", unpacked_struct_info.Struct.fields[1].default_value.?);

    const struct_info = @typeInfo(TestStruct);
    try expectEqual(struct_info, .Struct);
    try expectEqual(struct_info.Struct.is_tuple, false);
    try expectEqual(struct_info.Struct.layout, .Packed);
    try expectEqual(struct_info.Struct.fields.len, 4);
    try expectEqual(struct_info.Struct.fields[0].alignment, 2 * @alignOf(usize));
    try expectEqual(struct_info.Struct.fields[2].field_type, *TestStruct);
    try expectEqual(struct_info.Struct.fields[2].default_value, null);
    try expectEqual(struct_info.Struct.fields[3].default_value.?, 4);
    try expectEqual(struct_info.Struct.fields[3].alignment, 1);
    try expectEqual(struct_info.Struct.decls.len, 2);
    try expect(struct_info.Struct.decls[0].is_pub);
    try expect(!struct_info.Struct.decls[0].data.Fn.is_extern);
    try expectEqual(struct_info.Struct.decls[0].data.Fn.lib_name, null);
    try expectEqual(struct_info.Struct.decls[0].data.Fn.return_type, void);
    try expectEqual(struct_info.Struct.decls[0].data.Fn.fn_type, fn (*const TestStruct) void);
}

const TestUnpackedStruct = struct {
    fieldA: u32 = 4,
    fieldB: *const [6:0]u8 = "foobar",
};

const TestStruct = packed struct {
    fieldA: usize align(2 * @alignOf(usize)),
    fieldB: void,
    fieldC: *Self,
    fieldD: u32 = 4,

    pub fn foo(self: *const Self) void {
        _ = self;
    }
    const Self = @This();
};

test "type info: opaque info" {
    try testOpaque();
    comptime try testOpaque();
}

fn testOpaque() !void {
    const Foo = opaque {
        const A = 1;
        fn b() void {}
    };

    const foo_info = @typeInfo(Foo);
    try expectEqual(foo_info.Opaque.decls.len, 2);
}

test "type info: function type info" {
    // wasm doesn't support align attributes on functions
    if (builtin.target.cpu.arch == .wasm32 or builtin.target.cpu.arch == .wasm64) return error.SkipZigTest;
    try testFunction();
    comptime try testFunction();
}

fn testFunction() !void {
    const fn_info = @typeInfo(@TypeOf(foo));
    try expectEqual(fn_info, .Fn);
    try expect(fn_info.Fn.alignment > 0);
    try expectEqual(fn_info.Fn.calling_convention, .C);
    try expect(!fn_info.Fn.is_generic);
    try expectEqual(fn_info.Fn.args.len, 2);
    try expect(fn_info.Fn.is_var_args);
    try expectEqual(fn_info.Fn.return_type.?, usize);
    const fn_aligned_info = @typeInfo(@TypeOf(fooAligned));
    try expectEqual(fn_aligned_info.Fn.alignment, 4);

    const test_instance: TestStruct = undefined;
    const bound_fn_info = @typeInfo(@TypeOf(test_instance.foo));
    try expectEqual(bound_fn_info, .BoundFn);
    try expectEqual(bound_fn_info.BoundFn.args[0].arg_type.?, *const TestStruct);
}

extern fn foo(a: usize, b: bool, ...) callconv(.C) usize;
extern fn fooAligned(a: usize, b: bool, ...) align(4) callconv(.C) usize;

test "typeInfo with comptime parameter in struct fn def" {
    const S = struct {
        pub fn func(comptime x: f32) void {
            _ = x;
        }
    };
    comptime var info = @typeInfo(S);
    _ = info;
}

test "type info: vectors" {
    try testVector();
    comptime try testVector();
}

fn testVector() !void {
    const vec_info = @typeInfo(std.meta.Vector(4, i32));
    try expectEqual(vec_info, .Vector);
    try expectEqual(vec_info.Vector.len, 4);
    try expectEqual(vec_info.Vector.child, i32);
}

test "type info: anyframe and anyframe->T" {
    try testAnyFrame();
    comptime try testAnyFrame();
}

fn testAnyFrame() !void {
    {
        const anyframe_info = @typeInfo(anyframe->i32);
        try expectEqual(anyframe_info, .AnyFrame);
        try expectEqual(anyframe_info.AnyFrame.child.?, i32);
    }

    {
        const anyframe_info = @typeInfo(anyframe);
        try expectEqual(anyframe_info, .AnyFrame);
        try expectEqual(anyframe_info.AnyFrame.child, null);
    }
}

test "type info: pass to function" {
    _ = passTypeInfo(@typeInfo(void));
    _ = comptime passTypeInfo(@typeInfo(void));
}

fn passTypeInfo(comptime info: TypeInfo) type {
    _ = info;
    return void;
}

test "type info: TypeId -> TypeInfo impl cast" {
    _ = passTypeInfo(TypeId.Void);
    _ = comptime passTypeInfo(TypeId.Void);
}

test "type info: extern fns with and without lib names" {
    const S = struct {
        extern fn bar1() void;
        extern "cool" fn bar2() void;
    };
    const info = @typeInfo(S);
    comptime {
        for (info.Struct.decls) |decl| {
            if (std.mem.eql(u8, decl.name, "bar1")) {
                try expectEqual(decl.data.Fn.lib_name, null);
            } else {
                try expectEqualStrings("cool", decl.data.Fn.lib_name.?);
            }
        }
    }
}

test "data field is a compile-time value" {
    const S = struct {
        const Bar = @as(isize, -1);
    };
    comptime try expectEqual(@typeInfo(S).Struct.decls[0].data.Var, isize);
}

test "sentinel of opaque pointer type" {
    const c_void_info = @typeInfo(*c_void);
    try expectEqual(c_void_info.Pointer.sentinel, null);
}

test "@typeInfo does not force declarations into existence" {
    const S = struct {
        x: i32,

        fn doNotReferenceMe() void {
            @compileError("test failed");
        }
    };
    comptime try expectEqual(@typeInfo(S).Struct.fields.len, 1);
}

test "defaut value for a var-typed field" {
    const S = struct { x: anytype };
    try expectEqual(@typeInfo(S).Struct.fields[0].default_value, null);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "type info for async frames" {
    switch (@typeInfo(@Frame(add))) {
        .Frame => |frame| {
            try expectEqual(frame.function, add);
        },
        else => unreachable,
    }
}

test "type info: value is correctly copied" {
    comptime {
        var ptrInfo = @typeInfo([]u32);
        ptrInfo.Pointer.size = .One;
        try expectEqual(@typeInfo([]u32).Pointer.size, .Slice);
    }
}

test "Declarations are returned in declaration order" {
    const S = struct {
        const a = 1;
        const b = 2;
        const c = 3;
        const d = 4;
        const e = 5;
    };
    const d = @typeInfo(S).Struct.decls;
    try expect(std.mem.eql(u8, d[0].name, "a"));
    try expect(std.mem.eql(u8, d[1].name, "b"));
    try expect(std.mem.eql(u8, d[2].name, "c"));
    try expect(std.mem.eql(u8, d[3].name, "d"));
    try expect(std.mem.eql(u8, d[4].name, "e"));
}

test "Struct.is_tuple" {
    try expect(@typeInfo(@TypeOf(.{0})).Struct.is_tuple);
    try expect(!@typeInfo(@TypeOf(.{ .a = 0 })).Struct.is_tuple);
}

test "StructField.is_comptime" {
    const info = @typeInfo(struct { x: u8 = 3, comptime y: u32 = 5 }).Struct;
    try expect(!info.fields[0].is_comptime);
    try expect(info.fields[1].is_comptime);
}

test "typeInfo resolves usingnamespace declarations" {
    const A = struct {
        pub const f1 = 42;
    };

    const B = struct {
        const f0 = 42;
        usingnamespace A;
    };

    try expectEqual(@typeInfo(B).Struct.decls.len, 2);
    //a
}
