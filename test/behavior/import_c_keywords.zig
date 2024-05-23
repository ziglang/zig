const builtin = @import("builtin");
const Id = @import("export_c_keywords.zig").Id;
const std = @import("std");

extern var int: Id;
extern var long: Id;
extern var an_alias_of_int: Id;

extern var some_non_c_keyword_variable: Id;
extern var @"void": Id;
extern var an_alias_of_some_non_c_keyword_variable: Id;

extern const @"if": Id;
extern const @"else": Id;
extern const an_alias_of_if: Id;

extern const some_non_c_keyword_constant: Id;
extern const @"switch": Id;
extern const an_alias_of_some_non_c_keyword_constant: Id;

extern fn float() Id;
extern fn double() Id;
extern fn an_alias_of_float() Id;

extern fn some_non_c_keyword_function() Id;
extern fn @"break"() Id;
extern fn an_alias_of_some_non_c_keyword_function() Id;

test "import c keywords" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt == .coff) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try std.testing.expect(int == .c_keyword_variable);
    try std.testing.expect(long == .c_keyword_variable);
    try std.testing.expect(an_alias_of_int == .c_keyword_variable);

    try std.testing.expect(some_non_c_keyword_variable == .non_c_keyword_variable);
    try std.testing.expect(@"void" == .non_c_keyword_variable);
    try std.testing.expect(an_alias_of_some_non_c_keyword_variable == .non_c_keyword_variable);

    try std.testing.expect(@"if" == .c_keyword_constant);
    try std.testing.expect(@"else" == .c_keyword_constant);
    try std.testing.expect(an_alias_of_if == .c_keyword_constant);

    try std.testing.expect(some_non_c_keyword_constant == .non_c_keyword_constant);
    try std.testing.expect(@"switch" == .non_c_keyword_constant);
    try std.testing.expect(an_alias_of_some_non_c_keyword_constant == .non_c_keyword_constant);

    try std.testing.expect(float() == .c_keyword_function);
    try std.testing.expect(double() == .c_keyword_function);
    try std.testing.expect(an_alias_of_float() == .c_keyword_function);

    try std.testing.expect(some_non_c_keyword_function() == .non_c_keyword_function);
    try std.testing.expect(@"break"() == .non_c_keyword_function);
    try std.testing.expect(an_alias_of_some_non_c_keyword_function() == .non_c_keyword_function);

    var ptr_id: *const Id = &long;
    try std.testing.expect(ptr_id == &int);
    ptr_id = &an_alias_of_int;
    try std.testing.expect(ptr_id == &int);

    ptr_id = &@"void";
    try std.testing.expect(ptr_id == &some_non_c_keyword_variable);
    ptr_id = &an_alias_of_some_non_c_keyword_variable;
    try std.testing.expect(ptr_id == &some_non_c_keyword_variable);

    ptr_id = &@"else";
    try std.testing.expect(ptr_id == &@"if");
    ptr_id = &an_alias_of_if;
    try std.testing.expect(ptr_id == &@"if");

    ptr_id = &@"switch";
    try std.testing.expect(ptr_id == &some_non_c_keyword_constant);
    ptr_id = &an_alias_of_some_non_c_keyword_constant;
    try std.testing.expect(ptr_id == &some_non_c_keyword_constant);

    if (builtin.target.ofmt != .coff and builtin.target.os.tag != .windows) {
        var ptr_fn: *const fn () callconv(.C) Id = &double;
        try std.testing.expect(ptr_fn == &float);
        ptr_fn = &an_alias_of_float;
        try std.testing.expect(ptr_fn == &float);

        ptr_fn = &@"break";
        try std.testing.expect(ptr_fn == &some_non_c_keyword_function);
        ptr_fn = &an_alias_of_some_non_c_keyword_function;
        try std.testing.expect(ptr_fn == &some_non_c_keyword_function);
    }
}
