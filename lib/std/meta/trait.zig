const std = @import("../std.zig");
const builtin = std.builtin;
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const warn = debug.warn;

const meta = @import("../meta.zig");

pub const TraitFn = fn (type) bool;

pub fn multiTrait(comptime traits: anytype) TraitFn {
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

    const isVector = multiTrait(.{
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
            return @typeInfo(DeclType) == .Fn;
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
            const fields = switch (@typeInfo(T)) {
                .Struct => |s| s.fields,
                .Union => |u| u.fields,
                .Enum => |e| e.fields,
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
            return id == @typeInfo(T);
        }
    };
    return Closure.trait;
}

test "std.meta.trait.is" {
    testing.expect(is(.Int)(u8));
    testing.expect(!is(.Int)(f32));
    testing.expect(is(.Pointer)(*u8));
    testing.expect(is(.Void)(void));
    testing.expect(!is(.Optional)(anyerror));
}

pub fn isPtrTo(comptime id: builtin.TypeId) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            if (!comptime isSingleItemPtr(T)) return false;
            return id == @typeInfo(meta.Child(T));
        }
    };
    return Closure.trait;
}

test "std.meta.trait.isPtrTo" {
    testing.expect(!isPtrTo(.Struct)(struct {}));
    testing.expect(isPtrTo(.Struct)(*struct {}));
    testing.expect(!isPtrTo(.Struct)(**struct {}));
}

pub fn isSliceOf(comptime id: builtin.TypeId) TraitFn {
    const Closure = struct {
        pub fn trait(comptime T: type) bool {
            if (!comptime isSlice(T)) return false;
            return id == @typeInfo(meta.Child(T));
        }
    };
    return Closure.trait;
}

test "std.meta.trait.isSliceOf" {
    testing.expect(!isSliceOf(.Struct)(struct {}));
    testing.expect(isSliceOf(.Struct)([]struct {}));
    testing.expect(!isSliceOf(.Struct)([][]struct {}));
}

///////////Strait trait Fns

