const std = @import("../std.zig");
const builtin = @import("builtin");
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const warn = debug.warn;

const meta = @import("../meta.zig");

//This is necessary if we want to return generic functions directly because of how the
// the type erasure works. see:  #1375
fn traitFnWorkaround(comptime T: type) bool {
    return false;
}

pub const TraitFn = @TypeOf(traitFnWorkaround);

//////Trait generators

//Need TraitList because compiler can't do varargs at comptime yet
pub const TraitList = []const TraitFn;
pub fn multiTrait(comptime traits: TraitList) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            inline for (traits) |t|
                if (!t(T)) return false;
            return true;
        }
    };
    return Closure.trait;
}

test "std.meta.trait.multiTrait" {
    const Vector2 = struct {
        const MyType = @This();

        x: u8,
        y: u8,

        pub fn add(self: MyType, other: MyType) MyType {
            return MyType{
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }
    };

    const isVector = multiTrait(&[_]TraitFn{
        hasFn("add"),
        hasField("x"),
        hasField("y"),
    });
    testing.expect(isVector(Vector2));
    testing.expect(!isVector(u8));
}

pub fn hasFn(comptime name: []const u8) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            if (!comptime isContainer(T)) return false;
            if (!comptime @hasDecl(T, name)) return false;
            const DeclType = @TypeOf(@field(T, name));
            const decl_type_id = @typeId(DeclType);
            return decl_type_id == builtin.TypeId.Fn;
        }
    };
    return Closure.trait;
}

test "std.meta.trait.hasFn" {
    const TestStruct = struct {
        pub fn useless() void {}
    };

    testing.expect(hasFn("useless")(TestStruct));
    testing.expect(!hasFn("append")(TestStruct));
    testing.expect(!hasFn("useless")(u8));
}

pub fn hasField(comptime name: []const u8) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            const info = @typeInfo(T);
            const fields = switch (info) {
                builtin.TypeId.Struct => |s| s.fields,
                builtin.TypeId.Union => |u| u.fields,
                builtin.TypeId.Enum => |e| e.fields,
                else => return false,
            };

            inline for (fields) |field| {
                if (mem.eql(u8, field.name, name)) return true;
            }

            return false;
        }
    };
    return Closure.trait;
}

test "std.meta.trait.hasField" {
    const TestStruct = struct {
        value: u32,
    };

    testing.expect(hasField("value")(TestStruct));
    testing.expect(!hasField("value")(*TestStruct));
    testing.expect(!hasField("x")(TestStruct));
    testing.expect(!hasField("x")(**TestStruct));
    testing.expect(!hasField("value")(u8));
}

pub fn is(comptime id: builtin.TypeId) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            return id == @typeId(T);
        }
    };
    return Closure.trait;
}

test "std.meta.trait.is" {
    testing.expect(is(builtin.TypeId.Int)(u8));
    testing.expect(!is(builtin.TypeId.Int)(f32));
    testing.expect(is(builtin.TypeId.Pointer)(*u8));
    testing.expect(is(builtin.TypeId.Void)(void));
    testing.expect(!is(builtin.TypeId.Optional)(anyerror));
}

pub fn isPtrTo(comptime id: builtin.TypeId) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            if (!comptime isSingleItemPtr(T)) return false;
            return id == @typeId(meta.Child(T));
        }
    };
    return Closure.trait;
}

test "std.meta.trait.isPtrTo" {
    testing.expect(!isPtrTo(builtin.TypeId.Struct)(struct {}));
    testing.expect(isPtrTo(builtin.TypeId.Struct)(*struct {}));
    testing.expect(!isPtrTo(builtin.TypeId.Struct)(**struct {}));
}

///////////Strait trait Fns

//@TODO:
// Somewhat limited since we can't apply this logic to normal variables, fields, or
//  Fns yet. Should be isExternType?
pub fn isExtern(comptime T: type) bool {
    const Extern = builtin.TypeInfo.ContainerLayout.Extern;
    const info = @typeInfo(T);
    return switch (info) {
        builtin.TypeId.Struct => |s| s.layout == Extern,
        builtin.TypeId.Union => |u| u.layout == Extern,
        builtin.TypeId.Enum => |e| e.layout == Extern,
        else => false,
    };
}

test "std.meta.trait.isExtern" {
    const TestExStruct = extern struct {};
    const TestStruct = struct {};

    testing.expect(isExtern(TestExStruct));
    testing.expect(!isExtern(TestStruct));
    testing.expect(!isExtern(u8));
}

pub fn isPacked(comptime T: type) bool {
    const Packed = builtin.TypeInfo.ContainerLayout.Packed;
    const info = @typeInfo(T);
    return switch (info) {
        builtin.TypeId.Struct => |s| s.layout == Packed,
        builtin.TypeId.Union => |u| u.layout == Packed,
        builtin.TypeId.Enum => |e| e.layout == Packed,
        else => false,
    };
}

test "std.meta.trait.isPacked" {
    const TestPStruct = packed struct {};
    const TestStruct = struct {};

    testing.expect(isPacked(TestPStruct));
    testing.expect(!isPacked(TestStruct));
    testing.expect(!isPacked(u8));
}

pub fn isUnsignedInt(comptime T: type) bool {
    return switch (@typeId(T)) {
        builtin.TypeId.Int => !@typeInfo(T).Int.is_signed,
        else => false,
    };
}

