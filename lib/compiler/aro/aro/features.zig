const std = @import("std");
const Compilation = @import("Compilation.zig");
const target_util = @import("target.zig");

/// Used to implement the __has_feature macro.
pub fn hasFeature(comp: *Compilation, ext: []const u8) bool {
    const list = .{
        .assume_nonnull = true,
        .attribute_analyzer_noreturn = true,
        .attribute_availability = true,
        .attribute_availability_with_message = true,
        .attribute_availability_app_extension = true,
        .attribute_availability_with_version_underscores = true,
        .attribute_availability_tvos = true,
        .attribute_availability_watchos = true,
        .attribute_availability_with_strict = true,
        .attribute_availability_with_replacement = true,
        .attribute_availability_in_templates = true,
        .attribute_availability_swift = true,
        .attribute_cf_returns_not_retained = true,
        .attribute_cf_returns_retained = true,
        .attribute_cf_returns_on_parameters = true,
        .attribute_deprecated_with_message = true,
        .attribute_deprecated_with_replacement = true,
        .attribute_ext_vector_type = true,
        .attribute_ns_returns_not_retained = true,
        .attribute_ns_returns_retained = true,
        .attribute_ns_consumes_self = true,
        .attribute_ns_consumed = true,
        .attribute_cf_consumed = true,
        .attribute_overloadable = true,
        .attribute_unavailable_with_message = true,
        .attribute_unused_on_fields = true,
        .attribute_diagnose_if_objc = true,
        .blocks = false, // TODO
        .c_thread_safety_attributes = true,
        .enumerator_attributes = true,
        .nullability = true,
        .nullability_on_arrays = true,
        .nullability_nullable_result = true,
        .c_alignas = comp.langopts.standard.atLeast(.c11),
        .c_alignof = comp.langopts.standard.atLeast(.c11),
        .c_atomic = comp.langopts.standard.atLeast(.c11),
        .c_generic_selections = comp.langopts.standard.atLeast(.c11),
        .c_static_assert = comp.langopts.standard.atLeast(.c11),
        .c_thread_local = comp.langopts.standard.atLeast(.c11) and target_util.isTlsSupported(comp.target),
    };
    inline for (std.meta.fields(@TypeOf(list))) |f| {
        if (std.mem.eql(u8, f.name, ext)) return @field(list, f.name);
    }
    return false;
}

/// Used to implement the __has_extension macro.
pub fn hasExtension(comp: *Compilation, ext: []const u8) bool {
    const list = .{
        // C11 features
        .c_alignas = true,
        .c_alignof = true,
        .c_atomic = false, // TODO
        .c_generic_selections = true,
        .c_static_assert = true,
        .c_thread_local = target_util.isTlsSupported(comp.target),
        // misc
        .overloadable_unmarked = false, // TODO
        .statement_attributes_with_gnu_syntax = false, // TODO
        .gnu_asm = true,
        .gnu_asm_goto_with_outputs = true,
        .matrix_types = false, // TODO
        .matrix_types_scalar_division = false, // TODO
    };
    inline for (std.meta.fields(@TypeOf(list))) |f| {
        if (std.mem.eql(u8, f.name, ext)) return @field(list, f.name);
    }
    return false;
}
