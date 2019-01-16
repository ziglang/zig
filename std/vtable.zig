const std = @import("index.zig");
const builtin = @import("builtin");
const debug = std.debug;

const TypeInfo = builtin.TypeInfo;

pub fn populate(comptime VTable: type, comptime Functions: type, comptime T: type) *const VTable {
    const GlobalStorage = struct {
        const vtable = blk: {
            var res: VTable = undefined;
            inline for (@typeInfo(VTable).Struct.fields) |field| {
                const Fn =@typeOf(@field(res, field.name));
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
                //debug.assert(Expect.return_type.? == Actual.return_type.?);
                debug.assert(Expect.args.len == Actual.args.len);


                for (Expect.args) |expect_arg, i| {
                    const actual_arg = Actual.args[i];
                    debug.assert(!expect_arg.is_generic);
                    debug.assert(expect_arg.is_generic == actual_arg.is_generic);
                    debug.assert(expect_arg.is_noalias == actual_arg.is_noalias);


                    // For the first arg. We enforce that it is a pointer, and
                    // that the actual function takes *T.
                    //if (i == 0) {
                    //    const expect_ptr = @typeInfo(expect_arg.arg_type.?).Pointer;
                    //    const actual_ptr = @typeInfo(actual_arg.arg_type.?).Pointer;
                    //    debug.assert(expect_ptr.size == TypeInfo.Pointer.Size.One);
                    //    debug.assert(expect_ptr.size == actual_ptr.size);
                    //    debug.assert(expect_ptr.is_const == actual_ptr.is_const);
                    //    debug.assert(expect_ptr.is_volatile == actual_ptr.is_volatile);
                    //    debug.assert(actual_ptr.child == T);
                    //} else {
                    //    debug.assert(expect_arg.arg_type.? == actual_arg.arg_type.?);
                    //}
                }

                @field(res, field.name) = @ptrCast(Fn, @field(T, field.name));
            }

            break :blk res;
        };
    };

    return &GlobalStorage.vtable;
}