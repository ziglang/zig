const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;

const Type = std.builtin.Type;
const TypeId = std.builtin.TypeId;

const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

test "type info: integer, floating point type info" {
    try testIntFloat();
    comptime try testIntFloat();
}

fn testIntFloat() !void {
    const u8_info = @typeInfo(u8);
    try expect(u8_info == .Int);
    try expect(u8_info.Int.signedness == .unsigned);
    try expect(u8_info.Int.bits == 8);

    const f64_info = @typeInfo(f64);
    try expect(f64_info == .Float);
    try expect(f64_info.Float.bits == 64);
}

test "type info: optional type info" {
    try testOptional();
    comptime try testOptional();
}

fn testOptional() !void {
    const null_info = @typeInfo(?void);
    try expect(null_info == .Optional);
    try expect(null_info.Optional.child == void);
}

test "type info: C pointer type info" {
    try testCPtr();
    comptime try testCPtr();
}

fn testCPtr() !void {
    const ptr_info = @typeInfo([*c]align(4) const i8);
    try expect(ptr_info == .Pointer);
    try expect(ptr_info.Pointer.size == .C);
    try expect(ptr_info.Pointer.is_const);
    try expect(!ptr_info.Pointer.is_volatile);
    try expect(ptr_info.Pointer.alignment == 4);
    try expect(ptr_info.Pointer.child == i8);
}

test "type info: value is correctly copied" {
    comptime {
        var ptrInfo = @typeInfo([]u32);
        ptrInfo.Pointer.size = .One;
        try expect(@typeInfo([]u32).Pointer.size == .Slice);
    }
}

test "type info: tag type, void info" {
    try testBasic();
    comptime try testBasic();
}

fn testBasic() !void {
    try expect(@typeInfo(Type).Union.tag_type == TypeId);
    const void_info = @typeInfo(void);
    try expect(void_info == TypeId.Void);
    try expect(void_info.Void == {});
}

test "type info: pointer type info" {
    try testPointer();
    comptime try testPointer();
}

fn testPointer() !void {
    const u32_ptr_info = @typeInfo(*u32);
    try expect(u32_ptr_info == .Pointer);
    try expect(u32_ptr_info.Pointer.size == .One);
    try expect(u32_ptr_info.Pointer.is_const == false);
    try expect(u32_ptr_info.Pointer.is_volatile == false);
    try expect(u32_ptr_info.Pointer.alignment == @alignOf(u32));
    try expect(u32_ptr_info.Pointer.child == u32);
    try expect(u32_ptr_info.Pointer.sentinel == null);
}

test "type info: unknown length pointer type info" {
    try testUnknownLenPtr();
    comptime try testUnknownLenPtr();
}

fn testUnknownLenPtr() !void {
    const u32_ptr_info = @typeInfo([*]const volatile f64);
    try expect(u32_ptr_info == .Pointer);
    try expect(u32_ptr_info.Pointer.size == .Many);
    try expect(u32_ptr_info.Pointer.is_const == true);
    try expect(u32_ptr_info.Pointer.is_volatile == true);
    try expect(u32_ptr_info.Pointer.sentinel == null);
    try expect(u32_ptr_info.Pointer.alignment == @alignOf(f64));
    try expect(u32_ptr_info.Pointer.child == f64);
}

test "type info: null terminated pointer type info" {
    try testNullTerminatedPtr();
    comptime try testNullTerminatedPtr();
}

fn testNullTerminatedPtr() !void {
    const ptr_info = @typeInfo([*:0]u8);
    try expect(ptr_info == .Pointer);
    try expect(ptr_info.Pointer.size == .Many);
    try expect(ptr_info.Pointer.is_const == false);
    try expect(ptr_info.Pointer.is_volatile == false);
    try expect(@ptrCast(*const u8, ptr_info.Pointer.sentinel.?).* == 0);

    try expect(@typeInfo([:0]u8).Pointer.sentinel != null);
}

test "type info: slice type info" {
    try testSlice();
    comptime try testSlice();
}

