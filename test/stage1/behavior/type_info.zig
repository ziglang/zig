const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const builtin = @import("builtin");
const TypeInfo = builtin.TypeInfo;
const TypeId = builtin.TypeId;

test "type info: tag type, void info" {
    testBasic();
    comptime testBasic();
}

fn testBasic() void {
    expect(@TagType(TypeInfo) == TypeId);
    const void_info = @typeInfo(void);
    expect(void_info == TypeId.Void);
    expect(void_info.Void == {});
}

test "type info: integer, floating point type info" {
    testIntFloat();
    comptime testIntFloat();
}

fn testIntFloat() void {
    const u8_info = @typeInfo(u8);
    expect(u8_info == .Int);
    expect(!u8_info.Int.is_signed);
    expect(u8_info.Int.bits == 8);

    const f64_info = @typeInfo(f64);
    expect(f64_info == .Float);
    expect(f64_info.Float.bits == 64);
}

test "type info: pointer type info" {
    testPointer();
    comptime testPointer();
}

fn testPointer() void {
    const u32_ptr_info = @typeInfo(*u32);
    expect(u32_ptr_info == .Pointer);
    expect(u32_ptr_info.Pointer.size == TypeInfo.Pointer.Size.One);
    expect(u32_ptr_info.Pointer.is_const == false);
    expect(u32_ptr_info.Pointer.is_volatile == false);
    expect(u32_ptr_info.Pointer.alignment == @alignOf(u32));
    expect(u32_ptr_info.Pointer.child == u32);
    expect(u32_ptr_info.Pointer.sentinel == null);
}

test "type info: unknown length pointer type info" {
    testUnknownLenPtr();
    comptime testUnknownLenPtr();
}

fn testUnknownLenPtr() void {
    const u32_ptr_info = @typeInfo([*]const volatile f64);
    expect(u32_ptr_info == .Pointer);
    expect(u32_ptr_info.Pointer.size == TypeInfo.Pointer.Size.Many);
    expect(u32_ptr_info.Pointer.is_const == true);
    expect(u32_ptr_info.Pointer.is_volatile == true);
    expect(u32_ptr_info.Pointer.sentinel == null);
    expect(u32_ptr_info.Pointer.alignment == @alignOf(f64));
    expect(u32_ptr_info.Pointer.child == f64);
}

test "type info: null terminated pointer type info" {
    testNullTerminatedPtr();
    comptime testNullTerminatedPtr();
}

fn testNullTerminatedPtr() void {
    const ptr_info = @typeInfo([*:0]u8);
    expect(ptr_info == .Pointer);
    expect(ptr_info.Pointer.size == TypeInfo.Pointer.Size.Many);
    expect(ptr_info.Pointer.is_const == false);
    expect(ptr_info.Pointer.is_volatile == false);
    expect(ptr_info.Pointer.sentinel.? == 0);

    expect(@typeInfo([:0]u8).Pointer.sentinel != null);
    expect(@typeInfo([10:0]u8).Array.sentinel != null);
    expect(@typeInfo([10:0]u8).Array.len == 10);
    expect(@sizeOf([10:0]u8) == 11);
}

test "type info: C pointer type info" {
    testCPtr();
    comptime testCPtr();
}

fn testCPtr() void {
    const ptr_info = @typeInfo([*c]align(4) const i8);
    expect(ptr_info == .Pointer);
    expect(ptr_info.Pointer.size == .C);
    expect(ptr_info.Pointer.is_const);
    expect(!ptr_info.Pointer.is_volatile);
    expect(ptr_info.Pointer.alignment == 4);
    expect(ptr_info.Pointer.child == i8);
}

test "type info: slice type info" {
    testSlice();
    comptime testSlice();
}

fn testSlice() void {
    const u32_slice_info = @typeInfo([]u32);
    expect(u32_slice_info == .Pointer);
    expect(u32_slice_info.Pointer.size == .Slice);
    expect(u32_slice_info.Pointer.is_const == false);
    expect(u32_slice_info.Pointer.is_volatile == false);
    expect(u32_slice_info.Pointer.alignment == 4);
    expect(u32_slice_info.Pointer.child == u32);
}

test "type info: array type info" {
    testArray();
    comptime testArray();
}

fn testArray() void {
    const arr_info = @typeInfo([42]bool);
    expect(arr_info == .Array);
    expect(arr_info.Array.len == 42);
    expect(arr_info.Array.child == bool);
}

