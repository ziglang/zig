const assertOrPanic = @import("std").debug.assertOrPanic;
const mem = @import("std").mem;
const TypeInfo = @import("builtin").TypeInfo;
const TypeId = @import("builtin").TypeId;

test "type info: tag type, void info" {
    testBasic();
    comptime testBasic();
}

fn testBasic() void {
    assertOrPanic(@TagType(TypeInfo) == TypeId);
    const void_info = @typeInfo(void);
    assertOrPanic(TypeId(void_info) == TypeId.Void);
    assertOrPanic(void_info.Void == {});
}

test "type info: integer, floating point type info" {
    testIntFloat();
    comptime testIntFloat();
}

fn testIntFloat() void {
    const u8_info = @typeInfo(u8);
    assertOrPanic(TypeId(u8_info) == TypeId.Int);
    assertOrPanic(!u8_info.Int.is_signed);
    assertOrPanic(u8_info.Int.bits == 8);

    const f64_info = @typeInfo(f64);
    assertOrPanic(TypeId(f64_info) == TypeId.Float);
    assertOrPanic(f64_info.Float.bits == 64);
}

test "type info: pointer type info" {
    testPointer();
    comptime testPointer();
}

fn testPointer() void {
    const u32_ptr_info = @typeInfo(*u32);
    assertOrPanic(TypeId(u32_ptr_info) == TypeId.Pointer);
    assertOrPanic(u32_ptr_info.Pointer.size == TypeInfo.Pointer.Size.One);
    assertOrPanic(u32_ptr_info.Pointer.is_const == false);
    assertOrPanic(u32_ptr_info.Pointer.is_volatile == false);
    assertOrPanic(u32_ptr_info.Pointer.alignment == @alignOf(u32));
    assertOrPanic(u32_ptr_info.Pointer.child == u32);
}

test "type info: unknown length pointer type info" {
    testUnknownLenPtr();
    comptime testUnknownLenPtr();
}

fn testUnknownLenPtr() void {
    const u32_ptr_info = @typeInfo([*]const volatile f64);
    assertOrPanic(TypeId(u32_ptr_info) == TypeId.Pointer);
    assertOrPanic(u32_ptr_info.Pointer.size == TypeInfo.Pointer.Size.Many);
    assertOrPanic(u32_ptr_info.Pointer.is_const == true);
    assertOrPanic(u32_ptr_info.Pointer.is_volatile == true);
    assertOrPanic(u32_ptr_info.Pointer.alignment == @alignOf(f64));
    assertOrPanic(u32_ptr_info.Pointer.child == f64);
}

test "type info: slice type info" {
    testSlice();
    comptime testSlice();
}

fn testSlice() void {
    const u32_slice_info = @typeInfo([]u32);
    assertOrPanic(TypeId(u32_slice_info) == TypeId.Pointer);
    assertOrPanic(u32_slice_info.Pointer.size == TypeInfo.Pointer.Size.Slice);
    assertOrPanic(u32_slice_info.Pointer.is_const == false);
    assertOrPanic(u32_slice_info.Pointer.is_volatile == false);
    assertOrPanic(u32_slice_info.Pointer.alignment == 4);
    assertOrPanic(u32_slice_info.Pointer.child == u32);
}

test "type info: array type info" {
    testArray();
    comptime testArray();
}

fn testArray() void {
    const arr_info = @typeInfo([42]bool);
    assertOrPanic(TypeId(arr_info) == TypeId.Array);
    assertOrPanic(arr_info.Array.len == 42);
    assertOrPanic(arr_info.Array.child == bool);
}

test "type info: optional type info" {
    testOptional();
    comptime testOptional();
}

fn testOptional() void {
    const null_info = @typeInfo(?void);
    assertOrPanic(TypeId(null_info) == TypeId.Optional);
    assertOrPanic(null_info.Optional.child == void);
}

test "type info: promise info" {
    testPromise();
    comptime testPromise();
}

fn testPromise() void {
    const null_promise_info = @typeInfo(promise);
    assertOrPanic(TypeId(null_promise_info) == TypeId.Promise);
    assertOrPanic(null_promise_info.Promise.child == null);

    const promise_info = @typeInfo(promise->usize);
    assertOrPanic(TypeId(promise_info) == TypeId.Promise);
    assertOrPanic(promise_info.Promise.child.? == usize);
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
    assertOrPanic(TypeId(error_set_info) == TypeId.ErrorSet);
    assertOrPanic(error_set_info.ErrorSet.errors.len == 3);
    assertOrPanic(mem.eql(u8, error_set_info.ErrorSet.errors[0].name, "First"));
    assertOrPanic(error_set_info.ErrorSet.errors[2].value == @errorToInt(TestErrorSet.Third));

    const error_union_info = @typeInfo(TestErrorSet!usize);
    assertOrPanic(TypeId(error_union_info) == TypeId.ErrorUnion);
    assertOrPanic(error_union_info.ErrorUnion.error_set == TestErrorSet);
    assertOrPanic(error_union_info.ErrorUnion.payload == usize);
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
    assertOrPanic(TypeId(os_info) == TypeId.Enum);
    assertOrPanic(os_info.Enum.layout == TypeInfo.ContainerLayout.Auto);
    assertOrPanic(os_info.Enum.fields.len == 4);
    assertOrPanic(mem.eql(u8, os_info.Enum.fields[1].name, "Macos"));
    assertOrPanic(os_info.Enum.fields[3].value == 3);
    assertOrPanic(os_info.Enum.tag_type == u2);
    assertOrPanic(os_info.Enum.defs.len == 0);
}