fn testSlice() !void {
    const u32_slice_info = @typeInfo([]u32);
    try expect(u32_slice_info == .Pointer);
    try expect(u32_slice_info.Pointer.size == .Slice);
    try expect(u32_slice_info.Pointer.is_const == false);
    try expect(u32_slice_info.Pointer.is_volatile == false);
    try expect(u32_slice_info.Pointer.alignment == 4);
    try expect(u32_slice_info.Pointer.child == u32);
}

test "type info: array type info" {
    try testArray();
    comptime try testArray();
}

fn testArray() !void {
    {
        const info = @typeInfo([42]u8);
        try expect(info == .Array);
        try expect(info.Array.len == 42);
        try expect(info.Array.child == u8);
        try expect(info.Array.sentinel == null);
    }

    {
        const info = @typeInfo([10:0]u8);
        try expect(info.Array.len == 10);
        try expect(info.Array.child == u8);
        try expect(@ptrCast(*const u8, info.Array.sentinel.?).* == @as(u8, 0));
        try expect(@sizeOf([10:0]u8) == info.Array.len + 1);
    }
}

test "type info: error set, error union info, anyerror" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try expect(error_set_info == .ErrorSet);
    try expect(error_set_info.ErrorSet.?.len == 3);
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "First"));

    const error_union_info = @typeInfo(TestErrorSet!usize);
    try expect(error_union_info == .ErrorUnion);
    try expect(error_union_info.ErrorUnion.error_set == TestErrorSet);
    try expect(error_union_info.ErrorUnion.payload == usize);

    const global_info = @typeInfo(anyerror);
    try expect(global_info == .ErrorSet);
    try expect(global_info.ErrorSet == null);
}

test "type info: error set single value" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const TestSet = error.One;

    const error_set_info = @typeInfo(@TypeOf(TestSet));
    try expect(error_set_info == .ErrorSet);
    try expect(error_set_info.ErrorSet.?.len == 1);
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
}

test "type info: error set merged" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const TestSet = error{ One, Two } || error{Three};

    const error_set_info = @typeInfo(TestSet);
    try expect(error_set_info == .ErrorSet);
    try expect(error_set_info.ErrorSet.?.len == 3);
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Three"));
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Two"));
}

test "type info: enum info" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try expect(os_info == .Enum);
    try expect(os_info.Enum.fields.len == 4);
    try expect(mem.eql(u8, os_info.Enum.fields[1].name, "Macos"));
    try expect(os_info.Enum.fields[3].value == 3);
    try expect(os_info.Enum.tag_type == u2);
    try expect(os_info.Enum.decls.len == 0);
}

test "type info: union info" {
    try testUnion();
    comptime try testUnion();
}

fn testUnion() !void {
    const typeinfo_info = @typeInfo(Type);
    try expect(typeinfo_info == .Union);
    try expect(typeinfo_info.Union.layout == .Auto);
    try expect(typeinfo_info.Union.tag_type.? == TypeId);
    try expect(typeinfo_info.Union.fields.len == 24);
    try expect(typeinfo_info.Union.fields[4].type == @TypeOf(@typeInfo(u8).Int));
    try expect(typeinfo_info.Union.decls.len == 22);

    const TestNoTagUnion = union {
        Foo: void,
        Bar: u32,
    };

    const notag_union_info = @typeInfo(TestNoTagUnion);
    try expect(notag_union_info == .Union);
    try expect(notag_union_info.Union.tag_type == null);
    try expect(notag_union_info.Union.layout == .Auto);
    try expect(notag_union_info.Union.fields.len == 2);
    try expect(notag_union_info.Union.fields[0].alignment == @alignOf(void));
    try expect(notag_union_info.Union.fields[1].type == u32);
    try expect(notag_union_info.Union.fields[1].alignment == @alignOf(u32));

    const TestExternUnion = extern union {
        foo: *anyopaque,
    };

    const extern_union_info = @typeInfo(TestExternUnion);
    try expect(extern_union_info.Union.layout == .Extern);
    try expect(extern_union_info.Union.tag_type == null);
    try expect(extern_union_info.Union.fields[0].type == *anyopaque);
}

test "type info: struct info" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testStruct();
    comptime try testStruct();
}

