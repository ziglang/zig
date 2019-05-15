const std = @import("std");
const debug = std.debug;
const testing = std.testing;

pub const Any = ?*@OpaqueType();
pub const ConstAny = ?*const @OpaqueType();

pub fn toAny(self: var) Any {
    const T = @typeOf(self);
    if(@alignOf(T) == 0 or @sizeOf(T) == 0) return @intToPtr(Any, 0);
    return @ptrCast(Any, self);
}

pub fn fromAny(comptime T: type, any: Any) *T {
    const aligned = @alignCast(@alignOf(T), any);
    return @ptrCast(*T, aligned);
}

pub fn toConstAny(self: var) ConstAny
{
    const T = @typeOf(self);
    if(@alignOf(T) == 0 or  @sizeOf(T) == 0) return @intToPtr(AnyConst, 0);
    return @ptrCast(AnyConst, self);
}

pub fn fromConstAny(comptime T: type, any: ConstAny) *const T {
    const aligned = @alignCast(@alignOf(T), any);
    return @ptrCast(*const T, aligned);
}

pub fn abstractFn(comptime AbstractFunc: type, func: var) AbstractFunc
{
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
        switch(abs_arg.arg_type.?) {
            Any, ConstAny => |abs_arg_type| {
                //This will handle asserting that it is a pointer or optional pointer
                const impl_arg_ptr = switch(@typeInfo(impl_arg.arg_type.?)) {
                    .Optional => |o| @typeInfo(o.child).Pointer,
                    .Pointer => |p| p,
                    else => unreachable,
                };
                if(abs_arg_type == ConstAny) debug.assert(impl_arg_ptr.is_const);
            },
            else => debug.assert(abs_arg.arg_type.? == impl_arg.arg_type.?),
        }
    }

    return @ptrCast(AbstractFunc, func);
}

fn TestInterface(comptime T: type, comptime NameFn: type) type
{
    return struct
    {
        impl: T,
        nameFn: NameFn,
        
        const AnyNameFn = fn(Any)anyerror![]const u8;
        
        pub fn name(self: *@This()) ![]const u8
        {
            return self.nameFn(self.impl);
        }
        
        pub const Abstract = TestInterface(Any, AnyNameFn);
        pub fn abstract(self: *@This()) Abstract
        {
            return Abstract
            {
                .impl = toAny(self.impl),
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
    const NullImpl = struct
    {
        const Self = @This();
        
        pub fn name(self: *Self) error{}![]const u8
        {
            return "Null";
        }
        
        const NullImplInterface = TestInterface(*Self, @typeOf(name));
        pub fn interface(self: *Self) NullImplInterface
        {
            return NullImplInterface
            {
                .impl = self,
                .nameFn = name,
            };
        }
    };
    
    const ValImpl = struct
    {
        const Self = @This();
        
        val: []const u8,
        
        pub fn init(val: []const u8) Self
        {
            return Self
            {
                .val = val,
            };
        }
        
        pub fn name(self: *Self) ![]const u8
        {
            if(self.val.len < 5) return error.NameTooShort;
            return self.val;
        }
        
        const ValImplInterface = TestInterface(*Self, @typeOf(name));
        pub fn interface(self: *Self) ValImplInterface
        {
            return ValImplInterface
            {
                .impl = self,
                .nameFn = name,
            };
        }
    };
    
    var nimpl = NullImpl{};
    var vimpl = ValImpl.init("Value");
    
    //test normal "comptime" interface
    var n_iface = nimpl.interface();
    var name = try n_iface.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    testExpectedErrorSet(@typeOf(@typeOf(n_iface).name), error{});
    
    var v_iface = vimpl.interface();
    name = try v_iface.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    testExpectedErrorSet(@typeOf(@typeOf(v_iface).name), error{ NameTooShort, });
    
    //test abstracted "runtime" interface
    var iface = n_iface.abstract();
    name = try iface.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    testExpectedErrorSet(@typeOf(@typeOf(iface).name), anyerror);
    
    iface = v_iface.abstract();
    name = try iface.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    testExpectedErrorSet(@typeOf(@typeOf(iface).name), anyerror);
    
    //"comptime" and "runtime" interface pointers
    var n_iface_ptr = &n_iface;
    name = try n_iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    var iface_ptr = &n_iface_ptr.abstract();
    name = try iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Null"));
    
    var v_iface_ptr = &v_iface;
    name = try v_iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    iface_ptr = &v_iface_ptr.abstract();
    name = try iface_ptr.name();
    testing.expect(std.mem.eql(u8, name, "Value"));
    
    //See #2487
    //comptime
    //{
    //    var ct_iface = ValImpl.init("Comptime").interface().abstract();
    //    std.testing.expect(std.mem.eql(u8, try ct_iface.name(), "Comptime"));
    //}
}