test "type info: union info" {
    testUnion();
    comptime testUnion();
}

fn testUnion() void {
    const typeinfo_info = @typeInfo(TypeInfo);
    assertOrPanic(TypeId(typeinfo_info) == TypeId.Union);
    assertOrPanic(typeinfo_info.Union.layout == TypeInfo.ContainerLayout.Auto);
    assertOrPanic(typeinfo_info.Union.tag_type.? == TypeId);
    assertOrPanic(typeinfo_info.Union.fields.len == 24);
    assertOrPanic(typeinfo_info.Union.fields[4].enum_field != null);
    assertOrPanic(typeinfo_info.Union.fields[4].enum_field.?.value == 4);
    assertOrPanic(typeinfo_info.Union.fields[4].field_type == @typeOf(@typeInfo(u8).Int));
    assertOrPanic(typeinfo_info.Union.defs.len == 20);

    const TestNoTagUnion = union {
        Foo: void,
        Bar: u32,
    };

    const notag_union_info = @typeInfo(TestNoTagUnion);
    assertOrPanic(TypeId(notag_union_info) == TypeId.Union);
    assertOrPanic(notag_union_info.Union.tag_type == null);
    assertOrPanic(notag_union_info.Union.layout == TypeInfo.ContainerLayout.Auto);
    assertOrPanic(notag_union_info.Union.fields.len == 2);
    assertOrPanic(notag_union_info.Union.fields[0].enum_field == null);
    assertOrPanic(notag_union_info.Union.fields[1].field_type == u32);

    const TestExternUnion = extern union {
        foo: *c_void,
    };

    const extern_union_info = @typeInfo(TestExternUnion);
    assertOrPanic(extern_union_info.Union.layout == TypeInfo.ContainerLayout.Extern);
    assertOrPanic(extern_union_info.Union.tag_type == null);
    assertOrPanic(extern_union_info.Union.fields[0].enum_field == null);
    assertOrPanic(extern_union_info.Union.fields[0].field_type == *c_void);
}

test "type info: struct info" {
    testStruct();
    comptime testStruct();
}

fn testStruct() void {
    const struct_info = @typeInfo(TestStruct);
    assertOrPanic(TypeId(struct_info) == TypeId.Struct);
    assertOrPanic(struct_info.Struct.layout == TypeInfo.ContainerLayout.Packed);
    assertOrPanic(struct_info.Struct.fields.len == 3);
    assertOrPanic(struct_info.Struct.fields[1].offset == null);
    assertOrPanic(struct_info.Struct.fields[2].field_type == *TestStruct);
    assertOrPanic(struct_info.Struct.defs.len == 2);
    assertOrPanic(struct_info.Struct.defs[0].is_pub);
    assertOrPanic(!struct_info.Struct.defs[0].data.Fn.is_extern);
    assertOrPanic(struct_info.Struct.defs[0].data.Fn.lib_name == null);
    assertOrPanic(struct_info.Struct.defs[0].data.Fn.return_type == void);
    assertOrPanic(struct_info.Struct.defs[0].data.Fn.fn_type == fn (*const TestStruct) void);
}

const TestStruct = packed struct {
    const Self = @This();

    fieldA: usize,
    fieldB: void,
    fieldC: *Self,

    pub fn foo(self: *const Self) void {}
};

test "type info: function type info" {
    testFunction();
    comptime testFunction();
}

fn testFunction() void {
    const fn_info = @typeInfo(@typeOf(foo));
    assertOrPanic(TypeId(fn_info) == TypeId.Fn);
    assertOrPanic(fn_info.Fn.calling_convention == TypeInfo.CallingConvention.Unspecified);
    assertOrPanic(fn_info.Fn.is_generic);
    assertOrPanic(fn_info.Fn.args.len == 2);
    assertOrPanic(fn_info.Fn.is_var_args);
    assertOrPanic(fn_info.Fn.return_type == null);
    assertOrPanic(fn_info.Fn.async_allocator_type == null);

    const test_instance: TestStruct = undefined;
    const bound_fn_info = @typeInfo(@typeOf(test_instance.foo));
    assertOrPanic(TypeId(bound_fn_info) == TypeId.BoundFn);
    assertOrPanic(bound_fn_info.BoundFn.args[0].arg_type.? == *const TestStruct);
}

fn foo(comptime a: usize, b: bool, args: ...) usize {
    return 0;
}

test "typeInfo with comptime parameter in struct fn def" {
    const S = struct {
        pub fn func(comptime x: f32) void {}
    };
    comptime var info = @typeInfo(S);
}
