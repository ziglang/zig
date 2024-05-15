const builtin = @import("builtin");

test {
    _ = @import("behavior/align.zig");
    _ = @import("behavior/alignof.zig");
    _ = @import("behavior/array.zig");
    _ = @import("behavior/async_fn.zig");
    _ = @import("behavior/atomics.zig");
    _ = @import("behavior/await_struct.zig");
    _ = @import("behavior/basic.zig");
    _ = @import("behavior/bit_shifting.zig");
    _ = @import("behavior/bitcast.zig");
    _ = @import("behavior/bitreverse.zig");
    _ = @import("behavior/bool.zig");
    _ = @import("behavior/byteswap.zig");
    _ = @import("behavior/byval_arg_var.zig");
    _ = @import("behavior/call.zig");
    _ = @import("behavior/call_tail.zig");
    _ = @import("behavior/cast.zig");
    _ = @import("behavior/cast_int.zig");
    _ = @import("behavior/comptime_memory.zig");
    _ = @import("behavior/const_slice_child.zig");
    _ = @import("behavior/decltest.zig");
    _ = @import("behavior/duplicated_test_names.zig");
    _ = @import("behavior/defer.zig");
    _ = @import("behavior/destructure.zig");
    _ = @import("behavior/empty_tuple_fields.zig");
    _ = @import("behavior/empty_union.zig");
    _ = @import("behavior/enum.zig");
    _ = @import("behavior/error.zig");
    _ = @import("behavior/eval.zig");
    _ = @import("behavior/export_builtin.zig");
    _ = @import("behavior/export_self_referential_type_info.zig");
    _ = @import("behavior/extern.zig");
    _ = @import("behavior/field_parent_ptr.zig");
    _ = @import("behavior/floatop.zig");
    _ = @import("behavior/fn.zig");
    _ = @import("behavior/fn_delegation.zig");
    _ = @import("behavior/fn_in_struct_in_comptime.zig");
    _ = @import("behavior/for.zig");
    _ = @import("behavior/generics.zig");
    _ = @import("behavior/globals.zig");
    _ = @import("behavior/hasdecl.zig");
    _ = @import("behavior/hasfield.zig");
    _ = @import("behavior/if.zig");
    _ = @import("behavior/import.zig");
    _ = @import("behavior/import_c_keywords.zig");
    _ = @import("behavior/incomplete_struct_param_tld.zig");
    _ = @import("behavior/inline_switch.zig");
    _ = @import("behavior/int128.zig");
    _ = @import("behavior/int_comparison_elision.zig");
    _ = @import("behavior/ptrfromint.zig");
    _ = @import("behavior/ir_block_deps.zig");
    _ = @import("behavior/lower_strlit_to_vector.zig");
    _ = @import("behavior/math.zig");
    _ = @import("behavior/maximum_minimum.zig");
    _ = @import("behavior/member_func.zig");
    _ = @import("behavior/memcpy.zig");
    _ = @import("behavior/memset.zig");
    _ = @import("behavior/merge_error_sets.zig");
    _ = @import("behavior/muladd.zig");
    _ = @import("behavior/multiple_externs_with_conflicting_types.zig");
    _ = @import("behavior/namespace_depends_on_compile_var.zig");
    _ = @import("behavior/nan.zig");
    _ = @import("behavior/null.zig");
    _ = @import("behavior/optional.zig");
    _ = @import("behavior/packed-struct.zig");
    _ = @import("behavior/packed_struct_explicit_backing_int.zig");
    _ = @import("behavior/packed-union.zig");
    _ = @import("behavior/pointers.zig");
    _ = @import("behavior/popcount.zig");
    _ = @import("behavior/prefetch.zig");
    _ = @import("behavior/ptrcast.zig");
    _ = @import("behavior/pub_enum.zig");
    _ = @import("behavior/ref_var_in_if_after_if_2nd_switch_prong.zig");
    _ = @import("behavior/reflection.zig");
    _ = @import("behavior/return_address.zig");
    _ = @import("behavior/saturating_arithmetic.zig");
    _ = @import("behavior/select.zig");
    _ = @import("behavior/shuffle.zig");
    _ = @import("behavior/sizeof_and_typeof.zig");
    _ = @import("behavior/slice.zig");
    _ = @import("behavior/slice_sentinel_comptime.zig");
    _ = @import("behavior/src.zig");
    _ = @import("behavior/string_literals.zig");
    _ = @import("behavior/struct.zig");
    _ = @import("behavior/struct_contains_null_ptr_itself.zig");
    _ = @import("behavior/struct_contains_slice_of_itself.zig");
    _ = @import("behavior/switch.zig");
    _ = @import("behavior/switch_prong_err_enum.zig");
    _ = @import("behavior/switch_prong_implicit_cast.zig");
    _ = @import("behavior/switch_on_captured_error.zig");
    _ = @import("behavior/this.zig");
    _ = @import("behavior/threadlocal.zig");
    _ = @import("behavior/truncate.zig");
    _ = @import("behavior/try.zig");
    _ = @import("behavior/tuple.zig");
    _ = @import("behavior/tuple_declarations.zig");
    _ = @import("behavior/type.zig");
    _ = @import("behavior/type_info.zig");
    _ = @import("behavior/type_info_mul_linksection_addrspace_decls.zig");
    _ = @import("behavior/typename.zig");
    _ = @import("behavior/undefined.zig");
    _ = @import("behavior/underscore.zig");
    _ = @import("behavior/union.zig");
    _ = @import("behavior/union_with_members.zig");
    _ = @import("behavior/usingnamespace.zig");
    _ = @import("behavior/var_args.zig");
    _ = @import("behavior/vector.zig");
    _ = @import("behavior/void.zig");
    _ = @import("behavior/while.zig");
    _ = @import("behavior/widening.zig");
    _ = @import("behavior/abs.zig");

    if (builtin.cpu.arch == .wasm32) {
        _ = @import("behavior/wasm.zig");
    }

    if (builtin.os.tag != .wasi) {
        _ = @import("behavior/asm.zig");
    }

    if (builtin.zig_backend != .stage2_arm and
        builtin.zig_backend != .stage2_aarch64 and
        builtin.zig_backend != .stage2_spirv64)
    {
        _ = @import("behavior/export_keyword.zig");
    }
}

// This bug only repros in the root file
test "deference @embedFile() of a file full of zero bytes" {
    const contents = @embedFile("behavior/zero.bin").*;
    try @import("std").testing.expect(contents.len == 456);
    for (contents) |byte| try @import("std").testing.expect(byte == 0);
}
