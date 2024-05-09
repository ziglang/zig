const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;

const Type = std.builtin.Type;
const TypeId = std.builtin.TypeId;

const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

test "type info: integer, floating point type info" {
    try testIntFloat();
    try comptime testIntFloat();
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
    try comptime testOptional();
}

fn testOptional() !void {
    const null_info = @typeInfo(?void);
    try expect(null_info == .Optional);
    try expect(null_info.Optional.child == void);
}

test "type info: C pointer type info" {
    try testCPtr();
    try comptime testCPtr();
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
    try comptime testBasic();
}

fn testBasic() !void {
    try expect(@typeInfo(Type).Union.tag_type == TypeId);
    const void_info = @typeInfo(void);
    try expect(void_info == TypeId.Void);
    try expect(void_info.Void == {});
}

test "type info: pointer type info" {
    try testPointer();
    try comptime testPointer();
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
    try comptime testUnknownLenPtr();
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
    try comptime testNullTerminatedPtr();
}

fn testNullTerminatedPtr() !void {
    const ptr_info = @typeInfo([*:0]u8);
    try expect(ptr_info == .Pointer);
    try expect(ptr_info.Pointer.size == .Many);
    try expect(ptr_info.Pointer.is_const == false);
    try expect(ptr_info.Pointer.is_volatile == false);
    try expect(@as(*const u8, @ptrCast(ptr_info.Pointer.sentinel.?)).* == 0);

    try expect(@typeInfo([:0]u8).Pointer.sentinel != null);
}

test "type info: slice type info" {
    try testSlice();
    try comptime testSlice();
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
    try comptime testArray();
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
        try expect(@as(*const u8, @ptrCast(info.Array.sentinel.?)).* == @as(u8, 0));
        try expect(@sizeOf([10:0]u8) == info.Array.len + 1);
    }
}

test "type info: error set, error union info, anyerror" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testErrorSet();
    try comptime testErrorSet();
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

    const TestSet = error{ One, Two } || error{Three};

    const error_set_info = @typeInfo(TestSet);
    try expect(error_set_info == .ErrorSet);
    try expect(error_set_info.ErrorSet.?.len == 3);
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
    try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Three"));
}

test "type info: enum info" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testEnum();
    try comptime testEnum();
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
    try comptime testUnion();
}

fn testUnion() !void {
    const typeinfo_info = @typeInfo(Type);
    try expect(typeinfo_info == .Union);
    try expect(typeinfo_info.Union.layout == .auto);
    try expect(typeinfo_info.Union.tag_type.? == TypeId);
    try expect(typeinfo_info.Union.fields.len == 24);
    try expect(typeinfo_info.Union.fields[4].type == @TypeOf(@typeInfo(u8).Int));
    try expect(typeinfo_info.Union.decls.len == 21);

    const TestNoTagUnion = union {
        Foo: void,
        Bar: u32,
    };

    const notag_union_info = @typeInfo(TestNoTagUnion);
    try expect(notag_union_info == .Union);
    try expect(notag_union_info.Union.tag_type == null);
    try expect(notag_union_info.Union.layout == .auto);
    try expect(notag_union_info.Union.fields.len == 2);
    try expect(notag_union_info.Union.fields[0].alignment == @alignOf(void));
    try expect(notag_union_info.Union.fields[1].type == u32);
    try expect(notag_union_info.Union.fields[1].alignment == @alignOf(u32));

    const TestExternUnion = extern union {
        foo: *anyopaque,
    };

    const extern_union_info = @typeInfo(TestExternUnion);
    try expect(extern_union_info.Union.layout == .@"extern");
    try expect(extern_union_info.Union.tag_type == null);
    try expect(extern_union_info.Union.fields[0].type == *anyopaque);
}

test "type info: struct info" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testStruct();
    try comptime testStruct();
}

fn testStruct() !void {
    const unpacked_struct_info = @typeInfo(TestStruct);
    try expect(unpacked_struct_info.Struct.is_tuple == false);
    try expect(unpacked_struct_info.Struct.backing_integer == null);
    try expect(unpacked_struct_info.Struct.fields[0].alignment == @alignOf(u32));
    try expect(@as(*align(1) const u32, @ptrCast(unpacked_struct_info.Struct.fields[0].default_value.?)).* == 4);
    try expect(mem.eql(u8, "foobar", @as(*align(1) const *const [6:0]u8, @ptrCast(unpacked_struct_info.Struct.fields[1].default_value.?)).*));
}

const TestStruct = struct {
    fieldA: u32 = 4,
    fieldB: *const [6:0]u8 = "foobar",
};

test "type info: packed struct info" {
    try testPackedStruct();
    try comptime testPackedStruct();
}

fn testPackedStruct() !void {
    const struct_info = @typeInfo(TestPackedStruct);
    try expect(struct_info == .Struct);
    try expect(struct_info.Struct.is_tuple == false);
    try expect(struct_info.Struct.layout == .@"packed");
    try expect(struct_info.Struct.backing_integer == u128);
    try expect(struct_info.Struct.fields.len == 4);
    try expect(struct_info.Struct.fields[0].alignment == 0);
    try expect(struct_info.Struct.fields[2].type == f32);
    try expect(struct_info.Struct.fields[2].default_value == null);
    try expect(@as(*align(1) const u32, @ptrCast(struct_info.Struct.fields[3].default_value.?)).* == 4);
    try expect(struct_info.Struct.fields[3].alignment == 0);
    try expect(struct_info.Struct.decls.len == 1);
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
    try comptime testOpaque();
}

