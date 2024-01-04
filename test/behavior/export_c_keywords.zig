pub const Id = enum(c_int) {
    c_keyword_variable = 12,
    non_c_keyword_variable = 34,
    c_keyword_constant = 56,
    non_c_keyword_constant = 78,
    c_keyword_function = 910,
    non_c_keyword_function = 1112,
};

export var int: Id = .c_keyword_variable;

export var some_non_c_keyword_variable: Id = .non_c_keyword_variable;

export const @"if": Id = .c_keyword_constant;

export const some_non_c_keyword_constant: Id = .non_c_keyword_constant;

export fn float() Id {
    return .c_keyword_function;
}

export fn some_non_c_keyword_function() Id {
    return .non_c_keyword_function;
}

comptime {
    @export(int, .{ .name = "long" });
    @export(int, .{ .name = "an_alias_of_int" });

    @export(some_non_c_keyword_variable, .{ .name = "void" });
    @export(some_non_c_keyword_variable, .{ .name = "an_alias_of_some_non_c_keyword_variable" });

    @export(@"if", .{ .name = "else" });
    @export(@"if", .{ .name = "an_alias_of_if" });

    @export(some_non_c_keyword_constant, .{ .name = "switch" });
    @export(some_non_c_keyword_constant, .{ .name = "an_alias_of_some_non_c_keyword_constant" });

    @export(float, .{ .name = "double" });
    @export(float, .{ .name = "an_alias_of_float" });

    @export(some_non_c_keyword_function, .{ .name = "break" });
    @export(some_non_c_keyword_function, .{ .name = "an_alias_of_some_non_c_keyword_function" });
}
