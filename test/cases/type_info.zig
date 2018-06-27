const assert = @import("std").debug.assert;
const mem = @import("std").mem;
const TypeInfo = @import("builtin").TypeInfo;
const TypeId = @import("builtin").TypeId;

test "type info: tag type, void info" {
    testBasic();
    comptime testBasic();
}

fn testBasic() void {
    assert(@TagType(TypeInfo) == TypeId);
    const void_info = @typeInfo(void);
    assert(TypeId(void_info) == TypeId.Void);
    assert(void_info.Void == {});
}

test "type info: integer, floating point type info" {
    testIntFloat();
    comptime testIntFloat();
}

fn testIntFloat() void {
    const u8_info = @typeInfo(u8);
    assert(TypeId(u8_info) == TypeId.Int);
    assert(!u8_info.Int.is_signed);
    assert(u8_info.Int.bits == 8);

    const f64_info = @typeInfo(f64);
    assert(TypeId(f64_info) == TypeId.Float);
    assert(f64_info.Float.bits == 64);
}

test "type info: pointer type info" {
    testPointer();
    comptime testPointer();
}

fn testPointer() void {
    const u32_ptr_info = @typeInfo(*u32);
    assert(TypeId(u32_ptr_info) == TypeId.Pointer);
    assert(u32_ptr_info.Pointer.size == TypeInfo.Pointer.Size.One);
    assert(u32_ptr_info.Pointer.is_const == false);
    assert(u32_ptr_info.Pointer.is_volatile == false);
    assert(u32_ptr_info.Pointer.alignment == @alignOf(u32));
    assert(u32_ptr_info.Pointer.child == u32);
}

test "type info: unknown length pointer type info" {
    testUnknownLenPtr();
    comptime testUnknownLenPtr();
}

fn testUnknownLenPtr() void {
    const u32_ptr_info = @typeInfo([*]const volatile f64);
    assert(TypeId(u32_ptr_info) == TypeId.Pointer);
    assert(u32_ptr_info.Pointer.size == TypeInfo.Pointer.Size.Many);
    assert(u32_ptr_info.Pointer.is_const == true);
    assert(u32_ptr_info.Pointer.is_volatile == true);
    assert(u32_ptr_info.Pointer.alignment == @alignOf(f64));
    assert(u32_ptr_info.Pointer.child == f64);
}

test "type info: slice type info" {
    testSlice();
    comptime testSlice();
}

fn testSlice() void {
    const u32_slice_info = @typeInfo([]u32);
    assert(TypeId(u32_slice_info) == TypeId.Pointer);
    assert(u32_slice_info.Pointer.size == TypeInfo.Pointer.Size.Slice);
    assert(u32_slice_info.Pointer.is_const == false);
    assert(u32_slice_info.Pointer.is_volatile == false);
    assert(u32_slice_info.Pointer.alignment == 4);
    assert(u32_slice_info.Pointer.child == u32);
}

test "type info: array type info" {
    testArray();
    comptime testArray();
}

fn testArray() void {
    const arr_info = @typeInfo([42]bool);
    assert(TypeId(arr_info) == TypeId.Array);
    assert(arr_info.Array.len == 42);
    assert(arr_info.Array.child == bool);
}

test "type info: optional type info" {
    testOptional();
    comptime testOptional();
}

fn testOptional() void {
    const null_info = @typeInfo(?void);
    assert(TypeId(null_info) == TypeId.Optional);
    assert(null_info.Optional.child == void);
}

test "type info: promise info" {
    testPromise();
    comptime testPromise();
}

fn testPromise() void {
    const null_promise_info = @typeInfo(promise);
    assert(TypeId(null_promise_info) == TypeId.Promise);
    assert(null_promise_info.Promise.child == null);

    const promise_info = @typeInfo(promise->usize);
    assert(TypeId(promise_info) == TypeId.Promise);
    assert(promise_info.Promise.child.? == usize);
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
    assert(TypeId(error_set_info) == TypeId.ErrorSet);
    assert(error_set_info.ErrorSet.errors.len == 3);
    assert(mem.eql(u8, error_set_info.ErrorSet.errors[0].name, "First"));
    assert(error_set_info.ErrorSet.errors[2].value == @errorToInt(TestErrorSet.Third));

    const error_union_info = @typeInfo(TestErrorSet!usize);
    assert(TypeId(error_union_info) == TypeId.ErrorUnion);
    assert(error_union_info.ErrorUnion.error_set == TestErrorSet);
    assert(error_union_info.ErrorUnion.payload == usize);
}

