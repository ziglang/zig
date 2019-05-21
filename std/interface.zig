//@TODO: Fix std/hash_map.zig and src-self-hosted.zig to use comptime rng again when that is fixed!

const std = @import("std");
const debug = std.debug;
const testing = std.testing;

pub const Any = ?*@OpaqueType();
pub const ConstAny = ?*const @OpaqueType();
pub const Unused = ?*@OpaqueType();

pub fn toAny(self: var) Any {
    const T = @typeOf(self);
    if (@alignOf(T) == 0 or @sizeOf(T) == 0) @compileError(@typeName(T) ++ " is a 0-bit type. " ++ 
        "assign 'null' instead and ensure first parameter of implementatin Fns is Any");
    return @ptrCast(Any, self);
}

pub fn fromAny(comptime T: type, any: Any) *T {
    const aligned = @alignCast(@alignOf(T), any);
    return @ptrCast(*T, aligned);
}

pub fn toConstAny(self: var) ConstAny
{
    const T = @typeOf(self);
    if (@alignOf(T) == 0 or  @sizeOf(T) == 0) @compileError(@typeName(T) ++ " is a 0-bit type. " ++ 
        "assign 'null' instead and ensure first parameter of implementatin Fns is Any");
    return @ptrCast(ConstAny, self);
}

pub fn fromConstAny(comptime T: type, any: ConstAny) *const T {
    const aligned = @alignCast(@alignOf(T), any);
    return @ptrCast(*const T, aligned);
}

pub fn abstractFn(comptime AbstractFunc: type, func: var) AbstractFunc {
    const ImplementationFunc = @typeOf(func);
    const impl_func_info = @typeInfo(ImplementationFunc).Fn;
    const abs_func_info = @typeInfo(AbstractFunc).Fn;
    debug.assert(!abs_func_info.is_generic);
    debug.assert(!abs_func_info.is_var_args);
    debug.assert(abs_func_info.args.len > 0);
    debug.assert(abs_func_info.async_allocator_type == null);
    
    debug.assert(impl_func_info.async_allocator_type == null);
    
    debug.assert(abs_func_info.calling_convention == impl_func_info.calling_convention);
    debug.assert(abs_func_info.is_generic == impl_func_info.is_generic);
    debug.assert(abs_func_info.is_var_args == impl_func_info.is_var_args);
    
    if (comptime std.meta.trait.is(.ErrorUnion)(abs_func_info.return_type.?)) {
        const abs_eu_info = @typeInfo(abs_func_info.return_type.?).ErrorUnion;
        const impl_eu_info = @typeInfo(impl_func_info.return_type.?).ErrorUnion;
        const AbsError = abs_eu_info.error_set;
        const ImplError = impl_eu_info.error_set;
        debug.assert(std.meta.trait.isErrorSubset(AbsError)(ImplError));
        debug.assert(abs_eu_info.payload == impl_eu_info.payload); 
    } else {
        debug.assert(abs_func_info.return_type.? == impl_func_info.return_type.?);
    }
    
    debug.assert(abs_func_info.args.len == impl_func_info.args.len);

    inline for (abs_func_info.args) |abs_arg, i| {
        const impl_arg = impl_func_info.args[i];
        debug.assert(!abs_arg.is_generic);
        debug.assert(abs_arg.is_generic == impl_arg.is_generic);
        debug.assert(abs_arg.is_noalias == impl_arg.is_noalias);
        
        //If arg is Any or ConstAny, ensure it is a pointer or optional pointer.
        // In the latter case, additionally ensure that it is const.
        switch (abs_arg.arg_type.?) {
            Any, ConstAny => {
                //This will handle asserting that it is a pointer or optional pointer
                const impl_arg_ptr = switch (@typeInfo(impl_arg.arg_type.?)) {
                    .Optional => |o| @typeInfo(o.child).Pointer,
                    .Pointer => |p| p,
                    else => unreachable,
                };
                if (abs_arg.arg_type.? == ConstAny) debug.assert(impl_arg_ptr.is_const);
            },
            else => debug.assert(abs_arg.arg_type.? == impl_arg.arg_type.?),
        }
    }

    return @ptrCast(AbstractFunc, func);
}