test "isUnsignedInt" {
    testing.expect(isUnsignedInt(u32) == true);
    testing.expect(isUnsignedInt(comptime_int) == false);
    testing.expect(isUnsignedInt(i64) == false);
    testing.expect(isUnsignedInt(f64) == false);
}

pub fn isSignedInt(comptime T: type) bool {
    return switch (@typeId(T)) {
        builtin.TypeId.ComptimeInt => true,
        builtin.TypeId.Int => @typeInfo(T).Int.is_signed,
        else => false,
    };
}

test "isSignedInt" {
    testing.expect(isSignedInt(u32) == false);
    testing.expect(isSignedInt(comptime_int) == true);
    testing.expect(isSignedInt(i64) == true);
    testing.expect(isSignedInt(f64) == false);
}

pub fn isSingleItemPtr(comptime T: type) bool {
    if (comptime is(builtin.TypeId.Pointer)(T)) {
        const info = @typeInfo(T);
        return info.Pointer.size == builtin.TypeInfo.Pointer.Size.One;
    }
    return false;
}

test "std.meta.trait.isSingleItemPtr" {
    const array = [_]u8{0} ** 10;
    testing.expect(isSingleItemPtr(@TypeOf(&array[0])));
    testing.expect(!isSingleItemPtr(@TypeOf(array)));
    testing.expect(!isSingleItemPtr(@TypeOf(array[0..1])));
}

pub fn isManyItemPtr(comptime T: type) bool {
    if (comptime is(builtin.TypeId.Pointer)(T)) {
        const info = @typeInfo(T);
        return info.Pointer.size == builtin.TypeInfo.Pointer.Size.Many;
    }
    return false;
}

test "std.meta.trait.isManyItemPtr" {
    const array = [_]u8{0} ** 10;
    const mip = @ptrCast([*]const u8, &array[0]);
    testing.expect(isManyItemPtr(@TypeOf(mip)));
    testing.expect(!isManyItemPtr(@TypeOf(array)));
    testing.expect(!isManyItemPtr(@TypeOf(array[0..1])));
}

pub fn isSlice(comptime T: type) bool {
    if (comptime is(builtin.TypeId.Pointer)(T)) {
        const info = @typeInfo(T);
        return info.Pointer.size == builtin.TypeInfo.Pointer.Size.Slice;
    }
    return false;
}

test "std.meta.trait.isSlice" {
    const array = [_]u8{0} ** 10;
    testing.expect(isSlice(@TypeOf(array[0..])));
    testing.expect(!isSlice(@TypeOf(array)));
    testing.expect(!isSlice(@TypeOf(&array[0])));
}

pub fn isIndexable(comptime T: type) bool {
    if (comptime is(builtin.TypeId.Pointer)(T)) {
        const info = @typeInfo(T);
        if (info.Pointer.size == builtin.TypeInfo.Pointer.Size.One) {
            if (comptime is(builtin.TypeId.Array)(meta.Child(T))) return true;
            return false;
        }
        return true;
    }
    return comptime is(builtin.TypeId.Array)(T);
}

test "std.meta.trait.isIndexable" {
    const array = [_]u8{0} ** 10;
    const slice = array[0..];

    testing.expect(isIndexable(@TypeOf(array)));
    testing.expect(isIndexable(@TypeOf(&array)));
    testing.expect(isIndexable(@TypeOf(slice)));
    testing.expect(!isIndexable(meta.Child(@TypeOf(slice))));
}

pub fn isNumber(comptime T: type) bool {
    return switch (@typeId(T)) {
        builtin.TypeId.Int, builtin.TypeId.Float, builtin.TypeId.ComptimeInt, builtin.TypeId.ComptimeFloat => true,
        else => false,
    };
}

test "std.meta.trait.isNumber" {
    const NotANumber = struct {
        number: u8,
    };

    testing.expect(isNumber(u32));
    testing.expect(isNumber(f32));
    testing.expect(isNumber(u64));
    testing.expect(isNumber(@TypeOf(102)));
    testing.expect(isNumber(@TypeOf(102.123)));
    testing.expect(!isNumber([]u8));
    testing.expect(!isNumber(NotANumber));
}

pub fn isConstPtr(comptime T: type) bool {
    if (!comptime is(builtin.TypeId.Pointer)(T)) return false;
    const info = @typeInfo(T);
    return info.Pointer.is_const;
}

test "std.meta.trait.isConstPtr" {
    var t = @as(u8, 0);
    const c = @as(u8, 0);
    testing.expect(isConstPtr(*const @TypeOf(t)));
    testing.expect(isConstPtr(@TypeOf(&c)));
    testing.expect(!isConstPtr(*@TypeOf(t)));
    testing.expect(!isConstPtr(@TypeOf(6)));
}

pub fn isContainer(comptime T: type) bool {
    const info = @typeInfo(T);
    return switch (info) {
        builtin.TypeId.Struct => true,
        builtin.TypeId.Union => true,
        builtin.TypeId.Enum => true,
        else => false,
    };
}

test "std.meta.trait.isContainer" {
    const TestStruct = struct {};
    const TestUnion = union {
        a: void,
    };
    const TestEnum = enum {
        A,
        B,
    };

    testing.expect(isContainer(TestStruct));
    testing.expect(isContainer(TestUnion));
    testing.expect(isContainer(TestEnum));
    testing.expect(!isContainer(u8));
}
