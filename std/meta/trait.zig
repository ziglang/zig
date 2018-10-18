const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const debug = std.debug;
const warn = debug.warn;

const meta = @import("index.zig");

//This is necessary if we want to return generic functions directly because of how the
// the type erasure works. see:  #1375
fn traitFnWorkaround(comptime T: type) bool
{
    return false;
}

pub const TraitFn = @typeOf(traitFnWorkaround);

///

//////Trait generators

//Need TraitList because compiler can't do varargs at comptime yet
pub const TraitList = []const TraitFn;
pub fn multiTrait(comptime traits: TraitList) TraitFn
{
    const Closure = struct.
    {
        pub fn trait(comptime T: type) bool
        {
            comptime
            {
                for(traits) |t| if(!t(T)) return false;
                return true;
            }
        }
    };
    return Closure.trait;
}

test "std.trait.multiTrait"
{
    const Vector2 = struct.
    {
        const MyType = @This();
        
        x: u8,
        y: u8,
        
        pub fn add(self: MyType, other: MyType) MyType
        {
            return MyType.
            {
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }
    };
    
    const isVector = multiTrait
    (
        TraitList.
        {
            hasFn("add"),
            hasField("x"),
            hasField("y"),
        }
    );
    debug.assert(isVector(Vector2));
    debug.assert(!isVector(u8));
}

///

pub fn hasDef(comptime name: []const u8) TraitFn
{
    const Closure = struct.
    {
        pub fn trait(comptime T: type) bool
        {
            comptime
            {
                const info = @typeInfo(T);
                const defs = switch(info)
                {
                    builtin.TypeId.Struct => |s| s.defs,
                    builtin.TypeId.Union => |u| u.defs,
                    builtin.TypeId.Enum => |e| e.defs,
                    else => return false,
                };

                for(defs) |def|
                {
                    if(mem.eql(u8, def.name, name)) return def.is_pub;
                }
                
                return false;
            }
        }
    };
    return Closure.trait;
}

test "std.trait.hasDef"
{
    const TestStruct = struct.
    {
        pub const value = u8(16);
    };
    
    const TestStructFail = struct.
    {
        const value = u8(16);
    };

    debug.assert(hasDef("value")(TestStruct));
    debug.assert(!hasDef("value")(TestStructFail));
    debug.assert(!hasDef("value")(*TestStruct));
    debug.assert(!hasDef("value")(**TestStructFail));
    debug.assert(!hasDef("x")(TestStruct));
    debug.assert(!hasDef("value")(u8));
}

///
pub fn hasFn(comptime name: []const u8) TraitFn
{
    const Closure = struct.
    {
        pub fn trait(comptime T: type) bool
        {
            comptime
            {
                if(!hasDef(name)(T)) return false;
                const DefType = @typeOf(@field(T, name));
                const def_type_id = @typeId(DefType);
                return def_type_id == builtin.TypeId.Fn;
            }
        }
    };
    return Closure.trait;
}

test "std.trait.hasFn"
{
    const TestStruct = struct.
    {
        pub fn useless() void {}
    };

    debug.assert(hasFn("useless")(TestStruct));
    debug.assert(!hasFn("append")(TestStruct));
    debug.assert(!hasFn("useless")(u8));
}

///
pub fn hasField(comptime name: []const u8) TraitFn
{
    const Closure = struct.
    {
        pub fn trait(comptime T: type) bool
        {
            comptime
            {
                const info = @typeInfo(T);
                const fields = switch(info)
                {
                    builtin.TypeId.Struct => |s| s.fields,
                    builtin.TypeId.Union => |u| u.fields,
                    builtin.TypeId.Enum => |e| e.fields,
                    else => return false,
                };

                for(fields) |field|
                {
                    if(mem.eql(u8, field.name, name)) return true;
                }
                
                return false;
            }
        }
    };
    return Closure.trait;
}

test "std.trait.hasField"
{
    const TestStruct = struct.
    {
        value: u32,
    };

    debug.assert(hasField("value")(TestStruct));
    debug.assert(!hasField("value")(*TestStruct));
    debug.assert(!hasField("x")(TestStruct));
    debug.assert(!hasField("x")(**TestStruct));
    debug.assert(!hasField("value")(u8));
}

///

pub fn is(comptime id: builtin.TypeId) TraitFn
{
    const Closure = struct.
    {
        pub fn trait(comptime T: type) bool
        {
            comptime
            {
                return id == @typeId(T);
            }
        }
    };
    return Closure.trait;
}

test "std.trait.is"
{
    debug.assert(is(builtin.TypeId.Int)(u8));
    debug.assert(!is(builtin.TypeId.Int)(f32));
    debug.assert(is(builtin.TypeId.Pointer)(*u8));
    debug.assert(is(builtin.TypeId.Void)(void));
    debug.assert(!is(builtin.TypeId.Optional)(error));
}

///

pub fn isPtrTo(comptime id: builtin.TypeId) TraitFn
{
    const Closure = struct.
    {
        pub fn trait(comptime T: type) bool
        {
            comptime
            {
                if(!isSingleItemPtr(T)) return false;
                return id == @typeId(meta.Child(T));
            }
        }
    };
    return Closure.trait;
}

test "std.trait.isPtrTo"
{
    debug.assert(!isPtrTo(builtin.TypeId.Struct)(struct.{}));
    debug.assert(isPtrTo(builtin.TypeId.Struct)(*struct.{}));
    debug.assert(!isPtrTo(builtin.TypeId.Struct)(**struct.{}));
}


///////////Strait trait Fns

//@TODO:
// Somewhat limited since we can't apply this logic to normal variables, fields, or
//  Fns yet. Should be isExternType?
pub fn isExtern(comptime T: type) bool
{
    comptime
    {
        const Extern = builtin.TypeInfo.ContainerLayout.Extern;
        const info = @typeInfo(T);
        return switch(info)
        {
            builtin.TypeId.Struct => |s| s.layout == Extern,
            builtin.TypeId.Union => |u| u.layout == Extern,
            builtin.TypeId.Enum => |e| e.layout == Extern,
            else => false,
        };
    }
}

test "std.trait.isExtern"
{
    const TestExStruct = extern struct.{};
    const TestStruct = struct.{};

    debug.assert(isExtern(TestExStruct));
    debug.assert(!isExtern(TestStruct));
    debug.assert(!isExtern(u8));
}

///

pub fn isPacked(comptime T: type) bool
{
    comptime
    {
        const Packed = builtin.TypeInfo.ContainerLayout.Packed;
        const info = @typeInfo(T);
        return switch(info)
        {
            builtin.TypeId.Struct => |s| s.layout == Packed,
            builtin.TypeId.Union => |u| u.layout == Packed,
            builtin.TypeId.Enum => |e| e.layout == Packed,
            else => false,
        };
    }
}

test "std.trait.isPacked"
{
    const TestPStruct = packed struct.{};
    const TestStruct = struct.{};

    debug.assert(isPacked(TestPStruct));
    debug.assert(!isPacked(TestStruct));
    debug.assert(!isPacked(u8));
}

///

pub fn isSingleItemPtr(comptime T: type) bool
{
    comptime
    {
        if(is(builtin.TypeId.Pointer)(T))
        {
            const info = @typeInfo(T);
            return info.Pointer.size == builtin.TypeInfo.Pointer.Size.One;
        }
        return false;
    }
}

test "std.trait.isSingleItemPtr"
{
    const array = []u8.{0} ** 10;
    debug.assert(isSingleItemPtr(@typeOf(&array[0])));
    debug.assert(!isSingleItemPtr(@typeOf(array)));
    debug.assert(!isSingleItemPtr(@typeOf(array[0..1])));
}

///

pub fn isManyItemPtr(comptime T: type) bool
{
    comptime
    {
        if(is(builtin.TypeId.Pointer)(T))
        {
            const info = @typeInfo(T);
            return info.Pointer.size == builtin.TypeInfo.Pointer.Size.Many;
        }
        return false;
    }
}

test "std.trait.isManyItemPtr"
{
    const array = []u8.{0} ** 10;
    const mip = @ptrCast([*]const u8, &array[0]);
    debug.assert(isManyItemPtr(@typeOf(mip)));
    debug.assert(!isManyItemPtr(@typeOf(array)));
    debug.assert(!isManyItemPtr(@typeOf(array[0..1])));
}

///

pub fn isSlice(comptime T: type) bool
{
    comptime
    {
        if(is(builtin.TypeId.Pointer)(T))
        {
            const info = @typeInfo(T);
            return info.Pointer.size == builtin.TypeInfo.Pointer.Size.Slice;
        }
        return false;
    }
}

test "std.trait.isSlice"
{
    const array = []u8.{0} ** 10;
    debug.assert(isSlice(@typeOf(array[0..])));
    debug.assert(!isSlice(@typeOf(array)));
    debug.assert(!isSlice(@typeOf(&array[0])));
}

///

pub fn isIndexable(comptime T: type) bool
{
    comptime
    {
        if(is(builtin.TypeId.Pointer)(T))
        {
            const info = @typeInfo(T);
            if(info.Pointer.size == builtin.TypeInfo.Pointer.Size.One)
            {
                if(is(builtin.TypeId.Array)(meta.Child(T))) return true;
                return false;
            }
            return true;
        }
        return is(builtin.TypeId.Array)(T);
    }
}

test "std.trait.isIndexable"
{
    const array = []u8.{0} ** 10;
    const slice = array[0..];
    
    debug.assert(isIndexable(@typeOf(array)));
    debug.assert(isIndexable(@typeOf(&array)));
    debug.assert(isIndexable(@typeOf(slice)));
    debug.assert(!isIndexable(meta.Child(@typeOf(slice))));
}

///

pub fn isNumber(comptime T: type) bool
{
    comptime
    {
        return switch(@typeId(T))
        {
            builtin.TypeId.Int,
            builtin.TypeId.Float,
            builtin.TypeId.ComptimeInt,
            builtin.TypeId.ComptimeFloat => true,
            else => false,
        };
    }
}

test "std.trait.isNumber"
{
    const NotANumber = struct.
    {
        number: u8,
    };
    
    debug.assert(isNumber(u32));
    debug.assert(isNumber(f32));
    debug.assert(isNumber(u64));
    debug.assert(isNumber(@typeOf(102)));
    debug.assert(isNumber(@typeOf(102.123)));
    debug.assert(!isNumber([]u8));
    debug.assert(!isNumber(NotANumber));
}

///

pub fn isConstPtr(comptime T: type) bool
{
    comptime
    {
        if(!is(builtin.TypeId.Pointer)(T)) return false;
        const info = @typeInfo(T);
        return info.Pointer.is_const;
    }
}

test "std.trait.isConstPtr"
{
    var t = u8(0);
    const c = u8(0);
    debug.assert(isConstPtr(*const @typeOf(t)));
    debug.assert(isConstPtr(@typeOf(&c)));
    debug.assert(!isConstPtr(*@typeOf(t)));
    debug.assert(!isConstPtr(@typeOf(6)));
}

///

pub fn isContainer(comptime T: type) bool
{
    comptime
    {
        const info = @typeInfo(T);
        return switch(info)
        {
            builtin.TypeId.Struct => true,
            builtin.TypeId.Union => true,
            builtin.TypeId.Enum => true,
            else => false,
        };
    }
}

test "std.trait.isContainer"
{
    const TestStruct = struct.{};
    const TestUnion = union.{ a: void, };
    const TestEnum = enum.{ A, B, };
    
    debug.assert(isContainer(TestStruct));
    debug.assert(isContainer(TestUnion));
    debug.assert(isContainer(TestEnum));
    debug.assert(!isContainer(u8));
}

///