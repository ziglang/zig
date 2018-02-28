const builtin = @import("builtin");

comptime {
    _ = @import("cases/align.zig");
    _ = @import("cases/alignof.zig");
    _ = @import("cases/array.zig");
    _ = @import("cases/asm.zig");
    _ = @import("cases/atomics.zig");
    _ = @import("cases/bitcast.zig");
    _ = @import("cases/bool.zig");
    _ = @import("cases/bugs/394.zig");
    _ = @import("cases/bugs/655.zig");
    _ = @import("cases/bugs/656.zig");
    _ = @import("cases/cast.zig");
    _ = @import("cases/const_slice_child.zig");
    _ = @import("cases/defer.zig");
    _ = @import("cases/enum.zig");
    _ = @import("cases/enum_with_members.zig");
    _ = @import("cases/error.zig");
    _ = @import("cases/eval.zig");
    _ = @import("cases/field_parent_ptr.zig");
    _ = @import("cases/fn.zig");
    _ = @import("cases/for.zig");
    _ = @import("cases/generics.zig");
    _ = @import("cases/if.zig");
    _ = @import("cases/import.zig");
    _ = @import("cases/incomplete_struct_param_tld.zig");
    _ = @import("cases/ir_block_deps.zig");
    _ = @import("cases/math.zig");
    _ = @import("cases/misc.zig");
    _ = @import("cases/namespace_depends_on_compile_var/index.zig");
    _ = @import("cases/null.zig");
    _ = @import("cases/pub_enum/index.zig");
    _ = @import("cases/ref_var_in_if_after_if_2nd_switch_prong.zig");
    _ = @import("cases/reflection.zig");
    _ = @import("cases/sizeof_and_typeof.zig");
    _ = @import("cases/slice.zig");
    _ = @import("cases/struct.zig");
    _ = @import("cases/struct_contains_null_ptr_itself.zig");
    _ = @import("cases/struct_contains_slice_of_itself.zig");
    _ = @import("cases/switch.zig");
    _ = @import("cases/switch_prong_err_enum.zig");
    _ = @import("cases/switch_prong_implicit_cast.zig");
    _ = @import("cases/syntax.zig");
    _ = @import("cases/this.zig");
    _ = @import("cases/try.zig");
    _ = @import("cases/undefined.zig");
    _ = @import("cases/union.zig");
    _ = @import("cases/var_args.zig");
    _ = @import("cases/void.zig");
    _ = @import("cases/while.zig");


    // LLVM 5.0.1, 6.0.0, and trunk crash when attempting to optimize coroutine code.
    // So, Zig does not support ReleaseFast or ReleaseSafe for coroutines yet.
    // Luckily, Clang users are running into the same crashes, so folks from the LLVM
    // community are working on fixes. If we're really lucky they'll be fixed in 6.0.1.
    // Otherwise we can hope for 7.0.0.
    if (builtin.mode == builtin.Mode.Debug) {
        _ = @import("cases/coroutines.zig");
    }

}