fn testStruct() !void {
    const unpacked_struct_info = @typeInfo(TestStruct);
    try expect(unpacked_struct_info.Struct.is_tuple == false);
    try expect(unpacked_struct_info.Struct.backing_integer == null);
    try expect(unpacked_struct_info.Struct.fields[0].alignment == @alignOf(u32));
    try expect(@ptrCast(*align(1) const u32, unpacked_struct_info.Struct.fields[0].default_value.?).* == 4);
    try expect(mem.eql(u8, "foobar", @ptrCast(*align(1) const *const [6:0]u8, unpacked_struct_info.Struct.fields[1].default_value.?).*));
}

const TestStruct = struct {
    fieldA: u32 = 4,
    fieldB: *const [6:0]u8 = "foobar",
};

test "type info: packed struct info" {
    try testPackedStruct();
    comptime try testPackedStruct();
}

fn testPackedStruct() !void {
    const struct_info = @typeInfo(TestPackedStruct);
    try expect(struct_info == .Struct);
    try expect(struct_info.Struct.is_tuple == false);
    try expect(struct_info.Struct.layout == .Packed);
    try expect(struct_info.Struct.backing_integer == u128);
    try expect(struct_info.Struct.fields.len == 4);
    try expect(struct_info.Struct.fields[0].alignment == 0);
    try expect(struct_info.Struct.fields[2].type == f32);
    try expect(struct_info.Struct.fields[2].default_value == null);
    try expect(@ptrCast(*align(1) const u32, struct_info.Struct.fields[3].default_value.?).* == 4);
    try expect(struct_info.Struct.fields[3].alignment == 0);
    try expect(struct_info.Struct.decls.len == 2);
    try expect(struct_info.Struct.decls[0].is_pub);
}

const TestPackedStruct = packed struct {
    fieldA: u64,
    fieldB: void,
    fieldC: f32,
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
    try expect(foo_info.Opaque.decls.len == 2);
}

test "type info: function type info" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testFunction();
    comptime try testFunction();
}

fn testFunction() !void {
    const fn_info = @typeInfo(@TypeOf(typeInfoFoo));
    try expect(fn_info == .Fn);
    try expect(fn_info.Fn.alignment > 0);
    try expect(fn_info.Fn.calling_convention == .C);
    try expect(!fn_info.Fn.is_generic);
    try expect(fn_info.Fn.params.len == 2);
    try expect(fn_info.Fn.is_var_args);
    try expect(fn_info.Fn.return_type.? == usize);
    const fn_aligned_info = @typeInfo(@TypeOf(typeInfoFooAligned));
    try expect(fn_aligned_info.Fn.alignment == 4);
}

extern fn typeInfoFoo(a: usize, b: bool, ...) callconv(.C) usize;
extern fn typeInfoFooAligned(a: usize, b: bool, ...) align(4) callconv(.C) usize;

test "type info: generic function types" {
    const G1 = @typeInfo(@TypeOf(generic1));
    try expect(G1.Fn.params.len == 1);
    try expect(G1.Fn.params[0].is_generic == true);
    try expect(G1.Fn.params[0].type == null);
    try expect(G1.Fn.return_type == void);

    const G2 = @typeInfo(@TypeOf(generic2));
    try expect(G2.Fn.params.len == 3);
    try expect(G2.Fn.params[0].is_generic == false);
    try expect(G2.Fn.params[0].type == type);
    try expect(G2.Fn.params[1].is_generic == true);
    try expect(G2.Fn.params[1].type == null);
    try expect(G2.Fn.params[2].is_generic == false);
    try expect(G2.Fn.params[2].type == u8);
    try expect(G2.Fn.return_type == void);

    const G3 = @typeInfo(@TypeOf(generic3));
    try expect(G3.Fn.params.len == 1);
    try expect(G3.Fn.params[0].is_generic == true);
    try expect(G3.Fn.params[0].type == null);
    try expect(G3.Fn.return_type == null);

    const G4 = @typeInfo(@TypeOf(generic4));
    try expect(G4.Fn.params.len == 1);
    try expect(G4.Fn.params[0].is_generic == true);
    try expect(G4.Fn.params[0].type == null);
    try expect(G4.Fn.return_type == null);
}