test "type info: enum info" {
    testEnum();
    comptime testEnum();
}

fn testEnum() void {
    const Os = @import("builtin").Os;

    const os_info = @typeInfo(Os);
    assert(TypeId(os_info) == TypeId.Enum);
    assert(os_info.Enum.layout == TypeInfo.ContainerLayout.Auto);
    assert(os_info.Enum.fields.len == 32);
    assert(mem.eql(u8, os_info.Enum.fields[1].name, "ananas"));
    assert(os_info.Enum.fields[10].value == 10);
    assert(os_info.Enum.tag_type == u5);
    assert(os_info.Enum.defs.len == 0);
}

test "type info: union info" {
    testUnion();
    comptime testUnion();
}

fn testUnion() void {
    const typeinfo_info = @typeInfo(TypeInfo);
    assert(TypeId(typeinfo_info) == TypeId.Union);
    assert(typeinfo_info.Union.layout == TypeInfo.ContainerLayout.Auto);
    assert(typeinfo_info.Union.tag_type.? == TypeId);
    assert(typeinfo_info.Union.fields.len == 25);
    assert(typeinfo_info.Union.fields[4].enum_field != null);
    assert(typeinfo_info.Union.fields[4].enum_field.?.value == 4);
    assert(typeinfo_info.Union.fields[4].field_type == @typeOf(@typeInfo(u8).Int));
    assert(typeinfo_info.Union.defs.len == 20);

    const TestNoTagUnion = union {
        Foo: void,
        Bar: u32,
    };

    const notag_union_info = @typeInfo(TestNoTagUnion);
    assert(TypeId(notag_union_info) == TypeId.Union);
    assert(notag_union_info.Union.tag_type == null);
    assert(notag_union_info.Union.layout == TypeInfo.ContainerLayout.Auto);
    assert(notag_union_info.Union.fields.len == 2);
    assert(notag_union_info.Union.fields[0].enum_field == null);
    assert(notag_union_info.Union.fields[1].field_type == u32);

    const TestExternUnion = extern union {
        foo: *c_void,
    };

    const extern_union_info = @typeInfo(TestExternUnion);
    assert(extern_union_info.Union.layout == TypeInfo.ContainerLayout.Extern);
    assert(extern_union_info.Union.tag_type == null);
    assert(extern_union_info.Union.fields[0].enum_field == null);
    assert(extern_union_info.Union.fields[0].field_type == *c_void);
}

test "type info: struct info" {
    testStruct();
    comptime testStruct();
}

fn testStruct() void {
    const struct_info = @typeInfo(TestStruct);
    assert(TypeId(struct_info) == TypeId.Struct);
    assert(struct_info.Struct.layout == TypeInfo.ContainerLayout.Packed);
    assert(struct_info.Struct.fields.len == 3);
    assert(struct_info.Struct.fields[1].offset == null);
    assert(struct_info.Struct.fields[2].field_type == *TestStruct);
    assert(struct_info.Struct.defs.len == 2);
    assert(struct_info.Struct.defs[0].is_pub);
    assert(!struct_info.Struct.defs[0].data.Fn.is_extern);
    assert(struct_info.Struct.defs[0].data.Fn.lib_name == null);
    assert(struct_info.Struct.defs[0].data.Fn.return_type == void);
    assert(struct_info.Struct.defs[0].data.Fn.fn_type == fn (*const TestStruct) void);
}

const TestStruct = packed struct {
    const Self = this;

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
    assert(TypeId(fn_info) == TypeId.Fn);
    assert(fn_info.Fn.calling_convention == TypeInfo.CallingConvention.Unspecified);
    assert(fn_info.Fn.is_generic);
    assert(fn_info.Fn.args.len == 2);
    assert(fn_info.Fn.is_var_args);
    assert(fn_info.Fn.return_type == null);
    assert(fn_info.Fn.async_allocator_type == null);

    const test_instance: TestStruct = undefined;
    const bound_fn_info = @typeInfo(@typeOf(test_instance.foo));
    assert(TypeId(bound_fn_info) == TypeId.BoundFn);
    assert(bound_fn_info.BoundFn.args[0].arg_type.? == *const TestStruct);
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