//@TODO:
// Somewhat limited since we can't apply this logic to normal variables, fields, or
//  Fns yet. Should be isExternType?
pub fn isExtern(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Struct => |s| s.layout == .Extern,
        .Union => |u| u.layout == .Extern,
        .Enum => |e| e.layout == .Extern,
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
    return switch (@typeInfo(T)) {
        .Struct => |s| s.layout == .Packed,
        .Union => |u| u.layout == .Packed,
        .Enum => |e| e.layout == .Packed,
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
    return switch (@typeInfo(T)) {
        .Int => |i| !i.is_signed,
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
    return switch (@typeInfo(T)) {
        .ComptimeInt => true,
        .Int => |i| i.is_signed,
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
    if (comptime is(.Pointer)(T)) {
        return @typeInfo(T).Pointer.size == .One;
    }
    return false;
}

test "std.meta.trait.isSingleItemPtr" {
    const array = [_]u8{0} ** 10;
    comptime testing.expect(isSingleItemPtr(@TypeOf(&array[0])));
    comptime testing.expect(!isSingleItemPtr(@TypeOf(array)));
    var runtime_zero: usize = 0;
    testing.expect(!isSingleItemPtr(@TypeOf(array[runtime_zero..1])));
}

pub fn isManyItemPtr(comptime T: type) bool {
    if (comptime is(.Pointer)(T)) {
        return @typeInfo(T).Pointer.size == .Many;
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
    if (comptime is(.Pointer)(T)) {
        return @typeInfo(T).Pointer.size == .Slice;
    }
    return false;
}

test "std.meta.trait.isSlice" {
    const array = [_]u8{0} ** 10;
    var runtime_zero: usize = 0;
    testing.expect(isSlice(@TypeOf(array[runtime_zero..])));
    testing.expect(!isSlice(@TypeOf(array)));
    testing.expect(!isSlice(@TypeOf(&array[0])));
}

pub fn isIndexable(comptime T: type) bool {
    if (comptime is(.Pointer)(T)) {
        if (@typeInfo(T).Pointer.size == .One) {
            return (comptime is(.Array)(meta.Child(T)));
        }
        return true;
    }
    return comptime is(.Array)(T) or is(.Vector)(T);
}

test "std.meta.trait.isIndexable" {
    const array = [_]u8{0} ** 10;
    const slice = @as([]const u8, &array);
    const vector: meta.Vector(2, u32) = [_]u32{0} ** 2;

    testing.expect(isIndexable(@TypeOf(array)));
    testing.expect(isIndexable(@TypeOf(&array)));
    testing.expect(isIndexable(@TypeOf(slice)));
    testing.expect(!isIndexable(meta.Child(@TypeOf(slice))));
    testing.expect(isIndexable(@TypeOf(vector)));
}

pub fn isNumber(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Int, .Float, .ComptimeInt, .ComptimeFloat => true,
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
    if (!comptime is(.Pointer)(T)) return false;
    return @typeInfo(T).Pointer.is_const;
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
    return switch (@typeInfo(T)) {
        .Struct, .Union, .Enum => true,
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

pub fn isTuple(comptime T: type) bool {
    return is(.Struct)(T) and @typeInfo(T).Struct.is_tuple;
}

test "std.meta.trait.isTuple" {
    const t1 = struct {};
    const t2 = .{ .a = 0 };
    const t3 = .{ 1, 2, 3 };
    testing.expect(!isTuple(t1));
    testing.expect(!isTuple(@TypeOf(t2)));
    testing.expect(isTuple(@TypeOf(t3)));
}

pub fn hasDecls(comptime T: type, comptime names: anytype) bool {
    inline for (names) |name| {
        if (!@hasDecl(T, name))
            return false;
    }
    return true;
}

test "std.meta.trait.hasDecls" {
    const TestStruct1 = struct {};
    const TestStruct2 = struct {
        pub var a: u32;
        pub var b: u32;
        c: bool,
        pub fn useless() void {}
    };

    const tuple = .{ "a", "b", "c" };

    testing.expect(!hasDecls(TestStruct1, .{"a"}));
    testing.expect(hasDecls(TestStruct2, .{ "a", "b" }));
    testing.expect(hasDecls(TestStruct2, .{ "a", "b", "useless" }));
    testing.expect(!hasDecls(TestStruct2, .{ "a", "b", "c" }));
    testing.expect(!hasDecls(TestStruct2, tuple));
}

pub fn hasFields(comptime T: type, comptime names: anytype) bool {
    inline for (names) |name| {
        if (!@hasField(T, name))
            return false;
    }
    return true;
}

test "std.meta.trait.hasFields" {
    const TestStruct1 = struct {};
    const TestStruct2 = struct {
        a: u32,
        b: u32,
        c: bool,
        pub fn useless() void {}
    };

    const tuple = .{ "a", "b", "c" };

    testing.expect(!hasFields(TestStruct1, .{"a"}));
    testing.expect(hasFields(TestStruct2, .{ "a", "b" }));
    testing.expect(hasFields(TestStruct2, .{ "a", "b", "c" }));
    testing.expect(hasFields(TestStruct2, tuple));
    testing.expect(!hasFields(TestStruct2, .{ "a", "b", "useless" }));
}

pub fn hasFunctions(comptime T: type, comptime names: anytype) bool {
    inline for (names) |name| {
        if (!hasFn(name)(T))
            return false;
    }
    return true;
}

test "std.meta.trait.hasFunctions" {
    const TestStruct1 = struct {};
    const TestStruct2 = struct {
        pub fn a() void {}
        fn b() void {}
    };

    const tuple = .{ "a", "b", "c" };

    testing.expect(!hasFunctions(TestStruct1, .{"a"}));
    testing.expect(hasFunctions(TestStruct2, .{ "a", "b" }));
    testing.expect(!hasFunctions(TestStruct2, .{ "a", "b", "c" }));
    testing.expect(!hasFunctions(TestStruct2, tuple));
}

/// True if every value of the type `T` has a unique bit pattern representing it.
/// In other words, `T` has no unused bits and no padding.
pub fn hasUniqueRepresentation(comptime T: type) bool {
    switch (@typeInfo(T)) {
        else => return false, // TODO can we know if it's true for some of these types ?

        .AnyFrame,
        .Bool,
        .BoundFn,
        .Enum,
        .ErrorSet,
        .Fn,
        .Int, // TODO check that it is still true
        .Pointer,
        => return true,

        .Array => |info| return comptime hasUniqueRepresentation(info.child),

        .Struct => |info| {
            var sum_size = @as(usize, 0);

            inline for (info.fields) |field| {
                const FieldType = field.field_type;
                if (comptime !hasUniqueRepresentation(FieldType)) return false;
                sum_size += @sizeOf(FieldType);
            }

            return @sizeOf(T) == sum_size;
        },

        .Vector => |info| return comptime hasUniqueRepresentation(info.child),
    }
}

test "std.meta.trait.hasUniqueRepresentation" {
    const TestStruct1 = struct {
        a: u32,
        b: u32,
    };

    testing.expect(hasUniqueRepresentation(TestStruct1));

    const TestStruct2 = struct {
        a: u32,
        b: u16,
    };

    testing.expect(!hasUniqueRepresentation(TestStruct2));

    const TestStruct3 = struct {
        a: u32,
        b: u32,
    };

    testing.expect(hasUniqueRepresentation(TestStruct3));

    testing.expect(hasUniqueRepresentation(i1));
    testing.expect(hasUniqueRepresentation(u2));
    testing.expect(hasUniqueRepresentation(i3));
    testing.expect(hasUniqueRepresentation(u4));
    testing.expect(hasUniqueRepresentation(i5));
    testing.expect(hasUniqueRepresentation(u6));
    testing.expect(hasUniqueRepresentation(i7));
    testing.expect(hasUniqueRepresentation(u8));
    testing.expect(hasUniqueRepresentation(i9));
    testing.expect(hasUniqueRepresentation(u10));
}