fn generic1(param: anytype) void {
    _ = param;
}
fn generic2(comptime T: type, param: T, param2: u8) void {
    _ = param;
    _ = param2;
}
fn generic3(param: anytype) @TypeOf(param) {}
fn generic4(comptime param: anytype) @TypeOf(param) {}

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
    const vec_info = @typeInfo(@Vector(4, i32));
    try expect(vec_info == .Vector);
    try expect(vec_info.Vector.len == 4);
    try expect(vec_info.Vector.child == i32);
}

test "type info: anyframe and anyframe->T" {
    if (true) {
        // https://github.com/ziglang/zig/issues/6025
        return error.SkipZigTest;
    }

    try testAnyFrame();
    comptime try testAnyFrame();
}

fn testAnyFrame() !void {
    {
        const anyframe_info = @typeInfo(anyframe->i32);
        try expect(anyframe_info == .AnyFrame);
        try expect(anyframe_info.AnyFrame.child.? == i32);
    }

    {
        const anyframe_info = @typeInfo(anyframe);
        try expect(anyframe_info == .AnyFrame);
        try expect(anyframe_info.AnyFrame.child == null);
    }
}

test "type info: pass to function" {
    _ = passTypeInfo(@typeInfo(void));
    _ = comptime passTypeInfo(@typeInfo(void));
}

fn passTypeInfo(comptime info: Type) type {
    _ = info;
    return void;
}

test "type info: TypeId -> Type impl cast" {
    _ = passTypeInfo(TypeId.Void);
    _ = comptime passTypeInfo(TypeId.Void);
}

test "sentinel of opaque pointer type" {
    const c_void_info = @typeInfo(*anyopaque);
    try expect(c_void_info.Pointer.sentinel == null);
}

test "@typeInfo does not force declarations into existence" {
    const S = struct {
        x: i32,

        fn doNotReferenceMe() void {
            @compileError("test failed");
        }
    };
    comptime try expect(@typeInfo(S).Struct.fields.len == 1);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "type info for async frames" {
    if (true) {
        // https://github.com/ziglang/zig/issues/6025
        return error.SkipZigTest;
    }

    switch (@typeInfo(@Frame(add))) {
        .Frame => |frame| {
            try expect(@ptrCast(@TypeOf(add), frame.function) == add);
        },
        else => unreachable,
    }
}

test "Declarations are returned in declaration order" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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

test "Struct.is_tuple for anon list literal" {
    try expect(@typeInfo(@TypeOf(.{0})).Struct.is_tuple);
}

test "Struct.is_tuple for anon struct literal" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const info = @typeInfo(@TypeOf(.{ .a = 0 }));
    try expect(!info.Struct.is_tuple);
    try expect(std.mem.eql(u8, info.Struct.fields[0].name, "a"));
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

    try expect(@typeInfo(B).Struct.decls.len == 2);
    //a
}

test "value from struct @typeInfo default_value can be loaded at comptime" {
    comptime {
        const a = @typeInfo(@TypeOf(.{ .foo = @as(u8, 1) })).Struct.fields[0].default_value;
        try expect(@ptrCast(*const u8, a).* == 1);
    }
}

test "@typeInfo decls and usingnamespace" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const A = struct {
        const x = 5;
        const y = 34;

        comptime {}
    };
    const B = struct {
        usingnamespace A;
        const z = 56;

        test {}
    };
    const decls = @typeInfo(B).Struct.decls;
    try expect(decls.len == 3);
    try expectEqualStrings(decls[0].name, "x");
    try expectEqualStrings(decls[1].name, "y");
    try expectEqualStrings(decls[2].name, "z");
}

test "@typeInfo decls ignore dependency loops" {
    const S = struct {
        fn Def(comptime T: type) type {
            std.debug.assert(@typeInfo(T).Struct.decls.len == 1);
            return struct {
                const foo = u32;
            };
        }
        usingnamespace Def(@This());
    };
    _ = S.foo;
}

test "type info of tuple of string literal default value" {
    const struct_field = @typeInfo(@TypeOf(.{"hi"})).Struct.fields[0];
    const value = @ptrCast(*align(1) const *const [2:0]u8, struct_field.default_value.?).*;
    comptime std.debug.assert(value[0] == 'h');
}