test "type info: optional type info" {
    testOptional();
    comptime testOptional();
}

fn testOptional() void {
    const null_info = @typeInfo(?void);
    expect(null_info == .Optional);
    expect(null_info.Optional.child == void);
}

test "type info: error set, error union info" {
    testErrorSet();
    comptime testErrorSet();
}

fn testErrorSet() void {
    const TestErrorSet = error{
        First,
        Second,
        Third,
    };

    const error_set_info = @typeInfo(TestErrorSet);
    expect(error_set_info == .ErrorSet);
    expect(error_set_info.ErrorSet.?.len == 3);
    expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "First"));
    expect(error_set_info.ErrorSet.?[2].value == @errorToInt(TestErrorSet.Third));

    const error_union_info = @typeInfo(TestErrorSet!usize);
    expect(error_union_info == .ErrorUnion);
    expect(error_union_info.ErrorUnion.error_set == TestErrorSet);
    expect(error_union_info.ErrorUnion.payload == usize);

    const global_info = @typeInfo(anyerror);
    expect(global_info == .ErrorSet);
    expect(global_info.ErrorSet == null);
}

test "type info: enum info" {
    testEnum();
    comptime testEnum();
}

fn testEnum() void {
    const Os = enum {
        Windows,
        Macos,
        Linux,
        FreeBSD,
    };

    const os_info = @typeInfo(Os);
    expect(os_info == .Enum);
    expect(os_info.Enum.layout == .Auto);
    expect(os_info.Enum.fields.len == 4);
    expect(mem.eql(u8, os_info.Enum.fields[1].name, "Macos"));
    expect(os_info.Enum.fields[3].value == 3);
    expect(os_info.Enum.tag_type == u2);
    expect(os_info.Enum.decls.len == 0);
}

test "type info: union info" {
    testUnion();
    comptime testUnion();
}

fn testUnion() void {
    const typeinfo_info = @typeInfo(TypeInfo);
    expect(typeinfo_info == .Union);
    expect(typeinfo_info.Union.layout == .Auto);
    expect(typeinfo_info.Union.tag_type.? == TypeId);
    expect(typeinfo_info.Union.fields.len == 25);
    expect(typeinfo_info.Union.fields[4].enum_field != null);
    expect(typeinfo_info.Union.fields[4].enum_field.?.value == 4);
    expect(typeinfo_info.Union.fields[4].field_type == @TypeOf(@typeInfo(u8).Int));
    expect(typeinfo_info.Union.decls.len == 21);

    const TestNoTagUnion = union {
        Foo: void,
        Bar: u32,
    };

    const notag_union_info = @typeInfo(TestNoTagUnion);
    expect(notag_union_info == .Union);
    expect(notag_union_info.Union.tag_type == null);
    expect(notag_union_info.Union.layout == .Auto);
    expect(notag_union_info.Union.fields.len == 2);
    expect(notag_union_info.Union.fields[0].enum_field == null);
    expect(notag_union_info.Union.fields[1].field_type == u32);

    const TestExternUnion = extern union {
        foo: *c_void,
    };

    const extern_union_info = @typeInfo(TestExternUnion);
    expect(extern_union_info.Union.layout == .Extern);
    expect(extern_union_info.Union.tag_type == null);
    expect(extern_union_info.Union.fields[0].enum_field == null);
    expect(extern_union_info.Union.fields[0].field_type == *c_void);
}

test "type info: struct info" {
    testStruct();
    comptime testStruct();
}

fn testStruct() void {
    const struct_info = @typeInfo(TestStruct);
    expect(struct_info == .Struct);
    expect(struct_info.Struct.layout == .Packed);
    expect(struct_info.Struct.fields.len == 4);
    expect(struct_info.Struct.fields[1].offset == null);
    expect(struct_info.Struct.fields[2].field_type == *TestStruct);
    expect(struct_info.Struct.fields[2].default_value == null);
    expect(struct_info.Struct.fields[3].default_value.? == 4);
    expect(struct_info.Struct.decls.len == 2);
    expect(struct_info.Struct.decls[0].is_pub);
    expect(!struct_info.Struct.decls[0].data.Fn.is_extern);
    expect(struct_info.Struct.decls[0].data.Fn.lib_name == null);
    expect(struct_info.Struct.decls[0].data.Fn.return_type == void);
    expect(struct_info.Struct.decls[0].data.Fn.fn_type == fn (*const TestStruct) void);
}

