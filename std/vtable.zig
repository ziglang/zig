const std = @import("index.zig");
const builtin = @import("builtin");
const debug = std.debug;
const meta = std.meta;
const trait = meta.trait;

const TypeInfo = builtin.TypeInfo;

pub fn populate(comptime VTable: type, comptime Functions: type, comptime T: type) *const VTable {
    const GlobalStorage = struct {
        const vtable = blk: {
            var res: VTable = undefined;
            inline for (@typeInfo(VTable).Struct.fields) |field| {
                const Fn = @typeOf(@field(res, field.name));
                const Expect = @typeInfo(Fn).Fn;
                const Actual = @typeInfo(@typeOf(@field(Functions, field.name))).Fn;
                debug.assert(!Expect.is_generic);
                debug.assert(!Expect.is_var_args);
                debug.assert(Expect.args.len > 0);
                debug.assert(Expect.async_allocator_type == null);
                debug.assert(Actual.async_allocator_type == null);
                debug.assert(Expect.calling_convention == Actual.calling_convention);
                debug.assert(Expect.is_generic == Actual.is_generic);
                debug.assert(Expect.is_var_args == Actual.is_var_args);
                
                if (comptime trait.is(builtin.TypeId.ErrorUnion)(Expect.return_type.?)) {
                    const expect_eu_info = @typeInfo(Expect.return_type.?).ErrorUnion;
                    const actual_eu_info = @typeInfo(Actual.return_type.?).ErrorUnion;
                    const expect_error = expect_eu_info.error_set;
                    const actual_error = actual_eu_info.error_set;
                    debug.assert(trait.isErrorSubset(expect_error)(actual_error));
                    debug.assert(expect_eu_info.payload == actual_eu_info.payload);
                    
                } else {
                    debug.assert(Expect.return_type.? == Actual.return_type.?);
                }
                
                debug.assert(Expect.args.len == Actual.args.len);

                for (Expect.args) |expect_arg, i| {
                    const actual_arg = Actual.args[i];
                    debug.assert(!expect_arg.is_generic);
                    debug.assert(expect_arg.is_generic == actual_arg.is_generic);
                    debug.assert(expect_arg.is_noalias == actual_arg.is_noalias);

                    // For the first arg. We enforce that it is a pointer, and
                    // that the actual function takes *T.
                    if (i == 0) {
                        const expect_ptr = @typeInfo(expect_arg.arg_type.?).Pointer;
                        const actual_ptr = @typeInfo(actual_arg.arg_type.?).Pointer;
                        debug.assert(expect_ptr.size == TypeInfo.Pointer.Size.One);
                        debug.assert(expect_ptr.size == actual_ptr.size);
                        
                        // For constness, we only assert that actual is const if the
                        // expected function specifies const
                        if (expect_ptr.is_const) debug.assert(actual_ptr.is_const);
                        debug.assert(expect_ptr.is_volatile == actual_ptr.is_volatile);
                        debug.assert(actual_ptr.child == T);
                    } else {
                        debug.assert(expect_arg.arg_type.? == actual_arg.arg_type.?);
                    }
                }

                @field(res, field.name) = @ptrCast(Fn, @field(T, field.name));
            }

            break :blk res;
        };
    };

    return &GlobalStorage.vtable;
}

test "std.vtable" {
    const AbstractInterface = struct {
        const Self = @This();
        
        const VTable = struct {
            foo: fn(Context, usize) anyerror!usize,
        };
        const Context = *@OpaqueType();
         
        vtable: *const VTable,
        impl: Context,

        pub fn init(impl: var) Self {
            const T = comptime meta.Child(@typeOf(impl));
            return Self {
                .vtable = comptime std.vtable.populate(VTable, T, T),
                .impl = @ptrCast(Context, impl),
            };
        }
        
        pub fn foo(self: Self, x: usize) anyerror!usize {
            return self.vtable.foo(self.impl, x);
        }
    };
    
    const WorkingImpl = struct {
        const Self = @This();
    
        x: usize,

        pub const Error = error{TooLarge};
    
        pub fn foo(self: *Self, x: usize) Error!usize {
            if (x > 42) return error.TooLarge;
            self.x += x;
            return self.x;
        }
    };
    
    var works = WorkingImpl{ .x = 0, };
    var works_iface = AbstractInterface.init(&works);
    debug.assert((try works_iface.foo(10)) == 10);
    debug.warn("{}", try works_iface.foo(20));
}