fn testOpaque() !void {
    const Foo = opaque {
        pub const A = 1;
        pub fn b() void {}
    };

    const foo_info = @typeInfo(Foo);
    try expect(foo_info.Opaque.decls.len == 2);
}

test "type info: function type info" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testFunction();
    try comptime testFunction();
}

fn testFunction() !void {
    const foo_fn_type = @TypeOf(typeInfoFoo);
    const foo_fn_info = @typeInfo(foo_fn_type);
    try expect(foo_fn_info.Fn.calling_convention == .C);
    try expect(!foo_fn_info.Fn.is_generic);
    try expect(foo_fn_info.Fn.params.len == 2);
    try expect(foo_fn_info.Fn.is_var_args);
    try expect(foo_fn_info.Fn.return_type.? == usize);
    const foo_ptr_fn_info = @typeInfo(@TypeOf(&typeInfoFoo));
    try expect(foo_ptr_fn_info.Pointer.size == .One);
    try expect(foo_ptr_fn_info.Pointer.is_const);
    try expect(!foo_ptr_fn_info.Pointer.is_volatile);
    try expect(foo_ptr_fn_info.Pointer.address_space == .generic);
    try expect(foo_ptr_fn_info.Pointer.child == foo_fn_type);
    try expect(!foo_ptr_fn_info.Pointer.is_allowzero);
    try expect(foo_ptr_fn_info.Pointer.sentinel == null);

    const aligned_foo_fn_type = @TypeOf(typeInfoFooAligned);
    const aligned_foo_fn_info = @typeInfo(aligned_foo_fn_type);
    try expect(aligned_foo_fn_info.Fn.calling_convention == .C);
    try expect(!aligned_foo_fn_info.Fn.is_generic);
    try expect(aligned_foo_fn_info.Fn.params.len == 2);
    try expect(aligned_foo_fn_info.Fn.is_var_args);
    try expect(aligned_foo_fn_info.Fn.return_type.? == usize);
    const aligned_foo_ptr_fn_info = @typeInfo(@TypeOf(&typeInfoFooAligned));
    try expect(aligned_foo_ptr_fn_info.Pointer.size == .One);
    try expect(aligned_foo_ptr_fn_info.Pointer.is_const);
    try expect(!aligned_foo_ptr_fn_info.Pointer.is_volatile);
    try expect(aligned_foo_ptr_fn_info.Pointer.alignment == 4);
    try expect(aligned_foo_ptr_fn_info.Pointer.address_space == .generic);
    try expect(aligned_foo_ptr_fn_info.Pointer.child == aligned_foo_fn_type);
    try expect(!aligned_foo_ptr_fn_info.Pointer.is_allowzero);
    try expect(aligned_foo_ptr_fn_info.Pointer.sentinel == null);
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
    _ = &info;
}

test "type info: vectors" {
    try testVector();
    try comptime testVector();
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
    try comptime testAnyFrame();
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
    comptime assert(@typeInfo(S).Struct.fields.len == 1);
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
            try expect(@as(@TypeOf(add), @ptrCast(frame.function)) == add);
        },
        else => unreachable,
    }
}

test "Declarations are returned in declaration order" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        pub const a = 1;
        pub const b = 2;
        pub const c = 3;
        pub const d = 4;
        pub const e = 5;
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
        pub const f0 = 42;
        pub usingnamespace A;
    };

    const decls = @typeInfo(B).Struct.decls;
    try expect(decls.len == 2);
    try expectEqualStrings(decls[0].name, "f0");
    try expectEqualStrings(decls[1].name, "f1");
}

test "value from struct @typeInfo default_value can be loaded at comptime" {
    comptime {
        const a = @typeInfo(@TypeOf(.{ .foo = @as(u8, 1) })).Struct.fields[0].default_value;
        try expect(@as(*const u8, @ptrCast(a)).* == 1);
    }
}

test "@typeInfo decls and usingnamespace" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const A = struct {
        pub const x = 5;
        pub const y = 34;

        comptime {}
    };
    const B = struct {
        pub usingnamespace A;
        pub const z = 56;

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
        pub fn Def(comptime T: type) type {
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
    const value = @as(*align(1) const *const [2:0]u8, @ptrCast(struct_field.default_value.?)).*;
    comptime std.debug.assert(value[0] == 'h');
}

test "@typeInfo only contains pub decls" {
    const other = struct {
        const std = @import("std");

        usingnamespace struct {
            pub const inside_non_pub_usingnamespace = 0;
        };

        pub const Enum = enum {
            a,
            b,
            c,
        };

        pub const Struct = struct {
            foo: i32,
        };
    };
    const ti = @typeInfo(other);
    const decls = ti.Struct.decls;

    try std.testing.expectEqual(2, decls.len);
    try std.testing.expectEqualStrings("Enum", decls[0].name);
    try std.testing.expectEqualStrings("Struct", decls[1].name);
}