const AnyNameFn = fn(Any, usize)anyerror![]const u8;
const AnyTestInterface = TestInterface(Any, AnyNameFn);
fn TestInterface(comptime T: type, comptime NameFn: type) type {
    return struct {
        impl: T,
        nameFn: NameFn,
        
        pub fn name(self: *@This()) ![]const u8 {
            //0-bit T would make the first argument not get passed at all
            // which would break an abstracted interface. The second parameter
            // is used to verif that didn't happen.
            return self.nameFn(self.impl, std.math.maxInt(usize));
        }
        
        pub fn toAny(self: *@This()) AnyTestInterface {
            return AnyTestInterface {
                //unfortunate naming conflict
                .impl = std.interface.toAny(self.impl),
                .nameFn = abstractFn(AnyNameFn, self.nameFn),
            };
        }
    };
}

fn testExpectedErrorSet(comptime Func: type, comptime Error: type) void {
    const error_union = @typeInfo(Func).Fn.return_type.?;
    const FuncError = @typeInfo(error_union).ErrorUnion.error_set;

    testing.expect(std.meta.trait.isErrorSubset(FuncError)(Error) and
        std.meta.trait.isErrorSubset(Error)(FuncError));
}

test "interface" {
    //An implementation with no fields
    //Must use `Any` instead of `*Self` because 0-bit types would get passed at all
    // so `name` would expect 1 parameter, not two, while AnyTestInterface would
    // pass two anyway.
    const NullImpl = struct {
        const Self = @This();
        
        pub fn name(self: Unused, id: usize) error{}![]const u8 {
            //Verify we didn't get unexpected paramters due to the above mentioned
            // quality of 0-bit types.
            testing.expect(id == std.math.maxInt(usize));
            return "Null";
        }
        
        const TestInterfaceImpl = TestInterface(Unused, @typeOf(name));
        pub fn testInterface(self: var) TestInterfaceImpl {
            return TestInterfaceImpl {
                .impl = null,
                .nameFn = name,
            };
        }
    };
    
    const ValImpl = struct {
        const Self = @This();
        
        val: []const u8,
        
        pub fn init(val: []const u8) Self {
            return Self {
                .val = val,
            };
        }
        
        pub fn name(self: *Self, id: usize) ![]const u8 {
            testing.expect(id == std.math.maxInt(usize));
            if(self.val.len < 5) return error.NameTooShort;
            return self.val;
        }
        
        const TestInterfaceImpl = TestInterface(*Self, @typeOf(name));
        pub fn testInterface(self: *Self) TestInterfaceImpl {
            return TestInterfaceImpl {
                .impl = self,
                .nameFn = name,
            };
        }
    };
    
    var nimpl = NullImpl{};
    var vimpl = ValImpl.init("Value");
    
    //test normal "comptime" interface
    var n_iface = nimpl.testInterface();
    var name = try n_iface.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    testExpectedErrorSet(@typeOf(@typeOf(n_iface).name), error{});
    
    var v_iface = vimpl.testInterface();
    name = try v_iface.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    testExpectedErrorSet(@typeOf(@typeOf(v_iface).name), error{ NameTooShort, });
    
    //test abstracted "runtime" interface
    var iface = n_iface.toAny();
    name = try iface.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    testExpectedErrorSet(@typeOf(@typeOf(iface).name), anyerror);
    
    iface = v_iface.toAny();
    name = try iface.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    testExpectedErrorSet(@typeOf(@typeOf(iface).name), anyerror);
    
    //"comptime" and "runtime" interface pointers
    var n_iface_ptr = &n_iface;
    name = try n_iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    var iface_ptr = &n_iface_ptr.toAny();
    name = try iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    
    var v_iface_ptr = &v_iface;
    name = try v_iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    iface_ptr = &v_iface_ptr.toAny();
    name = try iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    
    //See #2487, also #2501
    //comptime
    //{
    //    var ct_iface = ValImpl.init("Comptime").testInterface().toAny();
    //    std.testing.expect(std.mem.eql(u8, try ct_iface.name(), "Comptime"));
    //}
}