const TestStruct = packed struct {
    fieldA: usize,
    fieldB: void,
    fieldC: *Self,
    fieldD: u32 = 4,

    pub fn foo(self: *const Self) void {}
    const Self = @This();
};

test "type info: function type info" {
    testFunction();
    comptime testFunction();
}

fn testFunction() void {
    const fn_info = @typeInfo(@TypeOf(foo));
    expect(fn_info == .Fn);
    expect(fn_info.Fn.calling_convention == .C);
    expect(!fn_info.Fn.is_generic);
    expect(fn_info.Fn.args.len == 2);
    expect(fn_info.Fn.is_var_args);
    expect(fn_info.Fn.return_type.? == usize);

    const test_instance: TestStruct = undefined;
    const bound_fn_info = @typeInfo(@TypeOf(test_instance.foo));
    expect(bound_fn_info == .BoundFn);
    expect(bound_fn_info.BoundFn.args[0].arg_type.? == *const TestStruct);
}

extern fn foo(a: usize, b: bool, ...) usize;

test "typeInfo with comptime parameter in struct fn def" {
    const S = struct {
        pub fn func(comptime x: f32) void {}
    };
    comptime var info = @typeInfo(S);
}

test "type info: vectors" {
    testVector();
    comptime testVector();
}

fn testVector() void {
    const vec_info = @typeInfo(std.meta.Vector(4, i32));
    expect(vec_info == .Vector);
    expect(vec_info.Vector.len == 4);
    expect(vec_info.Vector.child == i32);
}

test "type info: anyframe and anyframe->T" {
    testAnyFrame();
    comptime testAnyFrame();
}

fn testAnyFrame() void {
    {
        const anyframe_info = @typeInfo(anyframe->i32);
        expect(anyframe_info == .AnyFrame);
        expect(anyframe_info.AnyFrame.child.? == i32);
    }

    {
        const anyframe_info = @typeInfo(anyframe);
        expect(anyframe_info == .AnyFrame);
        expect(anyframe_info.AnyFrame.child == null);
    }
}

test "type info: optional field unwrapping" {
    const Struct = struct {
        cdOffset: u32,
    };

    const field = @typeInfo(Struct).Struct.fields[0];

    _ = field.offset orelse 0;
}

test "type info: pass to function" {
    _ = passTypeInfo(@typeInfo(void));
    _ = comptime passTypeInfo(@typeInfo(void));
}

fn passTypeInfo(comptime info: TypeInfo) type {
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
                expect(decl.data.Fn.lib_name == null);
            } else {
                std.testing.expectEqual(@as([]const u8, "cool"), decl.data.Fn.lib_name.?);
            }
        }
    }
}

test "data field is a compile-time value" {
    const S = struct {
        const Bar = @as(isize, -1);
    };
    comptime expect(@typeInfo(S).Struct.decls[0].data.Var == isize);
}

test "sentinel of opaque pointer type" {
    const c_void_info = @typeInfo(*c_void);
    expect(c_void_info.Pointer.sentinel == null);
}

test "@typeInfo does not force declarations into existence" {
    const S = struct {
        x: i32,

        fn doNotReferenceMe() void {
            @compileError("test failed");
        }
    };
    comptime expect(@typeInfo(S).Struct.fields.len == 1);
}

test "defaut value for a var-typed field" {
    const S = struct { x: anytype };
    expect(@typeInfo(S).Struct.fields[0].default_value == null);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "type info for async frames" {
    switch (@typeInfo(@Frame(add))) {
        .Frame => |frame| {
            expect(frame.function == add);
        },
        else => unreachable,
    }
}

test "type info: value is correctly copied" {
    comptime {
        var ptrInfo = @typeInfo([]u32);
        ptrInfo.Pointer.size = .One;
        expect(@typeInfo([]u32).Pointer.size == .Slice);
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
    expect(std.mem.eql(u8, d[0].name, "a"));
    expect(std.mem.eql(u8, d[1].name, "b"));
    expect(std.mem.eql(u8, d[2].name, "c"));
    expect(std.mem.eql(u8, d[3].name, "d"));
    expect(std.mem.eql(u8, d[4].name, "e"));
}

test "Struct.is_tuple" {
    expect(@typeInfo(@TypeOf(.{0})).Struct.is_tuple);
    expect(!@typeInfo(@TypeOf(.{ .a = 0 })).Struct.is_tuple);
}
